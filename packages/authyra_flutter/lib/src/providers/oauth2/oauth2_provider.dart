import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:authyra/authyra.dart';
import 'package:authyra/logging.dart';
import 'package:authyra_flutter/src/providers/oauth2/oauth2_config.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart';

/// Generic OAuth 2.0 Authorization Code provider with optional PKCE.
///
/// Implements the full browser-based OAuth 2.0 flow end-to-end:
///
/// ```
/// App                              Identity Provider
///  │── build authorization URL ───────────────────►│
///  │── open external browser ──────────────────────►│
///  │                                               │ (user authenticates)
///  │◄── deep-link callback (?code=…&state=…) ──────│
///  │── exchange code for tokens ───────────────────►│
///  │◄── { access_token, refresh_token, expires_in } │
///  │── GET /userinfo (Bearer) ─────────────────────►│
///  │◄── { sub, email, name, … } ───────────────────│
/// ```
///
/// PKCE ([RFC 7636](https://www.rfc-editor.org/rfc/rfc7636)) is enabled by
/// default (`OAuth2Config.usePkce = true`) and is strongly recommended for
/// public clients (mobile, desktop) that cannot safely store a client secret.
///
/// ## Setup
///
/// Use a prebuilt subclass ([GoogleProvider], [GitHubOAuth2Provider]) or
/// instantiate directly with a custom [OAuth2Config]:
///
/// ```dart
/// final discordProvider = OAuth2Provider(
///   config: OAuth2Config(
///     providerName:          'discord',
///     clientId:              'YOUR_CLIENT_ID',
///     authorizationEndpoint: 'https://discord.com/oauth2/authorize',
///     tokenEndpoint:         'https://discord.com/api/oauth2/token',
///     userInfoEndpoint:      'https://discord.com/api/users/@me',
///     redirectUri:           'myapp://auth/callback',
///     scopes:                ['identify', 'email'],
///     userExtractor: (json) => AuthUser(
///       id:    json['id']       as String,
///       email: json['email']    as String?,
///       name:  json['username'] as String?,
///     ),
///   ),
/// );
/// ```
///
/// ## Deep-link wiring
///
/// The provider completes sign-in only when the redirect URI is delivered back
/// to the app. Wire this up in your deep-link handler and call
/// [handleRedirectCallback]:
///
/// ```dart
/// AppLinks().uriLinkStream.listen((uri) {
///   OAuth2CallbackHandler.handleCallback(uri);
/// });
///
/// // Register once at startup:
/// OAuth2CallbackHandler.registerProvider('myapp', discordProvider);
/// ```
///
/// ## Token refresh
///
/// [supportsRefresh] is `true`. When [AuthyraClient] detects an expired
/// session, it calls [refreshToken] automatically — no user interaction
/// required.
///
/// ## Sign-out
///
/// Most providers do not require an explicit revocation call. Override
/// [signOut] if the provider exposes a revocation endpoint (e.g., Google's
/// `https://oauth2.googleapis.com/revoke`).
///
/// See also:
/// - [OAuth2Config], the configuration object.
/// - [GoogleProvider] / [GitHubOAuth2Provider], prebuilt subclasses.
/// - [ProxyOAuthProvider], for backend-delegated OAuth flows.
/// - [OAuth2CallbackHandler], the global deep-link router.
class OAuth2Provider with AuthyraLogging implements AuthProvider {
  /// The configuration describing endpoints, credentials, and scopes.
  final OAuth2Config config;

  final Dio _dio;

  // PKCE state — lives only for the duration of a single sign-in attempt.
  String? _codeVerifier;
  String? _codeChallenge;
  String? _state;

  /// Resolves when the redirect URI deep link arrives via [handleRedirectCallback].
  Completer<Map<String, String>>? _authCompleter;

  /// Creates an [OAuth2Provider].
  ///
  /// Optionally inject a [Dio] instance (useful for sharing interceptors or
  /// for testing):
  ///
  /// ```dart
  /// OAuth2Provider(config: myConfig, dio: myDio)
  /// ```
  OAuth2Provider({
    required this.config,
    Dio? dio,
  }) : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 30),
              receiveTimeout: const Duration(seconds: 30),
            ));

  // ---------------------------------------------------------------------------
  // AuthProvider identity
  // ---------------------------------------------------------------------------

  @override
  String get id => config.providerName;

  @override
  String get name => config.providerName;

  @override
  AuthProviderType get type => AuthProviderType.oauth2;

  /// Always `true` — OAuth2 providers return refresh tokens that enable
  /// silent session renewal via [refreshToken].
  @override
  bool get supportsRefresh => true;

  /// `false` by default — most providers do not require explicit revocation.
  ///
  /// Override and set to `true` in a subclass if the provider exposes a
  /// token revocation endpoint.
  @override
  bool get supportsSignOut => false;

  // ---------------------------------------------------------------------------
  // Sign in
  // ---------------------------------------------------------------------------

  /// Executes the full OAuth 2.0 Authorization Code flow.
  ///
  /// Steps:
  /// 1. Generate PKCE verifier / challenge (when `config.usePkce` is `true`)
  ///    and a CSRF state token.
  /// 2. Build the authorization URL and open it in an external browser.
  /// 3. Wait for [handleRedirectCallback] to deliver the code + state.
  /// 4. Verify the state (CSRF protection).
  /// 5. Exchange the code for tokens at [OAuth2Config.tokenEndpoint].
  /// 6. Fetch the user profile from [OAuth2Config.userInfoEndpoint].
  /// 7. Return [AuthSignInResult] with user + all tokens.
  ///
  /// Throws [AuthenticationFailedException] on protocol or network errors.
  /// Throws [AuthenticationCancelledException] when the user dismisses the
  /// browser or [OAuth2Config.timeout] elapses.
  @override
  Future<AuthSignInResult?> signIn({Map<String, dynamic>? params}) async {
    try {
      logInfo('Starting OAuth2 flow for ${config.providerName}');

      // Step 1: Generate PKCE values (and state for CSRF) if enabled.
      if (config.usePkce) {
        _generatePkceValues();
        logDebug('PKCE enabled — code verifier generated');
      } else {
        _generateState();
        logDebug('PKCE disabled — using state parameter only');
      }

      // Step 2: Build authorization URL.
      final authUrl = _buildAuthorizationUrl();
      logDebug('Authorization URL built');

      // Step 3: Open browser and wait for the redirect callback.
      final callbackParams = await _openAuthorizationUrl(authUrl);
      logDebug('Redirect callback received');

      // Step 4: Verify state (CSRF protection).
      _verifyState(callbackParams);

      // Step 5: Check for OAuth error parameters in the callback.
      _checkForErrors(callbackParams);

      // Step 6: Extract the authorization code.
      final code = callbackParams['code'];
      if (code == null || code.isEmpty) {
        throw AuthenticationFailedException(
          'No authorization code in callback from ${config.providerName}',
          providerName: config.providerName,
        );
      }
      logDebug('Authorization code received');

      // Step 7: Exchange code for tokens.
      final tokens = await _exchangeCodeForTokens(code);
      logDebug('Tokens received from ${config.providerName}');

      // Step 8: Fetch the user profile from the userinfo endpoint.
      final userInfo = await _fetchUserInfo(tokens['access_token']!);
      logDebug('User info fetched');

      // Step 9: Extract user from the provider-specific userInfo map.
      final user = config.userExtractor(userInfo);

      // Step 10: Parse expiry from the token response.
      // expires_in is included as a String in the returned map (token endpoint
      // returns it as a JSON integer, which we stringify to stay Map<String,String>).
      final expiresInStr = tokens['expires_in'];
      final expiresAt = expiresInStr != null ? DateTime.now().add(Duration(seconds: int.parse(expiresInStr))) : null;

      logInfo('OAuth2 sign in successful for $id');

      // Return the full result — never discard tokens.
      return AuthSignInResult(
        user: user,
        accessToken: tokens['access_token'],
        refreshToken: tokens['refresh_token'],
        expiresAt: expiresAt,
      );
    } on AuthException {
      rethrow;
    } catch (e, stackTrace) {
      logError('OAuth2 sign in failed', e, stackTrace);
      throw AuthenticationFailedException(
        'Failed to sign in with ${config.providerName}',
        providerName: id,
        originalError: e,
      );
    } finally {
      _cleanup();
    }
  }

  // ---------------------------------------------------------------------------
  // Sign out
  // ---------------------------------------------------------------------------

  /// No-op by default — most OAuth providers do not require an explicit
  /// revocation call for mobile / SPA clients.
  ///
  /// Override in a subclass to call the provider's revocation endpoint, e.g.:
  ///
  /// ```dart
  /// @override
  /// Future<void> signOut({String? userId}) async {
  ///   await _dio.post('https://oauth2.googleapis.com/revoke',
  ///     queryParameters: {'token': storedAccessToken});
  /// }
  /// ```
  @override
  Future<void> signOut({String? userId}) async {
    logDebug('signOut called for ${config.providerName} — no-op');
  }

  // ---------------------------------------------------------------------------
  // Token refresh
  // ---------------------------------------------------------------------------

  /// Exchanges [refreshToken] for a fresh access token.
  ///
  /// Called automatically by [AuthyraClient] when the active session is
  /// expired and [supportsRefresh] is `true`.
  ///
  /// Returns `null` if the refresh token is invalid or rejected by the
  /// provider — the client will then require a full re-authentication.
  ///
  /// Throws [TokenRefreshFailedException] on network errors.
  @override
  Future<AuthTokenResult?> refreshToken(String refreshToken) async {
    try {
      logDebug('Refreshing token for ${config.providerName}');

      final body = {
        'grant_type': 'refresh_token',
        'refresh_token': refreshToken,
        'client_id': config.clientId,
        if (config.clientSecret != null) 'client_secret': config.clientSecret,
        ...config.additionalTokenParams,
      };

      final response = await _dio.post(
        config.tokenEndpoint,
        data: body,
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: config.tokenHeaders,
        ),
      );

      final data = response.data as Map<String, dynamic>;
      final newAccessToken = data['access_token'] as String;
      final newRefreshToken = data['refresh_token'] as String?;
      final expiresIn = data['expires_in'] as int?;
      final expiresAt = expiresIn != null
          ? DateTime.now().add(Duration(seconds: expiresIn))
          : DateTime.now().add(const Duration(hours: 1));

      logDebug('Token refreshed successfully for ${config.providerName}');

      return AuthTokenResult(
        accessToken: newAccessToken,
        refreshToken: newRefreshToken, // null = retain existing token
        expiresAt: expiresAt,
      );
    } on DioException catch (e) {
      logError('Token refresh failed for ${config.providerName}', e);
      throw TokenRefreshFailedException(
        'Failed to refresh token for ${config.providerName}',
        e,
      );
    } catch (e, stackTrace) {
      logError('Unexpected error during token refresh', e, stackTrace);
      throw TokenRefreshFailedException(
        'Unexpected error during token refresh',
        e,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Deep-link callback (must be called by the app's link handler)
  // ---------------------------------------------------------------------------

  /// Resolves the pending [signIn] call with the redirect callback parameters.
  ///
  /// Call this from your app's deep-link stream handler. Typically you register
  /// the provider with [OAuth2CallbackHandler] which calls this automatically:
  ///
  /// ```dart
  /// // Register once at startup:
  /// OAuth2CallbackHandler.registerProvider('myapp', discordProvider);
  ///
  /// // In your link handler:
  /// AppLinks().uriLinkStream.listen(OAuth2CallbackHandler.handleCallback);
  /// ```
  ///
  /// If called when no sign-in is in progress, the call is silently ignored.
  void handleRedirectCallback(Uri uri) {
    if (_authCompleter == null || _authCompleter!.isCompleted) {
      logWarning('Received callback but no pending auth request');
      return;
    }

    logDebug('Processing redirect callback');

    final params = uri.queryParameters;

    // Also handle implicit flow (fragment-based) if code is not in params.
    if (params.isEmpty && uri.fragment.isNotEmpty) {
      _authCompleter!.complete(Uri.splitQueryString(uri.fragment));
    } else {
      _authCompleter!.complete(params);
    }
  }

  // ---------------------------------------------------------------------------
  // PKCE & security helpers
  // ---------------------------------------------------------------------------

  /// Generates a cryptographically random PKCE code verifier, derives the
  /// SHA-256 code challenge, and generates the CSRF state token.
  void _generatePkceValues() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));

    _codeVerifier = base64UrlEncode(bytes).replaceAll('=', '').replaceAll('+', '-').replaceAll('/', '_');

    final digest = sha256.convert(utf8.encode(_codeVerifier!));
    _codeChallenge = base64UrlEncode(digest.bytes).replaceAll('=', '').replaceAll('+', '-').replaceAll('/', '_');

    _generateState();
  }

  /// Generates a cryptographically random CSRF state token.
  void _generateState() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    _state = base64UrlEncode(bytes).replaceAll('=', '').replaceAll('+', '-').replaceAll('/', '_');
  }

  /// Verifies that the `state` in the callback matches the one sent in the
  /// authorization request (CSRF protection, RFC 6749 §10.12).
  void _verifyState(Map<String, String> params) {
    if (_state == null) {
      throw AuthenticationFailedException(
        'Internal error: state not generated before verifying',
        providerName: id,
      );
    }

    if (params['state'] != _state) {
      throw AuthenticationFailedException(
        'State mismatch — possible CSRF attack detected for $id',
        providerName: id,
      );
    }

    logDebug('CSRF state verified for $id');
  }

  /// Checks the callback for OAuth 2.0 error parameters (RFC 6749 §4.1.2.1).
  void _checkForErrors(Map<String, String> params) {
    final error = params['error'];
    if (error == null) return;

    final description = params['error_description'];
    logError('OAuth error from $id', {'error': error, 'description': description});

    if (error == 'access_denied') throw AuthenticationCancelledException(id);

    throw AuthenticationFailedException(
      description ?? error,
      providerName: id,
    );
  }

  // ---------------------------------------------------------------------------
  // OAuth flow helpers
  // ---------------------------------------------------------------------------

  /// Assembles the full authorization URL including PKCE and state params.
  String _buildAuthorizationUrl() {
    final queryParams = {
      'client_id': config.clientId,
      'redirect_uri': config.redirectUri,
      'response_type': 'code',
      'scope': config.scopes.join(' '),
      'state': _state!,
      if (config.usePkce) ...{
        'code_challenge': _codeChallenge!,
        'code_challenge_method': 'S256',
      },
      ...config.additionalAuthParams,
    };

    return Uri.parse(config.authorizationEndpoint).replace(queryParameters: queryParams).toString();
  }

  /// Launches [url] in an external browser and waits for [handleRedirectCallback]
  /// to resolve with the callback parameters.
  Future<Map<String, String>> _openAuthorizationUrl(String url) async {
    _authCompleter = Completer<Map<String, String>>();

    try {
      final uri = Uri.parse(url);

      if (!await canLaunchUrl(uri)) {
        throw AuthenticationFailedException(
          'Cannot launch authorization URL for $id',
          providerName: id,
        );
      }

      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        throw AuthenticationFailedException(
          'Failed to launch authorization URL for $id',
          providerName: id,
        );
      }

      logDebug('Browser opened for $id — waiting for callback');

      return await _authCompleter!.future.timeout(
        config.timeout,
        onTimeout: () => throw AuthenticationCancelledException(id),
      );
    } on AuthException {
      rethrow;
    } catch (e) {
      throw AuthenticationFailedException(
        'Error during authorization URL launch for $id',
        providerName: id,
        originalError: e,
      );
    }
  }

  /// Exchanges the authorization [code] for access / refresh tokens.
  ///
  /// Returns a `Map<String, String>` containing the token response fields,
  /// including `access_token`, optionally `refresh_token`, `id_token`, and
  /// `expires_in` (stringified from the JSON integer).
  Future<Map<String, String>> _exchangeCodeForTokens(String code) async {
    logDebug('Exchanging authorization code for tokens at ${config.tokenEndpoint}');

    final body = {
      'grant_type': 'authorization_code',
      'code': code,
      'redirect_uri': config.redirectUri,
      'client_id': config.clientId,
      if (config.clientSecret != null) 'client_secret': config.clientSecret,
      if (config.usePkce && _codeVerifier != null) 'code_verifier': _codeVerifier!,
      ...config.additionalTokenParams,
    };

    try {
      final response = await _dio.post(
        config.tokenEndpoint,
        data: body,
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: config.tokenHeaders,
        ),
      );

      final data = response.data as Map<String, dynamic>;

      if (!data.containsKey('access_token')) {
        throw AuthenticationFailedException(
          'Token endpoint did not return an access_token for $id',
          providerName: id,
        );
      }

      return {
        'access_token': data['access_token'] as String,
        if (data['refresh_token'] != null) 'refresh_token': data['refresh_token'] as String,
        if (data['id_token'] != null) 'id_token': data['id_token'] as String,
        // Stringify expires_in so the Map<String,String> type is preserved.
        // Parsed back to int in signIn() via int.parse().
        if (data['expires_in'] != null) 'expires_in': data['expires_in'].toString(),
      };
    } on DioException catch (e) {
      logError('Code exchange failed for $id', e);
      throw AuthenticationFailedException(
        'Failed to exchange authorization code for $id '
        '(HTTP ${e.response?.statusCode})',
        providerName: id,
        originalError: e.response?.data ?? e,
      );
    }
  }

  /// Fetches the authenticated user's profile from [OAuth2Config.userInfoEndpoint].
  Future<Map<String, dynamic>> _fetchUserInfo(String accessToken) async {
    logDebug('Fetching user info from ${config.userInfoEndpoint}');

    try {
      final response = await _dio.get(
        config.userInfoEndpoint,
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
            ...?config.userInfoHeaders,
          },
        ),
      );

      final userInfo = response.data;
      if (userInfo is! Map) {
        throw AuthenticationFailedException(
          'Unexpected userinfo response format from $id',
          providerName: id,
        );
      }

      return userInfo as Map<String, dynamic>;
    } on DioException catch (e) {
      logError('Failed to fetch user info for $id', e);
      throw AuthenticationFailedException(
        'Failed to fetch user information from $id',
        providerName: id,
        originalError: e,
      );
    }
  }

  /// Clears all per-request PKCE and state values after each sign-in attempt.
  void _cleanup() {
    _codeVerifier = null;
    _codeChallenge = null;
    _state = null;
    _authCompleter = null;
    logDebug('OAuth2 temporary state cleaned up for $id');
  }
}

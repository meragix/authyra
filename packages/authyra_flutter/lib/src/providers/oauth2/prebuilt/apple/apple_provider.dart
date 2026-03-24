import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:authyra/authyra.dart';
import 'package:authyra/logging.dart';
import 'package:authyra_flutter/src/utils/jwt_utils.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart';

import 'apple_config.dart';

/// Prebuilt [AuthProvider] for Sign in with Apple.
///
/// Implements the Apple OAuth 2.0 Authorization Code flow with PKCE and a
/// nonce, handling the Apple-specific requirements:
///
/// - **Dynamic client secret** — the ES256 JWT is generated on every request
///   via [JwtUtils.generateAppleClientSecret]. No static secret is needed.
/// - **No userinfo endpoint** — the user profile is decoded from the `id_token`
///   JWT returned by `https://appleid.apple.com/auth/token`.
/// - **First-sign-in user data** — Apple sends `name` and `email` only once,
///   encoded as a `user` query parameter in the callback URL. The provider
///   extracts these automatically and folds them into [AuthUser].
///
/// ```
/// App                              Apple
///  │── build authorization URL ─────────────────────►│
///  │── open external browser ──────────────────────►│
///  │                                               │ (user authenticates)
///  │◄── deep-link callback (?code=…&state=…) ──────│
///  │      [+ user={"name":{…},"email":"…"} on first sign-in]
///  │── POST /auth/token (with ES256 client_secret) ►│
///  │◄── { access_token, refresh_token, id_token } ──│
///  │── decode id_token (JWT) — no HTTP call needed  │
/// ```
///
/// ## Setup
///
/// ```dart
/// final appleProvider = AppleProvider(
///   config: AppleOAuthConfig(
///     clientId:      'com.example.app.service',
///     teamId:        'AB12CD34EF',
///     keyId:         'XYZXYZXYZX',
///     privateKeyPem: File('AuthKey_XYZXYZXYZX.p8').readAsStringSync(),
///     redirectUri:   'https://example.com/auth/apple/callback',
///   ),
/// );
///
/// final client = AuthyraClient(
///   providers: [appleProvider],
///   storage: SecureAuthStorage(),
/// );
///
/// // Wire deep-link callbacks:
/// OAuth2CallbackHandler.registerProvider('https', appleProvider);
/// AppLinks().uriLinkStream.listen(OAuth2CallbackHandler.handleCallback);
/// ```
///
/// ## Sign in
///
/// ```dart
/// final user = await Authyra.instance.signIn('apple');
/// print('Hello, ${user.name}!');
/// ```
///
/// ## User fields extracted
///
/// | [AuthUser] field | Source                                          |
/// |------------------|-------------------------------------------------|
/// | `id`             | `id_token` → `sub` claim (stable Apple User ID) |
/// | `email`          | `id_token` → `email` claim                      |
/// | `name`           | `user` callback param (first sign-in only)      |
/// | `metadata`       | `email_verified`, `given_name`, `family_name`   |
///
/// **Important**: Persist `user.name` immediately after the first sign-in —
/// Apple will not send it again.
///
/// ## Token refresh
///
/// [supportsRefresh] is `true`. Apple honors the refresh token for up to
/// 6 months and does not rotate it. The fresh `access_token` is stored in
/// the updated [AuthSession].
///
/// See also:
/// - [AppleOAuthConfig], the configuration object.
/// - [JwtUtils.generateAppleClientSecret], ES256 JWT generation.
/// - [OAuth2CallbackHandler], the global deep-link router.
/// - [Apple documentation](https://developer.apple.com/documentation/sign_in_with_apple/sign_in_with_apple_rest_api)
class AppleProvider with AuthyraLogging implements AuthProvider {
  /// The configuration describing credentials, redirect URI, and scopes.
  final AppleOAuthConfig config;

  final Dio _dio;

  // Per-request PKCE + security values.
  String? _codeVerifier;
  String? _codeChallenge;
  String? _state;
  String? _nonce;

  /// Resolves when the redirect URI deep link arrives via [handleRedirectCallback].
  Completer<Map<String, String>>? _authCompleter;

  /// Creates an [AppleProvider].
  ///
  /// Optionally inject a [Dio] instance for sharing interceptors or testing.
  AppleProvider({
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
  String get id => 'apple';

  @override
  String get name => 'apple';

  @override
  AuthProviderType get type => AuthProviderType.oauth2;

  /// Always `true` — Apple issues refresh tokens that enable silent renewal.
  @override
  bool get supportsRefresh => true;

  /// `false` — Apple does not expose a client-side revocation endpoint.
  @override
  bool get supportsSignOut => false;

  // ---------------------------------------------------------------------------
  // Sign in
  // ---------------------------------------------------------------------------

  /// Executes the Sign in with Apple Authorization Code flow.
  ///
  /// Steps:
  /// 1. Generate PKCE verifier/challenge, CSRF state, and a nonce.
  /// 2. Build the Apple authorization URL and open it in an external browser.
  /// 3. Wait for [handleRedirectCallback] to deliver the code + state.
  /// 4. Verify the state (CSRF protection).
  /// 5. Exchange the code for tokens at `https://appleid.apple.com/auth/token`
  ///    using a dynamically generated ES256 client secret.
  /// 6. Decode the `id_token` JWT to extract user identity (sub, email).
  /// 7. Parse first-sign-in `user` JSON for the user's name (if present).
  /// 8. Return [AuthSignInResult] with the extracted user + tokens.
  ///
  /// Throws [AuthenticationFailedException] on protocol or network errors.
  /// Throws [AuthenticationCancelledException] when the user dismisses the
  /// browser or [AppleOAuthConfig.timeout] elapses.
  @override
  Future<AuthSignInResult?> signIn({AuthSignInParams? params}) async {
    try {
      logInfo('Starting Sign in with Apple flow');

      // Step 1: Generate PKCE, state, and nonce.
      _generateSecurityValues();

      // Step 2: Build the Apple authorization URL.
      final authUrl = _buildAuthorizationUrl();
      logDebug('Apple authorization URL built');

      // Step 3: Open the browser and wait for the deep-link callback.
      final callbackParams = await _openBrowserAndWait(authUrl);
      logDebug('Apple redirect callback received');

      // Step 4: CSRF protection.
      _verifyState(callbackParams);

      // Step 5: OAuth error check.
      _checkForErrors(callbackParams);

      // Step 6: Extract the authorization code.
      final code = callbackParams['code'];
      if (code == null || code.isEmpty) {
        throw AuthenticationFailedException(
          'No authorization code in Apple callback',
          providerName: id,
        );
      }

      // On first sign-in, Apple sends a `user` query parameter with name/email.
      // This is never sent again — must be persisted immediately.
      final userJsonStr = callbackParams['user'];
      Map<String, dynamic>? appleUserJson;
      if (userJsonStr != null) {
        try {
          appleUserJson = jsonDecode(userJsonStr) as Map<String, dynamic>;
          logDebug('Apple first-sign-in user JSON received');
        } catch (_) {
          logWarning('Failed to parse Apple user JSON from callback');
        }
      }

      // Step 7: Exchange code for tokens.
      final tokens = await _exchangeCodeForTokens(code);
      logDebug('Apple tokens received');

      // Step 8: Decode id_token to extract the user profile.
      final idToken = tokens['id_token'];
      if (idToken == null) {
        throw AuthenticationFailedException(
          'Apple token response is missing id_token',
          providerName: id,
        );
      }

      final user = _extractUser(idToken, appleUserJson);

      final expiresInStr = tokens['expires_in'];
      final expiresAt = expiresInStr != null
          ? DateTime.now().add(Duration(seconds: int.parse(expiresInStr)))
          : null;

      logInfo('Sign in with Apple successful for user: ${user.id}');

      return AuthSignInResult(
        user: user,
        accessToken: tokens['access_token'],
        refreshToken: tokens['refresh_token'],
        expiresAt: expiresAt,
      );
    } on AuthException {
      rethrow;
    } catch (e, st) {
      logError('Sign in with Apple failed', e, st);
      throw AuthenticationFailedException(
        'Failed to sign in with Apple',
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

  /// No-op — Apple does not expose a client-side token revocation endpoint.
  @override
  Future<void> signOut({String? userId}) async {
    logDebug('Apple signOut called — no-op');
  }

  // ---------------------------------------------------------------------------
  // Token refresh
  // ---------------------------------------------------------------------------

  /// Exchanges [refreshToken] for a fresh access token.
  ///
  /// Apple requires the same dynamically generated ES256 [client_secret] for
  /// refresh calls. The refresh token itself is **not rotated** — Apple
  /// re-uses the same token across refreshes.
  ///
  /// Returns `null` if the refresh token has been revoked or is otherwise
  /// invalid (the caller should require full re-authentication).
  ///
  /// Throws [TokenRefreshFailedException] on network errors.
  @override
  Future<AuthTokenResult?> refreshToken(String refreshToken) async {
    try {
      logDebug('Refreshing Apple token');

      final clientSecret = _generateClientSecret();

      final response = await _dio.post(
        'https://appleid.apple.com/auth/token',
        data: {
          'grant_type': 'refresh_token',
          'refresh_token': refreshToken,
          'client_id': config.clientId,
          'client_secret': clientSecret,
        },
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );

      final data = response.data as Map<String, dynamic>;
      final newAccessToken = data['access_token'] as String;
      final expiresIn = data['expires_in'] as int?;
      final expiresAt = expiresIn != null
          ? DateTime.now().add(Duration(seconds: expiresIn))
          : DateTime.now().add(const Duration(hours: 1));

      logDebug('Apple token refreshed successfully');

      // Apple does not rotate refresh tokens — pass null to retain existing.
      return AuthTokenResult(
        accessToken: newAccessToken,
        refreshToken: null,
        expiresAt: expiresAt,
      );
    } on DioException catch (e) {
      logError('Apple token refresh failed', e);
      throw TokenRefreshFailedException(
        'Failed to refresh Apple token',
        e,
      );
    } catch (e, st) {
      logError('Unexpected error during Apple token refresh', e, st);
      throw TokenRefreshFailedException(
        'Unexpected error during Apple token refresh',
        e,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Deep-link callback
  // ---------------------------------------------------------------------------

  /// Resolves the pending [signIn] call with the redirect callback parameters.
  ///
  /// Wire this in your deep-link handler via [OAuth2CallbackHandler]:
  ///
  /// ```dart
  /// // Register once at startup:
  /// OAuth2CallbackHandler.registerProvider('https', appleProvider);
  ///
  /// // In your link handler:
  /// AppLinks().uriLinkStream.listen(OAuth2CallbackHandler.handleCallback);
  /// ```
  ///
  /// If no sign-in is in progress, the call is silently ignored.
  void handleRedirectCallback(Uri uri) {
    if (_authCompleter == null || _authCompleter!.isCompleted) {
      logWarning('Received Apple callback but no pending auth request');
      return;
    }
    logDebug('Processing Apple redirect callback');
    _authCompleter!.complete(uri.queryParameters);
  }

  // ---------------------------------------------------------------------------
  // Security helpers
  // ---------------------------------------------------------------------------

  /// Generates PKCE verifier/challenge, a CSRF state token, and a nonce.
  ///
  /// The nonce is included in the authorization request and Apple embeds it
  /// in the returned `id_token`, enabling replay-attack detection.
  void _generateSecurityValues() {
    final random = Random.secure();

    // PKCE (RFC 7636)
    final verifierBytes = List<int>.generate(32, (_) => random.nextInt(256));
    _codeVerifier = base64UrlEncode(verifierBytes)
        .replaceAll('=', '')
        .replaceAll('+', '-')
        .replaceAll('/', '_');
    final digest = sha256.convert(utf8.encode(_codeVerifier!));
    _codeChallenge = base64UrlEncode(digest.bytes)
        .replaceAll('=', '')
        .replaceAll('+', '-')
        .replaceAll('/', '_');

    // CSRF state (RFC 6749 §10.12)
    final stateBytes = List<int>.generate(16, (_) => random.nextInt(256));
    _state = base64UrlEncode(stateBytes)
        .replaceAll('=', '')
        .replaceAll('+', '-')
        .replaceAll('/', '_');

    // Nonce — raw lowercase hex, included in id_token for replay protection.
    final nonceBytes = List<int>.generate(16, (_) => random.nextInt(256));
    _nonce = nonceBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Verifies the `state` in the callback against the value sent in the
  /// authorization request (CSRF protection).
  void _verifyState(Map<String, String> params) {
    if (params['state'] != _state) {
      throw AuthenticationFailedException(
        'State mismatch — possible CSRF attack detected for Apple Sign In',
        providerName: id,
      );
    }
    logDebug('Apple CSRF state verified');
  }

  /// Checks the callback for OAuth error parameters (RFC 6749 §4.1.2.1).
  ///
  /// Apple uses `user_cancelled_authorize` when the user dismisses the
  /// authorization sheet.
  void _checkForErrors(Map<String, String> params) {
    final error = params['error'];
    if (error == null) return;

    logError('Apple OAuth error', {'error': error});

    if (error == 'user_cancelled_authorize') {
      throw AuthenticationCancelledException(id);
    }

    throw AuthenticationFailedException(
      params['error_description'] ?? error,
      providerName: id,
    );
  }

  // ---------------------------------------------------------------------------
  // OAuth flow helpers
  // ---------------------------------------------------------------------------

  /// Assembles the Apple authorization URL.
  ///
  /// `response_mode=query` returns parameters in the redirect URI query string,
  /// which is compatible with custom URL schemes and Universal Links used in
  /// native apps. Web-based flows should use `response_mode=form_post`.
  String _buildAuthorizationUrl() {
    return Uri.https('appleid.apple.com', '/auth/authorize', {
      'client_id': config.clientId,
      'redirect_uri': config.redirectUri,
      'response_type': 'code',
      'scope': config.scopes.join(' '),
      'state': _state!,
      'nonce': _nonce!,
      'response_mode': 'query',
      'code_challenge': _codeChallenge!,
      'code_challenge_method': 'S256',
    }).toString();
  }

  /// Launches [url] in an external browser and waits for the deep-link
  /// callback to resolve via [handleRedirectCallback].
  Future<Map<String, String>> _openBrowserAndWait(String url) async {
    _authCompleter = Completer<Map<String, String>>();

    final uri = Uri.parse(url);
    if (!await canLaunchUrl(uri)) {
      throw AuthenticationFailedException(
        'Cannot launch Apple authorization URL',
        providerName: id,
      );
    }

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      throw AuthenticationFailedException(
        'Failed to launch Apple authorization URL',
        providerName: id,
      );
    }

    logDebug('Browser opened for Apple — waiting for callback');

    return _authCompleter!.future.timeout(
      config.timeout,
      onTimeout: () => throw AuthenticationCancelledException(id),
    );
  }

  /// Exchanges the authorization [code] for access/refresh/id tokens.
  ///
  /// Generates a fresh ES256 client secret for each call — Apple requires
  /// this instead of a static secret.
  Future<Map<String, String>> _exchangeCodeForTokens(String code) async {
    logDebug('Exchanging Apple authorization code for tokens');

    final clientSecret = _generateClientSecret();

    try {
      final response = await _dio.post(
        'https://appleid.apple.com/auth/token',
        data: {
          'grant_type': 'authorization_code',
          'code': code,
          'redirect_uri': config.redirectUri,
          'client_id': config.clientId,
          'client_secret': clientSecret,
          'code_verifier': _codeVerifier!,
        },
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );

      final data = response.data as Map<String, dynamic>;

      if (!data.containsKey('access_token')) {
        throw AuthenticationFailedException(
          'Apple token endpoint did not return access_token',
          providerName: id,
        );
      }

      return {
        'access_token': data['access_token'] as String,
        if (data['refresh_token'] != null)
          'refresh_token': data['refresh_token'] as String,
        if (data['id_token'] != null) 'id_token': data['id_token'] as String,
        if (data['expires_in'] != null)
          'expires_in': data['expires_in'].toString(),
      };
    } on DioException catch (e) {
      logError('Apple code exchange failed', e);
      throw AuthenticationFailedException(
        'Failed to exchange Apple authorization code '
        '(HTTP ${e.response?.statusCode})',
        providerName: id,
        originalError: e.response?.data ?? e,
      );
    }
  }

  /// Generates a fresh ES256 client-secret JWT for use in Apple token calls.
  String _generateClientSecret() => JwtUtils.generateAppleClientSecret(
        teamId: config.teamId,
        clientId: config.clientId,
        keyId: config.keyId,
        privateKeyPem: config.privateKeyPem,
        validity: config.clientSecretValidity,
      );

  /// Builds an [AuthUser] from the decoded `id_token` claims and the optional
  /// first-sign-in `user` JSON object.
  ///
  /// Apple `id_token` claim reference:
  /// https://developer.apple.com/documentation/sign_in_with_apple/sign_in_with_apple_rest_api/authenticating_users_with_sign_in_with_apple
  AuthUser _extractUser(
    String idToken,
    Map<String, dynamic>? appleUserJson,
  ) {
    final claims = JwtUtils.decodePayload(idToken);

    final sub = claims['sub'] as String; // Stable Apple User ID
    final email = claims['email'] as String?;
    final emailVerified = claims['email_verified'];

    // Name is only present on the very first sign-in via the `user` callback
    // parameter — it is never included in subsequent id_tokens.
    String? firstName;
    String? lastName;
    if (appleUserJson != null) {
      final nameMap = appleUserJson['name'] as Map<String, dynamic>?;
      firstName = nameMap?['firstName'] as String?;
      lastName = nameMap?['lastName'] as String?;
    }

    final nameParts = [firstName, lastName].whereType<String>();
    final fullName = nameParts.isNotEmpty ? nameParts.join(' ') : null;

    return AuthUser(
      id: sub,
      email: email,
      name: fullName,
      metadata: {
        'email_verified': emailVerified,
        if (firstName != null) 'given_name': firstName,
        if (lastName != null) 'family_name': lastName,
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Cleanup
  // ---------------------------------------------------------------------------

  /// Clears all per-request security values after each sign-in attempt.
  void _cleanup() {
    _codeVerifier = null;
    _codeChallenge = null;
    _state = null;
    _nonce = null;
    _authCompleter = null;
    logDebug('Apple temporary state cleaned up');
  }
}

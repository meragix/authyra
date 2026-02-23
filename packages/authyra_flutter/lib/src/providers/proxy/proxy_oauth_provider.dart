import 'dart:async';

import 'package:authyra/authyra.dart';
import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart';

import 'proxy_oauth_config.dart';

/// Authentication provider that delegates the entire OAuth flow to your backend.
///
/// Unlike [OAuth2Provider], which drives the Authorization Code exchange
/// directly from the app, [ProxyOAuthProvider] keeps all sensitive operations
/// (client secret, code exchange, token storage) on the server. The app only
/// needs to:
///
/// 1. Call [signIn] — which POSTs to your backend to obtain an authorization
///    URL, then opens it in an external browser.
/// 2. Register a deep-link handler and call [handleDeepLink] when the backend
///    redirects back to the app with a custom token.
///
/// ## Backend flow
///
/// ```
/// App                Backend                  Identity Provider
///  │──POST /auth/google/initiate──►│                  │
///  │◄── { authorization_url } ─────│                  │
///  │                               │                  │
///  │── opens browser ─────────────►│──► /oauth2/auth ►│
///  │                               │                  │
///  │                               │◄── code ─────────│
///  │                               │── exchange code ─►│
///  │                               │◄── tokens ───────│
///  │                               │── create session  │
///  │◄── myapp://auth/callback?token=CUSTOM_JWT ────────│
///  │                               │                  │
///  │──POST /auth/google/callback { token } ──►│        │
///  │◄── { user, access_token, ... } ─────────│        │
/// ```
///
/// ## Setup
///
/// ```dart
/// final provider = ProxyOAuthProvider(
///   config: ProxyOAuthConfig(
///     providerName:       'google',
///     initiationEndpoint: 'https://api.example.com/auth/google/initiate',
///     callbackEndpoint:   'https://api.example.com/auth/google/callback',
///     appCallbackScheme:  'myapp://auth/callback',
///     backendRedirectUri: 'https://api.example.com/auth/google/oauth-callback',
///     userExtractor: (json) => AuthUser(
///       id:    json['id']    as String,
///       email: json['email'] as String?,
///       name:  json['name']  as String?,
///     ),
///   ),
/// );
/// ```
///
/// ## Deep-link wiring
///
/// In your app's deep-link handler (e.g., `app_links`, `uni_links`, or
/// `GoRouter`'s redirect), forward matching URIs to [handleDeepLink]:
///
/// ```dart
/// final sub = AppLinks().uriLinkStream.listen((uri) {
///   if (uri.toString().startsWith('myapp://auth/callback')) {
///     provider.handleDeepLink(uri);
///   }
/// });
/// ```
///
/// See also:
/// - [ProxyOAuthConfig], the configuration object.
/// - [OAuth2Provider], for direct client-side OAuth2 flows.
/// - [CredentialsProvider], for email / password flows.
class ProxyOAuthProvider with AuthyraLogging implements AuthProvider {
  /// The configuration describing backend endpoints and app callback scheme.
  final ProxyOAuthConfig config;

  final Dio _dio;

  /// Completer resolved by [handleDeepLink] when the backend redirects back.
  Completer<Uri>? _pendingCallback;

  /// Creates a [ProxyOAuthProvider].
  ///
  /// Optionally inject a [Dio] instance (e.g., for testing or to share an
  /// existing client with interceptors):
  ///
  /// ```dart
  /// ProxyOAuthProvider(
  ///   config: myConfig,
  ///   dio: myDioWithAuthInterceptor,
  /// )
  /// ```
  ProxyOAuthProvider({
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

  /// Proxy providers cannot refresh tokens client-side — the backend holds
  /// the refresh token. Set to `true` if you add a backend refresh endpoint
  /// and override [refreshToken].
  @override
  bool get supportsRefresh => false;

  @override
  bool get supportsSignOut => false;

  // ---------------------------------------------------------------------------
  // Sign in
  // ---------------------------------------------------------------------------

  /// Initiates the backend-driven OAuth flow.
  ///
  /// Steps:
  /// 1. POSTs to [ProxyOAuthConfig.initiationEndpoint] to obtain the
  ///    authorization URL.
  /// 2. Opens the URL in an external browser via `url_launcher`.
  /// 3. Waits for [handleDeepLink] to resolve the pending callback.
  /// 4. Exchanges the received token with the backend and returns the
  ///    authenticated user + any session tokens.
  ///
  /// Throws [AuthenticationFailedException] on network or protocol errors.
  /// Throws [AuthenticationCancelledException] if [ProxyOAuthConfig.timeout]
  /// elapses before the deep link arrives.
  @override
  Future<AuthSignInResult?> signIn({Map<String, dynamic>? params}) async {
    if (_pendingCallback != null && !_pendingCallback!.isCompleted) {
      logWarning('Cancelling previous pending OAuth callback for $id');
      _pendingCallback!.completeError(
        AuthenticationCancelledException(id),
      );
    }
    _pendingCallback = Completer<Uri>();

    try {
      logInfo('Starting backend OAuth flow for $id');

      // Step 1: Ask the backend to initiate the OAuth flow.
      final authUrl = await _initiateFlow(params);
      logDebug('Authorization URL received for $id');

      // Step 2: Open the URL in an external browser.
      await _launchUrl(authUrl);
      logDebug('Authorization URL launched for $id');

      // Step 3: Wait for the deep-link callback from the backend.
      final callbackUri = await _pendingCallback!.future.timeout(
        config.timeout,
        onTimeout: () {
          logWarning('OAuth flow timed out for $id');
          throw AuthenticationCancelledException(id);
        },
      );
      logDebug('Deep-link callback received for $id');

      // Step 4: Exchange the backend token for user info + session credentials.
      return await _exchangeToken(callbackUri);
    } on AuthException {
      rethrow;
    } catch (e, stackTrace) {
      logError('Backend OAuth sign in failed for $id', e, stackTrace);
      throw AuthenticationFailedException(
        'Failed to sign in via $id backend OAuth',
        providerName: id,
        originalError: e,
      );
    } finally {
      _pendingCallback = null;
    }
  }

  // ---------------------------------------------------------------------------
  // Sign out
  // ---------------------------------------------------------------------------

  @override
  Future<void> signOut({String? userId}) async {
    // Server-side session revocation is the backend's responsibility.
    // Override and call your backend's sign-out endpoint if needed.
    logDebug('signOut called for $id — no-op (backend manages session)');
  }

  // ---------------------------------------------------------------------------
  // Token refresh
  // ---------------------------------------------------------------------------

  /// Returns `null` by default — proxy providers do not refresh tokens
  /// client-side.
  ///
  /// Override and POST to your backend's refresh endpoint to enable silent
  /// renewal. Return an [AuthTokenResult] with the new credentials.
  @override
  Future<AuthTokenResult?> refreshToken(String refreshToken) async => null;

  // ---------------------------------------------------------------------------
  // Deep-link handler (must be wired up by the app)
  // ---------------------------------------------------------------------------

  /// Call this when a deep link matching [ProxyOAuthConfig.appCallbackScheme]
  /// arrives in your app.
  ///
  /// Resolves the [signIn] call that is waiting for the backend callback.
  ///
  /// ```dart
  /// // In your deep-link stream handler:
  /// AppLinks().uriLinkStream.listen((uri) {
  ///   if (uri.toString().startsWith('myapp://auth/callback')) {
  ///     googleProxyProvider.handleDeepLink(uri);
  ///   }
  /// });
  /// ```
  void handleDeepLink(Uri uri) {
    if (_pendingCallback == null || _pendingCallback!.isCompleted) {
      logWarning('Received deep link for $id but no pending OAuth request');
      return;
    }

    logDebug('Resolving OAuth deep link for $id: $uri');
    _pendingCallback!.complete(uri);
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// POSTs to the initiation endpoint and returns the authorization URL.
  Future<String> _initiateFlow(Map<String, dynamic>? extraParams) async {
    try {
      final response = await _dio.post(
        config.initiationEndpoint,
        data: {
          'redirect_uri': config.backendRedirectUri,
          if (extraParams != null) ...extraParams,
        },
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            ...?config.headers,
          },
        ),
      );

      final data = response.data;
      if (data is! Map || !data.containsKey('authorization_url')) {
        throw AuthenticationFailedException(
          'Initiation endpoint did not return an "authorization_url"',
          providerName: id,
        );
      }

      return data['authorization_url'] as String;
    } on DioException catch (e) {
      throw AuthenticationFailedException(
        'Failed to initiate OAuth flow via backend (HTTP ${e.response?.statusCode})',
        providerName: id,
        originalError: e,
      );
    }
  }

  /// Launches [url] in an external browser.
  Future<void> _launchUrl(String url) async {
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
  }

  /// Exchanges the deep-link token for a user profile and session credentials.
  ///
  /// Checks the deep link for an `error` query param first. Then:
  /// - If [ProxyOAuthConfig.userInfoEndpoint] is set: fetches user info with
  ///   the token as a Bearer credential.
  /// - Otherwise: POSTs `{ token }` to [ProxyOAuthConfig.callbackEndpoint].
  Future<AuthSignInResult> _exchangeToken(Uri callbackUri) async {
    // Surface any OAuth error reported by the backend.
    final error = callbackUri.queryParameters['error'];
    if (error != null) {
      final description = callbackUri.queryParameters['error_description'];
      logError('Backend OAuth error for $id', {'error': error, 'description': description});
      if (error == 'access_denied') throw AuthenticationCancelledException(id);
      throw AuthenticationFailedException(
        description ?? error,
        providerName: id,
      );
    }

    final token = callbackUri.queryParameters['token'];
    if (token == null || token.isEmpty) {
      throw AuthenticationFailedException(
        'Deep-link callback for $id did not contain a "token" parameter',
        providerName: id,
      );
    }

    try {
      // Option A: GET userInfoEndpoint with the token as Bearer.
      if (config.userInfoEndpoint != null) {
        return await _fetchUserInfo(token);
      }

      // Option B: POST the token to callbackEndpoint to verify and get user.
      return await _postCallbackEndpoint(token);
    } on DioException catch (e) {
      throw AuthenticationFailedException(
        'Token exchange with backend failed for $id (HTTP ${e.response?.statusCode})',
        providerName: id,
        originalError: e,
      );
    }
  }

  /// GETs [ProxyOAuthConfig.userInfoEndpoint] with `Authorization: Bearer token`.
  Future<AuthSignInResult> _fetchUserInfo(String token) async {
    final response = await _dio.get(
      config.userInfoEndpoint!,
      options: Options(headers: {
        'Authorization': 'Bearer $token',
        ...?config.headers,
      }),
    );

    final user = config.userExtractor(response.data as Map<String, dynamic>);
    logInfo('User info fetched for $id: ${user.id}');

    return AuthSignInResult(user: user, accessToken: token);
  }

  /// POSTs `{ token }` to [ProxyOAuthConfig.callbackEndpoint] and returns the
  /// full [AuthSignInResult] including any session tokens from the backend.
  Future<AuthSignInResult> _postCallbackEndpoint(String token) async {
    final response = await _dio.post(
      config.callbackEndpoint,
      data: {'token': token},
      options: Options(headers: {
        'Content-Type': 'application/json',
        ...?config.headers,
      }),
    );

    final data = response.data as Map<String, dynamic>;
    final userJson = data['user'] as Map<String, dynamic>? ?? data;
    final user = config.userExtractor(userJson);

    final accessToken = data['access_token'] as String? ?? token;
    final refreshToken = data['refresh_token'] as String?;
    final expiresIn = data['expires_in'] as int?;
    final expiresAt = expiresIn != null ? DateTime.now().add(Duration(seconds: expiresIn)) : null;

    logInfo('Backend token exchange successful for $id: ${user.id}');

    return AuthSignInResult(
      user: user,
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: expiresAt,
    );
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:authyra/src/core/exceptions.dart';
import 'package:authyra/src/core/logger.dart';
import 'package:authyra/src/providers/auth_provider.dart';
import 'package:authyra/src/providers/oauth2/oauth2_config.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart';

/// Generic OAuth 2.0 provider implementation
class OAuth2Provider with AuthyraLogging implements AuthProvider {
  final OAuth2Config config;
  final Dio _dio;

  // PKCE values (Proof Key for Code Exchange)
  String? _codeVerifier;
  String? _codeChallenge;
  String? _state;

  // Completer for handling redirect callback
  Completer<Map<String, String>>? _authCompleter;

  OAuth2Provider({
    required this.config,
    Dio? dio,
  }) : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 30),
              receiveTimeout: const Duration(seconds: 30),
            ));

  @override
  String get id => config.providerName;

  @override
  String get name => config.providerName;

  @override
  AuthProviderType get type => AuthProviderType.oauth2;

  @override
  bool get supportsRefresh => true;

  @override
  bool get supportsSignOut => false;

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

      // Step 10: Parse expiry from the token response (if present).
      final expiresIn = tokens['expires_in'];
      final expiresAt = expiresIn != null
          ? DateTime.now().add(Duration(seconds: int.parse(expiresIn)))
          : null;

      logInfo('OAuth2 sign in successful for $id');

      // Return the full result including tokens — never discard them.
      return AuthSignInResult(
        user: user,
        accessToken: tokens['access_token'],
        refreshToken: tokens['refresh_token'],
        expiresAt: expiresAt,
      );
    } on AuthyraException {
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

  @override
  Future<void> signOut({String? userId}) async {
    // Most OAuth providers do not expose a token revocation endpoint that
    // requires explicit sign-out. Override in subclasses when needed
    // (e.g., Google's /revoke endpoint).
    logDebug('signOut called for ${config.providerName} — no-op');
  }

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
      throw TokenRefreshFailedException('Unexpected error during token refresh', e);
    }
  }

  // ==========================================
  // PKCE & Security
  // ==========================================

  /// Generate PKCE code verifier and challenge
  void _generatePkceValues() {
    // Generate random code verifier (43-128 characters)
    final random = Random.secure();
    final values = List<int>.generate(32, (_) => random.nextInt(256));

    _codeVerifier = base64UrlEncode(values).replaceAll('=', '').replaceAll('+', '-').replaceAll('/', '_');

    // Generate code challenge from verifier using SHA256
    final bytes = utf8.encode(_codeVerifier!);
    final digest = sha256.convert(bytes);
    _codeChallenge = base64UrlEncode(digest.bytes).replaceAll('=', '').replaceAll('+', '-').replaceAll('/', '_');

    // Generate state for CSRF protection
    _generateState();
  }

  /// Generate state parameter for CSRF protection
  void _generateState() {
    final random = Random.secure();
    final values = List<int>.generate(16, (_) => random.nextInt(256));
    _state = base64UrlEncode(values).replaceAll('=', '').replaceAll('+', '-').replaceAll('/', '_');
  }

  /// Verify state parameter from callback
  void _verifyState(Map<String, String> params) {
    final receivedState = params['state'];

    if (_state == null) {
      throw AuthenticationFailedException(
        'Internal error: state not generated',
        providerName: id,
      );
    }

    if (receivedState != _state) {
      throw AuthenticationFailedException(
        'State mismatch - possible CSRF attack detected',
        providerName: id,
      );
    }

    logDebug('State verified successfully');
  }

  /// Check for OAuth errors in callback
  void _checkForErrors(Map<String, String> params) {
    if (params.containsKey('error')) {
      final error = params['error']!;
      final errorDescription = params['error_description'];
      final errorUri = params['error_uri'];

      logError('OAuth error received', {
        'error': error,
        'description': errorDescription,
        'uri': errorUri,
      });

      // Handle specific OAuth errors
      if (error == 'access_denied') {
        throw AuthenticationCancelledException(id);
      }

      throw AuthenticationFailedException(
        errorDescription ?? error,
        providerName: id,
      );
    }
  }

  // ==========================================
  // OAuth Flow
  // ==========================================

  /// Build the authorization URL with all parameters
  String _buildAuthorizationUrl() {
    final params = {
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

    final uri = Uri.parse(config.authorizationEndpoint).replace(
      queryParameters: params,
    );

    return uri.toString();
  }

  /// Open authorization URL in browser and wait for callback
  Future<Map<String, String>> _openAuthorizationUrl(String url) async {
    _authCompleter = Completer<Map<String, String>>();

    try {
      final uri = Uri.parse(url);

      if (!await canLaunchUrl(uri)) {
        throw AuthenticationFailedException(
          'Cannot launch authorization URL',
          providerName: id,
        );
      }

      // Launch URL in external browser
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        throw AuthenticationFailedException(
          'Failed to launch authorization URL',
          providerName: id,
        );
      }

      logDebug('Authorization URL launched successfully');

      // Wait for redirect callback (with timeout)
      final result = await _authCompleter!.future.timeout(
        config.timeout,
        onTimeout: () {
          throw AuthenticationCancelledException(id);
        },
      );

      return result;
    } catch (e) {
      if (e is AuthyraException) rethrow;

      throw AuthenticationFailedException(
        'Error opening authorization URL',
        providerName: id,
        originalError: e,
      );
    }
  }

  /// Handle redirect callback from deep link
  void handleRedirectCallback(Uri uri) {
    if (_authCompleter == null || _authCompleter!.isCompleted) {
      logWarning('Received callback but no pending auth request');
      return;
    }

    logDebug('Processing redirect callback');

    // Extract query parameters from URI
    final params = uri.queryParameters;

    // Also check fragment for implicit flow (though we use code flow)
    if (params.isEmpty && uri.fragment.isNotEmpty) {
      final fragmentParams = Uri.splitQueryString(uri.fragment);
      _authCompleter!.complete(fragmentParams);
    } else {
      _authCompleter!.complete(params);
    }
  }

  /// Exchange authorization code for access token
  Future<Map<String, String>> _exchangeCodeForTokens(String code) async {
    logDebug('Exchanging authorization code for tokens');

    final data = {
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
        data: data,
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: config.tokenHeaders,
        ),
      );

      final tokens = response.data as Map<String, dynamic>;

      // Validate response
      if (!tokens.containsKey('access_token')) {
        throw AuthenticationFailedException(
          'No access token in response',
          providerName: id,
        );
      }

      return {
        'access_token': tokens['access_token'] as String,
        if (tokens['refresh_token'] != null) 'refresh_token': tokens['refresh_token'] as String,
        if (tokens['id_token'] != null) 'id_token': tokens['id_token'] as String,
      };
    } on DioException catch (e) {
      logError('Token exchange failed', e);

      final statusCode = e.response?.statusCode;
      final errorData = e.response?.data;

      throw AuthenticationFailedException(
        'Failed to exchange authorization code (HTTP $statusCode)',
        providerName: id,
        originalError: errorData ?? e,
      );
    }
  }

  /// Fetch user information from provider
  Future<Map<String, dynamic>> _fetchUserInfo(String accessToken) async {
    logDebug('Fetching user information');

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
          'Invalid user info response format',
          providerName: id,
        );
      }

      return userInfo as Map<String, dynamic>;
    } on DioException catch (e) {
      logError('Failed to fetch user info', e);

      throw AuthenticationFailedException(
        'Failed to fetch user information from ${config.providerName}',
        providerName: id,
        originalError: e,
      );
    }
  }

  /// Clean up temporary values
  void _cleanup() {
    _codeVerifier = null;
    _codeChallenge = null;
    _state = null;
    _authCompleter = null;
    logDebug('OAuth2 temporary values cleaned up');
  }
}

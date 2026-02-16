// ignore_for_file: unused_field

import 'dart:async';

import 'package:authyra/src/core/logger.dart';
import 'package:authyra/src/models/auth_user.dart';
import 'package:authyra/src/providers/auth_provider.dart';
import 'package:authyra/src/providers/proxy_oauth/proxy_oauth_config.dart';
import 'package:dio/dio.dart';

/// Backend-driven OAuth provider
///
/// Use this when your backend handles the OAuth flow with providers,
/// and your app just receives a custom token from your backend.
///
/// # Flow:
/// 1. App calls backend initiation endpoint
/// 2. Backend returns authorization URL
/// 3. App opens URL in browser
/// 4. User authenticates with provider (Google, etc.)
/// 5. Provider redirects to backend
/// 6. Backend exchanges code for tokens
/// 7. Backend creates user session
/// 8. Backend redirects to app with custom token
/// 9. App receives token via deep link
///
/// # Example Backend Endpoints:
///
/// ```
/// POST /auth/{provider}
/// Response: { "authorization_url": "https://...", "state": "..." }
///
/// GET /auth/{provider}/callback?code=...&state=...
/// → Backend handles OAuth, creates session
/// → Redirects to: myapp://auth/callback?token=CUSTOM_JWT
/// ```
class ProxyOauthProvider with AuthyraLogging implements AuthProvider {
  final ProxyOauthConfig config;
  final Dio _dio;

  String? _state;
  Completer<Map<String, String>>? _authCompleter;

  ProxyOauthProvider({
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
  bool get supportsRefresh => true;

  @override
  Future<AuthUser> signIn({Map<String, dynamic>? data}) {
    logInfo('Starting backend OAuth flow for ${config.providerName}');

    throw UnimplementedError();
  }

  @override
  Future<void> signOut({AuthUser? session}) async {
    logDebug('Sign out called for ${config.providerName}');
    // Backend should handle session invalidation
  }

  @override
  Future<AuthUser?> refreshToken(String refreshToken) {
    logDebug('Refreshing token via backend');
    throw UnimplementedError();
  }

  // ==========================================
  // Private Methods
  // ==========================================
}

import 'package:authyra/src/models/auth_user.dart';

/// Configuration for backend-driven OAuth
class ProxyOauthConfig {
  /// Your backend's OAuth initiation endpoint
  /// Example: https://api.yourapp.com/auth/google/init
  final String initiationEndpoint;

  /// Your backend's token exchange endpoint
  /// Example: https://api.yourapp.com/auth/google/callback
  final String callbackEndpoint;

  /// Your backend's user info endpoint (optional)
  /// If null, user info is expected in callback response
  final String? userInfoEndpoint;

  /// Redirect URI for your backend (not the app)
  /// Example: https://api.yourapp.com/auth/callback
  final String backendRedirectUri;

  /// Custom app deep link scheme for receiving backend token
  /// Example: myapp://auth/callback
  final String appCallbackScheme;

  /// Provider name (google, facebook, etc.)
  final String providerName;

  /// Additional headers for backend requests
  final Map<String, String>? headers;

  /// Function to extract user from backend response
  final AuthUser Function(Map<String, dynamic> json) userExtractor;

  /// Timeout for OAuth flow
  final Duration timeout;

  const ProxyOauthConfig({
    required this.initiationEndpoint,
    required this.callbackEndpoint,
    required this.backendRedirectUri,
    required this.appCallbackScheme,
    required this.providerName,
    required this.userExtractor,
    this.userInfoEndpoint,
    this.headers,
    this.timeout = const Duration(minutes: 5),
  });
}

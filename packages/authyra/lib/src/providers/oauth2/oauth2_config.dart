import 'package:authyra/src/models/auth_user.dart';

/// Configuration for OAuth 2.0 provider
class OAuth2Config {
  final String clientId;
  final String? clientSecret;
  final String authorizationEndpoint;
  final String tokenEndpoint;
  final String userInfoEndpoint;
  final String redirectUri;
  final List<String> scopes;
  final bool usePkce;
  final Map<String, String> additionalAuthParams;
  final Map<String, String> additionalTokenParams;
  final AuthUser Function(Map<String, dynamic> json) userExtractor;
  final String providerName;

  /// Optional: Custom headers for token request
  final Map<String, String>? tokenHeaders;

  /// Optional: Custom headers for user info request
  final Map<String, String>? userInfoHeaders;

  /// Timeout for OAuth operations
  final Duration timeout;

  const OAuth2Config({
    required this.clientId,
    this.clientSecret,
    required this.authorizationEndpoint,
    required this.tokenEndpoint,
    required this.userInfoEndpoint,
    required this.redirectUri,
    required this.scopes,
    required this.userExtractor,
    required this.providerName,
    this.usePkce = true,
    this.additionalAuthParams = const {},
    this.additionalTokenParams = const {},
    this.tokenHeaders,
    this.userInfoHeaders,
    this.timeout = const Duration(minutes: 5),
  });
}

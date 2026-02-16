import 'package:authyra/src/models/auth_user.dart';
import 'package:authyra/src/providers/oauth2/oauth2_config.dart';
import 'package:authyra/src/providers/oauth2/oauth2_provider.dart';

/// Google provider
class GoogleProvider extends OAuth2Provider {
  @override
  String get id => 'google';

  GoogleProvider({
    required String clientId,
    String? clientSecret,
    String? redirectUri,
    List<String> scopes = const ['openid', 'email', 'profile'],
  }) : super(
          config: OAuth2Config(
            clientId: clientId,
            clientSecret: clientSecret,
            authorizationEndpoint: 'https://accounts.google.com/o/oauth2/v2/auth',
            tokenEndpoint: 'https://oauth2.googleapis.com/token',
            userInfoEndpoint: 'https://www.googleapis.com/oauth2/v3/userinfo',
            redirectUri: redirectUri ?? 'com.googleusercontent.apps.$clientId:/oauth2redirect',
            scopes: scopes,
            providerName: 'google',
            usePkce: true,
            additionalAuthParams: {
              'access_type': 'offline', // Get refresh token
              'prompt': 'consent', // Force consent screen to get refresh token
            },
            userExtractor: _extractGoogleUser,
          ),
        );

  /// Extract user data from Google's userinfo response
  static AuthUser _extractGoogleUser(Map<String, dynamic> json) {
    return AuthUser(
      id: json['sub'] as String,
      email: json['email'] as String?,
      name: json['name'] as String?,
      avatarUrl: json['picture'] as String?,
      metadata: {
        'email_verified': json['email_verified'] ?? false,
        'locale': json['locale'],
        'given_name': json['given_name'],
        'family_name': json['family_name'],
        'hd': json['hd'], // Hosted domain for Google Workspace
      },
    );
  }
}

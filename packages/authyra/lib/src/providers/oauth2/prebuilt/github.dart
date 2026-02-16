import 'package:authyra/src/models/auth_user.dart';
import 'package:authyra/src/providers/oauth2/oauth2_config.dart';
import 'package:authyra/src/providers/oauth2/oauth2_provider.dart';

/// GitHub OAuth2 provider
class GitHubOAuth2Provider extends OAuth2Provider {
  @override
  String get id => 'github';

  GitHubOAuth2Provider({
    required String clientId,
    required String clientSecret,
    String redirectUri = 'authyra://callback',
    List<String> scopes = const ['user', 'user:email'],
  }) : super(
          config: OAuth2Config(
            clientId: clientId,
            clientSecret: clientSecret,
            authorizationEndpoint: 'https://github.com/login/oauth/authorize',
            tokenEndpoint: 'https://github.com/login/oauth/access_token',
            userInfoEndpoint: 'https://api.github.com/user',
            redirectUri: redirectUri,
            scopes: scopes,
            providerName: 'github',
            usePkce: false, // GitHub doesn't support PKCE yet
            additionalTokenParams: {
              'accept': 'application/json',
            },
            userExtractor: _extractGitHubUser,
          ),
        );

  /// Extract user data from GitHub's response
  static AuthUser _extractGitHubUser(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'].toString(),
      email: json['email'] as String?,
      name: json['name'] as String? ?? json['login'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      // provider: 'github',
      metadata: {
        'login': json['login'],
        'bio': json['bio'],
        'company': json['company'],
        'location': json['location'],
        'blog': json['blog'],
        'twitter_username': json['twitter_username'],
        'public_repos': json['public_repos'],
        'followers': json['followers'],
        'following': json['following'],
      },
    );
  }
}

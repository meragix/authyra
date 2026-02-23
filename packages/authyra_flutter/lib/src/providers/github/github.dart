import 'package:authyra/authyra.dart';
import 'package:authyra_flutter/src/providers/oauth2/oauth2_config.dart';
import 'package:authyra_flutter/src/providers/oauth2/oauth2_provider.dart';

/// Prebuilt [OAuth2Provider] for GitHub OAuth Apps.
///
/// Implements the GitHub OAuth 2.0 Authorization Code flow **without** PKCE,
/// because GitHub does not support the `code_challenge` parameter as of writing
/// (see [GitHub docs](https://docs.github.com/en/apps/oauth-apps/building-oauth-apps/authorizing-oauth-apps)).
/// A `client_secret` is therefore **required**.
///
/// > **Security note**: embedding a client secret in a mobile / desktop app
/// > exposes it to extraction. For production mobile apps, prefer routing the
/// > OAuth exchange through your backend using [ProxyOAuthProvider].
///
/// ## Setup
///
/// 1. Create an OAuth App in
///    [GitHub Developer Settings](https://github.com/settings/developers) and
///    set the **Authorization callback URL** to your app's redirect URI.
/// 2. Construct a [GitHubOAuth2Provider]:
///
/// ```dart
/// final githubProvider = GitHubOAuth2Provider(
///   clientId:     'YOUR_CLIENT_ID',
///   clientSecret: 'YOUR_CLIENT_SECRET',
///   redirectUri:  'myapp://auth/callback',
/// );
/// ```
///
/// 3. Register and wire deep-link handling:
///
/// ```dart
/// final client = AuthyraClient(
///   providers: [githubProvider],
///   storage: SecureAuthStorage(),
/// );
///
/// OAuth2CallbackHandler.registerProvider('myapp', githubProvider);
/// AppLinks().uriLinkStream.listen(OAuth2CallbackHandler.handleCallback);
/// ```
///
/// 4. Sign in:
///
/// ```dart
/// final user = await Authyra.instance.signIn('github');
/// ```
///
/// ## Scopes
///
/// Default scopes: `['user', 'user:email']`.
/// Add more as needed, e.g. `['user', 'user:email', 'repo']`.
///
/// ## Token refresh
///
/// GitHub access tokens do not expire by default (they are long-lived). If you
/// enable [fine-grained personal access tokens](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens#fine-grained-personal-access-tokens)
/// or expiring tokens in your GitHub App settings, override [refreshToken] to
/// call GitHub's token refresh endpoint.
///
/// ## User fields extracted
///
/// | [AuthUser] field | GitHub field       |
/// |-----------------|--------------------|
/// | `id`            | `id` (int → String)|
/// | `email`         | `email`            |
/// | `name`          | `name` or `login`  |
/// | `avatarUrl`     | `avatar_url`       |
/// | `metadata`      | `login`, `bio`, `company`, `location`, `blog`, `twitter_username`, `public_repos`, `followers`, `following` |
///
/// See also:
/// - [OAuth2Provider], the base class.
/// - [GoogleProvider], the prebuilt Google provider.
/// - [ProxyOAuthProvider], for backend-delegated flows (recommended for production mobile).
class GitHubOAuth2Provider extends OAuth2Provider {
  @override
  String get id => 'github';

  /// Creates a [GitHubOAuth2Provider].
  ///
  /// - [clientId]: The OAuth App's client ID from GitHub Developer Settings.
  /// - [clientSecret]: The OAuth App's client secret. Required because GitHub
  ///   does not support PKCE.
  /// - [redirectUri]: The URI GitHub redirects to after authorization.
  ///   Must exactly match the **Authorization callback URL** in GitHub settings.
  ///   Defaults to `'authyra://callback'`.
  /// - [scopes]: OAuth 2.0 scopes to request. Defaults to
  ///   `['user', 'user:email']`.
  GitHubOAuth2Provider({
    required String clientId,
    required String clientSecret,
    String redirectUri = 'authyra://callback',
    List<String> scopes = const ['user', 'user:email'],
  }) : super(
          config: OAuth2Config(
            providerName: 'github',
            clientId: clientId,
            clientSecret: clientSecret,
            authorizationEndpoint: 'https://github.com/login/oauth/authorize',
            tokenEndpoint: 'https://github.com/login/oauth/access_token',
            userInfoEndpoint: 'https://api.github.com/user',
            redirectUri: redirectUri,
            scopes: scopes,
            // GitHub does not support PKCE — client secret is required instead.
            usePkce: false,
            additionalTokenParams: const {
              // Ensure GitHub returns JSON instead of URL-encoded form data.
              'accept': 'application/json',
            },
            userExtractor: _extractGitHubUser,
          ),
        );

  /// Extracts an [AuthUser] from GitHub's `/user` API response.
  ///
  /// GitHub's `id` field is an integer — converted to `String` via `.toString()`
  /// to match [AuthUser.id]'s `String` type.
  ///
  /// GitHub API reference: https://docs.github.com/en/rest/users/users#get-the-authenticated-user
  static AuthUser _extractGitHubUser(Map<String, dynamic> json) {
    return AuthUser(
      // GitHub returns id as a JSON integer.
      id: json['id'].toString(),
      email: json['email'] as String?,
      // Fall back to the login (username) if the display name is not set.
      name: json['name'] as String? ?? json['login'] as String?,
      avatarUrl: json['avatar_url'] as String?,
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

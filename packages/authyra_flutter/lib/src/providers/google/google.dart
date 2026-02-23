import 'package:authyra/authyra.dart';
import 'package:authyra_flutter/src/providers/oauth2/oauth2_config.dart';
import 'package:authyra_flutter/src/providers/oauth2/oauth2_provider.dart';

/// Prebuilt [OAuth2Provider] for Google Sign-In.
///
/// Implements the Google OAuth 2.0 Authorization Code flow with PKCE,
/// targeting the `https://accounts.google.com/o/oauth2/v2/auth` endpoint.
/// Requesting `access_type: offline` and `prompt: consent` ensures Google
/// returns a refresh token on every consent, enabling silent session renewal.
///
/// ## Setup
///
/// 1. Create an OAuth 2.0 client ID in the
///    [Google Cloud Console](https://console.cloud.google.com/apis/credentials).
///    Choose **iOS** or **Android** (for mobile) or **Web** (for web / desktop).
/// 2. Construct a [GoogleProvider] with your `clientId`:
///
/// ```dart
/// final googleProvider = GoogleProvider(clientId: 'YOUR_CLIENT_ID');
/// ```
///
/// 3. Register it with [AuthyraClient] and wire the deep-link callback:
///
/// ```dart
/// final client = AuthyraClient(
///   providers: [googleProvider],
///   storage: SecureAuthStorage(),
/// );
///
/// // Deep-link handler (package:app_links or equivalent):
/// OAuth2CallbackHandler.registerProvider(
///   'com.googleusercontent.apps.YOUR_CLIENT_ID', // reverse client ID
///   googleProvider,
/// );
/// AppLinks().uriLinkStream.listen(OAuth2CallbackHandler.handleCallback);
/// ```
///
/// 4. Sign in:
///
/// ```dart
/// final user = await Authyra.instance.signIn('google');
/// print('Hello, ${user.name}!');
/// ```
///
/// ## Scopes
///
/// The default scopes are `['openid', 'email', 'profile']`. Pass additional
/// scopes at construction if your app needs more data (e.g.,
/// `'https://www.googleapis.com/auth/calendar'`):
///
/// ```dart
/// GoogleProvider(
///   clientId: 'YOUR_CLIENT_ID',
///   scopes: ['openid', 'email', 'profile', 'https://www.googleapis.com/auth/calendar'],
/// )
/// ```
///
/// ## Redirect URI
///
/// For native apps the redirect URI defaults to the
/// [reverse client ID scheme](https://developers.google.com/identity/protocols/oauth2/native-app#redirect-uri_1):
/// `com.googleusercontent.apps.<clientId>:/oauth2redirect`.
/// Override [redirectUri] if your app uses a different scheme.
///
/// ## User fields extracted
///
/// | [AuthUser] field | Google claim   |
/// |-----------------|----------------|
/// | `id`            | `sub`          |
/// | `email`         | `email`        |
/// | `name`          | `name`         |
/// | `avatarUrl`     | `picture`      |
/// | `metadata`      | `email_verified`, `locale`, `given_name`, `family_name`, `hd` |
///
/// See also:
/// - [OAuth2Provider], the base class.
/// - [OAuth2Config], the configuration object.
/// - [GitHubOAuth2Provider], the prebuilt GitHub provider.
class GoogleProvider extends OAuth2Provider {
  @override
  String get id => 'google';

  /// Creates a [GoogleProvider].
  ///
  /// - [clientId]: The OAuth 2.0 client ID from Google Cloud Console.
  /// - [clientSecret]: Required for confidential clients (backend / desktop
  ///   with secret). Omit for mobile PKCE flows.
  /// - [redirectUri]: Defaults to the reverse client ID scheme required by
  ///   native Google OAuth:
  ///   `com.googleusercontent.apps.<clientId>:/oauth2redirect`.
  /// - [scopes]: OAuth 2.0 scopes to request. Defaults to
  ///   `['openid', 'email', 'profile']`.
  GoogleProvider({
    required String clientId,
    String? clientSecret,
    String? redirectUri,
    List<String> scopes = const ['openid', 'email', 'profile'],
  }) : super(
          config: OAuth2Config(
            providerName: 'google',
            clientId: clientId,
            clientSecret: clientSecret,
            authorizationEndpoint:
                'https://accounts.google.com/o/oauth2/v2/auth',
            tokenEndpoint: 'https://oauth2.googleapis.com/token',
            userInfoEndpoint: 'https://www.googleapis.com/oauth2/v3/userinfo',
            redirectUri: redirectUri ??
                'com.googleusercontent.apps.$clientId:/oauth2redirect',
            scopes: scopes,
            usePkce: true,
            additionalAuthParams: const {
              // Ensures a refresh token is returned on first consent.
              'access_type': 'offline',
              // Forces the consent screen so a refresh token is always issued.
              // Remove 'prompt: consent' after the first sign-in if you store
              // the refresh token and don't want to re-prompt on every login.
              'prompt': 'consent',
            },
            userExtractor: _extractGoogleUser,
          ),
        );

  /// Extracts an [AuthUser] from Google's `/oauth2/v3/userinfo` response.
  ///
  /// Google claim reference:
  /// https://developers.google.com/identity/protocols/oauth2/openid-connect#an-id-tokens-payload
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
        // `hd` is the hosted domain; present only for Google Workspace accounts.
        'hd': json['hd'],
      },
    );
  }
}

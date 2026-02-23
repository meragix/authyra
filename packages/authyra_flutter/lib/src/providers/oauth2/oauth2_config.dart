import 'package:authyra/authyra.dart';

/// Configuration for an [OAuth2Provider] instance.
///
/// [OAuth2Config] is an immutable value object that describes everything an
/// [OAuth2Provider] needs to execute the Authorization Code flow with optional
/// PKCE — without hard-coding provider-specific logic into the provider itself.
///
/// Prebuilt configs are available via [GoogleProvider] and
/// [GitHubOAuth2Provider]. Use [OAuth2Config] directly when integrating a
/// custom identity provider.
///
/// ## Minimal example (custom provider)
///
/// ```dart
/// OAuth2Config(
///   providerName:            'discord',
///   clientId:                'YOUR_CLIENT_ID',
///   authorizationEndpoint:   'https://discord.com/oauth2/authorize',
///   tokenEndpoint:           'https://discord.com/api/oauth2/token',
///   userInfoEndpoint:        'https://discord.com/api/users/@me',
///   redirectUri:             'myapp://auth/callback',
///   scopes:                  ['identify', 'email'],
///   userExtractor: (json) => AuthUser(
///     id:    json['id']       as String,
///     email: json['email']    as String?,
///     name:  json['username'] as String?,
///   ),
/// )
/// ```
///
/// See also:
/// - [OAuth2Provider], which consumes this config.
/// - [GoogleProvider] / [GitHubOAuth2Provider], prebuilt subclasses.
class OAuth2Config {
  // ---------------------------------------------------------------------------
  // Identity provider endpoints
  // ---------------------------------------------------------------------------

  /// The identity provider's authorization endpoint URL.
  ///
  /// Users are redirected here to authenticate and grant consent.
  ///
  /// Example: `'https://accounts.google.com/o/oauth2/v2/auth'`
  final String authorizationEndpoint;

  /// The identity provider's token endpoint URL.
  ///
  /// Used to exchange the authorization code for access / refresh tokens.
  ///
  /// Example: `'https://oauth2.googleapis.com/token'`
  final String tokenEndpoint;

  /// The identity provider's userinfo endpoint URL.
  ///
  /// Called after token exchange to fetch the authenticated user's profile.
  /// The response JSON is passed directly to [userExtractor].
  ///
  /// Example: `'https://www.googleapis.com/oauth2/v3/userinfo'`
  final String userInfoEndpoint;

  // ---------------------------------------------------------------------------
  // Client credentials
  // ---------------------------------------------------------------------------

  /// The OAuth 2.0 client ID issued by the identity provider.
  final String clientId;

  /// The OAuth 2.0 client secret, if required by the identity provider.
  ///
  /// **Never embed a client secret in a Flutter / mobile app**. Use
  /// [ProxyOAuthProvider] to delegate the exchange to your backend, or use
  /// PKCE (`usePkce: true`) which does not require a client secret.
  ///
  /// For confidential clients (backend, CLI), this is required.
  final String? clientSecret;

  // ---------------------------------------------------------------------------
  // Flow parameters
  // ---------------------------------------------------------------------------

  /// The URI the identity provider redirects to after authorization.
  ///
  /// For native mobile apps this is typically a custom scheme:
  /// `'com.yourapp://oauth2redirect'`.
  ///
  /// For web apps: `'https://yourapp.com/auth/callback'`.
  final String redirectUri;

  /// OAuth 2.0 scopes to request.
  ///
  /// Scopes determine which user data the app can access after sign-in.
  ///
  /// Example: `['openid', 'email', 'profile']`
  final List<String> scopes;

  /// Whether to use PKCE (Proof Key for Code Exchange, RFC 7636).
  ///
  /// **Strongly recommended** for public clients (mobile, SPA) that cannot
  /// safely store a client secret. PKCE replaces the client secret with a
  /// per-request code challenge that prevents authorization code interception.
  ///
  /// Defaults to `true`. Set to `false` only for providers that do not support
  /// PKCE (e.g., GitHub, as of writing).
  final bool usePkce;

  // ---------------------------------------------------------------------------
  // User extraction
  // ---------------------------------------------------------------------------

  /// Extracts an [AuthUser] from the userinfo endpoint JSON response.
  ///
  /// The function receives the raw `Map<String, dynamic>` from the identity
  /// provider and must return a populated [AuthUser].
  ///
  /// ```dart
  /// userExtractor: (json) => AuthUser(
  ///   id:        json['sub']     as String,
  ///   email:     json['email']   as String?,
  ///   name:      json['name']    as String?,
  ///   avatarUrl: json['picture'] as String?,
  /// ),
  /// ```
  final AuthUser Function(Map<String, dynamic> json) userExtractor;

  // ---------------------------------------------------------------------------
  // Provider metadata
  // ---------------------------------------------------------------------------

  /// Lowercase slug identifying this provider.
  ///
  /// Used as [AuthProvider.id] and in log messages.
  ///
  /// Example: `'google'`, `'discord'`, `'github'`
  final String providerName;

  // ---------------------------------------------------------------------------
  // Advanced / optional
  // ---------------------------------------------------------------------------

  /// Extra query parameters appended to the authorization URL.
  ///
  /// Use to pass provider-specific hints, e.g.:
  /// - Google: `{'access_type': 'offline', 'prompt': 'consent'}`
  /// - Microsoft: `{'response_mode': 'query'}`
  final Map<String, String> additionalAuthParams;

  /// Extra body parameters included in the token endpoint request.
  ///
  /// Use for provider quirks, e.g.:
  /// - GitHub expects `{'accept': 'application/json'}` to get JSON back.
  final Map<String, String> additionalTokenParams;

  /// Custom headers attached to the token endpoint request.
  ///
  /// Useful for providers that require `Authorization: Basic …` for
  /// confidential client authentication.
  final Map<String, String>? tokenHeaders;

  /// Custom headers attached to the userinfo endpoint request.
  ///
  /// Defaults to `{'Authorization': 'Bearer <access_token>'}` added by
  /// [OAuth2Provider]. Override here if the provider expects a different
  /// auth scheme.
  final Map<String, String>? userInfoHeaders;

  /// How long [OAuth2Provider] waits for the user to complete the browser
  /// flow before throwing [AuthenticationCancelledException].
  ///
  /// Defaults to 5 minutes.
  final Duration timeout;

  /// Creates an [OAuth2Config].
  const OAuth2Config({
    required this.clientId,
    required this.authorizationEndpoint,
    required this.tokenEndpoint,
    required this.userInfoEndpoint,
    required this.redirectUri,
    required this.scopes,
    required this.userExtractor,
    required this.providerName,
    this.clientSecret,
    this.usePkce = true,
    this.additionalAuthParams = const {},
    this.additionalTokenParams = const {},
    this.tokenHeaders,
    this.userInfoHeaders,
    this.timeout = const Duration(minutes: 5),
  });

  /// Returns a copy of this config with the specified fields replaced.
  ///
  /// Useful in tests or for environment-specific overrides:
  ///
  /// ```dart
  /// final stagingConfig = prodConfig.copyWith(
  ///   redirectUri: 'myapp-staging://auth/callback',
  /// );
  /// ```
  OAuth2Config copyWith({
    String? clientId,
    String? clientSecret,
    String? authorizationEndpoint,
    String? tokenEndpoint,
    String? userInfoEndpoint,
    String? redirectUri,
    List<String>? scopes,
    bool? usePkce,
    AuthUser Function(Map<String, dynamic>)? userExtractor,
    String? providerName,
    Map<String, String>? additionalAuthParams,
    Map<String, String>? additionalTokenParams,
    Map<String, String>? tokenHeaders,
    Map<String, String>? userInfoHeaders,
    Duration? timeout,
  }) {
    return OAuth2Config(
      clientId: clientId ?? this.clientId,
      clientSecret: clientSecret ?? this.clientSecret,
      authorizationEndpoint:
          authorizationEndpoint ?? this.authorizationEndpoint,
      tokenEndpoint: tokenEndpoint ?? this.tokenEndpoint,
      userInfoEndpoint: userInfoEndpoint ?? this.userInfoEndpoint,
      redirectUri: redirectUri ?? this.redirectUri,
      scopes: scopes ?? this.scopes,
      usePkce: usePkce ?? this.usePkce,
      userExtractor: userExtractor ?? this.userExtractor,
      providerName: providerName ?? this.providerName,
      additionalAuthParams: additionalAuthParams ?? this.additionalAuthParams,
      additionalTokenParams:
          additionalTokenParams ?? this.additionalTokenParams,
      tokenHeaders: tokenHeaders ?? this.tokenHeaders,
      userInfoHeaders: userInfoHeaders ?? this.userInfoHeaders,
      timeout: timeout ?? this.timeout,
    );
  }
}

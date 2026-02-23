import 'package:authyra/src/models/auth_user.dart';

/// Configuration for a backend-driven ("proxy") OAuth provider.
///
/// Unlike [OAuth2Config], where the *app* drives the OAuth exchange directly
/// with the identity provider, [ProxyOAuthConfig] delegates every sensitive
/// step to *your backend*. The backend:
///
/// 1. Generates the authorization URL (and keeps the client secret safe).
/// 2. Receives the authorization code from the identity provider.
/// 3. Exchanges the code for tokens.
/// 4. Creates a server-side session, then deep-links the app with a short-lived
///    custom token.
///
/// This pattern is recommended for mobile / desktop clients that cannot safely
/// store an OAuth client secret.
///
/// ## Backend contract
///
/// | Field                  | Role                                           |
/// |------------------------|------------------------------------------------|
/// | [initiationEndpoint]   | `POST` — returns the authorization URL to open |
/// | [callbackEndpoint]     | `POST {token}` — verifies the deep-link token, returns user + session tokens |
/// | [userInfoEndpoint]     | `GET` (Bearer) — optional alternative to [callbackEndpoint] for user info |
///
/// ## Example
///
/// ```dart
/// ProxyOAuthConfig(
///   providerName: 'google',
///   initiationEndpoint: 'https://api.example.com/auth/google/initiate',
///   callbackEndpoint:   'https://api.example.com/auth/google/callback',
///   appCallbackScheme:  'myapp://auth/callback',
///   backendRedirectUri: 'https://api.example.com/auth/google/oauth-callback',
///   userExtractor: (json) => AuthUser(
///     id: json['id'] as String,
///     email: json['email'] as String?,
///     name: json['name'] as String?,
///   ),
/// )
/// ```
///
/// See also:
/// - [ProxyOAuthProvider], the provider that uses this config.
/// - [OAuth2Config], for direct (client-side) OAuth2 flows.
class ProxyOAuthConfig {
  /// Your backend endpoint that initiates the OAuth flow.
  ///
  /// [ProxyOAuthProvider] sends `POST initiationEndpoint` and expects a JSON
  /// body containing at least `{ "authorization_url": "https://..." }`.
  ///
  /// Example: `https://api.yourapp.com/auth/google/initiate`
  final String initiationEndpoint;

  /// Your backend endpoint that exchanges the deep-link token for a user
  /// profile and session credentials.
  ///
  /// [ProxyOAuthProvider] sends `POST callbackEndpoint` with
  /// `{ "token": "<deep-link-token>" }` and expects a JSON body that can be
  /// passed directly to [userExtractor].
  ///
  /// Example: `https://api.yourapp.com/auth/google/callback`
  final String callbackEndpoint;

  /// Optional endpoint for fetching user information.
  ///
  /// When set, [ProxyOAuthProvider] calls `GET userInfoEndpoint` with an
  /// `Authorization: Bearer <token>` header instead of POSTing to
  /// [callbackEndpoint]. The response is passed to [userExtractor].
  ///
  /// Leave `null` (default) to use [callbackEndpoint] for everything.
  final String? userInfoEndpoint;

  /// The redirect URI registered on *your backend* with the identity provider.
  ///
  /// The backend uses this when building the authorization URL. It is the
  /// server-side URL that the identity provider will redirect to after the
  /// user authenticates.
  ///
  /// Example: `https://api.yourapp.com/auth/google/oauth-callback`
  final String backendRedirectUri;

  /// The deep-link URI prefix the app will receive from the backend.
  ///
  /// After the backend completes the OAuth exchange it redirects to:
  /// `<appCallbackScheme>?token=<CUSTOM_JWT>`
  ///
  /// Example: `myapp://auth/callback`
  final String appCallbackScheme;

  /// Slug identifying the upstream identity provider.
  ///
  /// Sent to the backend initiation endpoint. Also used as [AuthProvider.id]
  /// and in log messages.
  ///
  /// Example: `'google'`, `'github'`, `'facebook'`
  final String providerName;

  /// Additional headers attached to every backend request.
  ///
  /// Useful for passing API keys or custom auth headers, e.g.:
  /// `{'X-Api-Key': 'secret'}`.
  final Map<String, String>? headers;

  /// Extracts an [AuthUser] from the JSON body returned by [callbackEndpoint]
  /// (or [userInfoEndpoint]).
  ///
  /// ```dart
  /// userExtractor: (json) => AuthUser(
  ///   id:    json['id']    as String,
  ///   email: json['email'] as String?,
  ///   name:  json['name']  as String?,
  /// ),
  /// ```
  final AuthUser Function(Map<String, dynamic> json) userExtractor;

  /// How long to wait for the user to complete the browser-based OAuth flow.
  ///
  /// Defaults to 5 minutes. If the timeout elapses before the deep link
  /// arrives, [ProxyOAuthProvider] throws [AuthenticationCancelledException].
  final Duration timeout;

  /// Creates a [ProxyOAuthConfig].
  const ProxyOAuthConfig({
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

/// Deprecated alias for [ProxyOAuthConfig].
///
/// Renamed for consistent OAuth acronym capitalisation. Migrate to
/// [ProxyOAuthConfig] and remove this alias in v0.2.0.
@Deprecated('Use ProxyOAuthConfig instead. This alias will be removed in v0.2.0.')
typedef ProxyOauthConfig = ProxyOAuthConfig;

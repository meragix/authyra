/// Configuration for Sign in with Apple.
///
/// Apple uses a unique OAuth2 variant:
///
/// - There is **no static client secret** — every token-endpoint call must
///   include a short-lived ES256 JWT generated from a `.p8` private key
///   (see [JwtUtils.generateAppleClientSecret]).
/// - There is **no userinfo endpoint** — the authenticated user's identity is
///   encoded in the `id_token` returned by the token endpoint.
/// - On the **first sign-in only**, Apple sends a `user` JSON object in the
///   callback URL, containing the user's name. This value is never sent again,
///   so you must persist the name immediately.
///
/// ## Setup
///
/// 1. In the [Apple Developer Portal](https://developer.apple.com/account/resources/identifiers/list/serviceId),
///    create a **Services ID** — this is your [clientId].
/// 2. Enable **Sign in with Apple** for the Services ID and configure your
///    [redirectUri] (must be HTTPS; localhost is not allowed).
/// 3. In [Keys](https://developer.apple.com/account/resources/authkeys/list),
///    create a key with **Sign in with Apple** enabled. Download the `.p8` file.
/// 4. Note your **Team ID** (top-right of the developer portal) and **Key ID**.
///
/// ```dart
/// final appleConfig = AppleOAuthConfig(
///   clientId:      'com.example.app.service',   // Services ID
///   teamId:        'AB12CD34EF',                 // 10-character Team ID
///   keyId:         'XYZXYZXYZX',                 // Key ID shown next to the key
///   privateKeyPem: File('AuthKey_XYZXYZXYZX.p8').readAsStringSync(),
///   redirectUri:   'https://example.com/auth/apple/callback',
/// );
/// ```
///
/// See also:
/// - [AppleProvider], the provider that consumes this config.
/// - [JwtUtils.generateAppleClientSecret], used internally for each token call.
/// - [Apple documentation](https://developer.apple.com/documentation/sign_in_with_apple/sign_in_with_apple_rest_api)
class AppleOAuthConfig {
  /// The Services ID created in the Apple Developer Portal.
  ///
  /// For native iOS/macOS apps this is typically the **bundle ID** (e.g.,
  /// `com.example.app`). For web and cross-platform use a separate **Services
  /// ID** (e.g., `com.example.app.web`).
  final String clientId;

  /// The 10-character Apple Team ID found in the top-right of the
  /// [Apple Developer Portal](https://developer.apple.com/).
  final String teamId;

  /// The Key ID shown next to your Sign in with Apple key in
  /// [Keys](https://developer.apple.com/account/resources/authkeys/list).
  final String keyId;

  /// The full contents of the `.p8` private key file downloaded from the
  /// Apple Developer Portal, including the `-----BEGIN PRIVATE KEY-----` header
  /// and `-----END PRIVATE KEY-----` footer.
  ///
  /// Never commit this value to source control. Load it from a secure secret
  /// store (environment variable, secrets manager, encrypted file).
  final String privateKeyPem;

  /// The HTTPS redirect URI registered for this Services ID in the
  /// Apple Developer Portal.
  ///
  /// Apple requires a full HTTPS URI (no localhost). For native deep links,
  /// register your URI using Apple's associated domains or Universal Links.
  final String redirectUri;

  /// OAuth 2.0 scopes to request.
  ///
  /// Apple supports `name` and `email`. Defaults to both.
  ///
  /// **Note**: Apple only sends name and email data on the user's very first
  /// sign-in — subsequent logins will not include these values regardless of
  /// the scopes requested.
  final List<String> scopes;

  /// How long the generated ES256 client-secret JWT should be valid.
  ///
  /// Apple enforces a maximum of 180 days. Defaults to 180 days.
  /// There is no need to set this lower — the token is regenerated on every
  /// token-endpoint call regardless.
  final Duration clientSecretValidity;

  /// Maximum time to wait for the user to complete the Apple authorization
  /// flow in the browser before throwing [AuthenticationCancelledException].
  ///
  /// Defaults to 5 minutes.
  final Duration timeout;

  /// Creates an [AppleOAuthConfig].
  const AppleOAuthConfig({
    required this.clientId,
    required this.teamId,
    required this.keyId,
    required this.privateKeyPem,
    required this.redirectUri,
    this.scopes = const ['name', 'email'],
    this.clientSecretValidity = const Duration(days: 180),
    this.timeout = const Duration(minutes: 5),
  });
}

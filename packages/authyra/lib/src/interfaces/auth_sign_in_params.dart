/// Typed parameter hierarchy for [AuthProvider.signIn].
///
/// Each [AuthProvider] implementation declares which concrete subclass it
/// expects. [AuthyraClient.signIn] forwards the params verbatim; cast to the
/// expected type inside your provider.
///
/// Built-in subclasses:
/// - [CredentialsSignInParams]: email + password
/// - [OAuth2SignInParams]: post-redirect code + state
abstract class AuthSignInParams {
  const AuthSignInParams();
}

/// Parameters for email + password (or any custom credentials) sign-in.
///
/// ```dart
/// await client.signIn('email', params: CredentialsSignInParams(
///   email: 'alice@example.com',
///   password: 's3cr3t',
/// ));
/// ```
class CredentialsSignInParams extends AuthSignInParams {
  /// The user's email address.
  final String email;

  /// The user's password.
  final String password;

  const CredentialsSignInParams({
    required this.email,
    required this.password,
  });
}

/// Parameters for an OAuth 2.0 / OIDC Authorization Code flow.
///
/// Typically supplied after the provider redirects back with [code] and [state].
///
/// ```dart
/// await client.signIn('google', params: OAuth2SignInParams(
///   code: uri.queryParameters['code'],
///   state: uri.queryParameters['state'],
/// ));
/// ```
class OAuth2SignInParams extends AuthSignInParams {
  /// The authorization code returned by the identity provider.
  final String? code;

  /// CSRF state value to verify the callback originated from this client.
  final String? state;

  /// Override the redirect URI for this specific sign-in attempt.
  final String? redirectUri;

  /// OAuth 2.0 scopes to request (provider-specific).
  final List<String>? scopes;

  const OAuth2SignInParams({
    this.code,
    this.state,
    this.redirectUri,
    this.scopes,
  });
}

// v2 — not yet implemented:
//
// class MagicLinkSignInParams extends AuthSignInParams {
//   final String email;
//   final String? token; // null during request phase, required for verification
//   const MagicLinkSignInParams({required this.email, this.token});
// }
//
// class PhoneSignInParams extends AuthSignInParams {
//   final String phoneNumber; // E.164 format, e.g. '+33612345678'
//   final String? otp;        // null during request phase, required for verification
//   const PhoneSignInParams({required this.phoneNumber, this.otp});
// }

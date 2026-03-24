/// Typed parameter hierarchy for [AuthProvider.signIn].
///
/// Each [AuthProvider] implementation declares which concrete subclass it
/// expects. [AuthyraClient.signIn] forwards the params verbatim — cast to the
/// expected type inside your provider.
///
/// Built-in subclasses:
/// - [CredentialsSignInParams] — email + password
/// - [OAuth2SignInParams]      — post-redirect code + state
/// - [MagicLinkSignInParams]   — passwordless email / token verification
/// - [PhoneSignInParams]       — SMS OTP
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

/// Parameters for a passwordless magic-link flow.
///
/// During the *request* phase, supply only [email].
/// During the *verification* phase, supply both [email] and [token].
///
/// ```dart
/// // Step 1 — send the link
/// await client.signIn('magic', params: MagicLinkSignInParams(email: 'alice@example.com'));
///
/// // Step 2 — verify the token from the link
/// await client.signIn('magic', params: MagicLinkSignInParams(
///   email: 'alice@example.com',
///   token: tokenFromUrl,
/// ));
/// ```
class MagicLinkSignInParams extends AuthSignInParams {
  /// The email address to send the magic link to.
  final String email;

  /// The token extracted from the magic link URL (only required for verification).
  final String? token;

  const MagicLinkSignInParams({required this.email, this.token});
}

/// Parameters for an SMS one-time-password flow.
///
/// During the *request* phase, supply only [phoneNumber].
/// During the *verification* phase, supply both [phoneNumber] and [otp].
///
/// ```dart
/// // Step 1 — send the OTP
/// await client.signIn('phone', params: PhoneSignInParams(phoneNumber: '+33612345678'));
///
/// // Step 2 — verify
/// await client.signIn('phone', params: PhoneSignInParams(
///   phoneNumber: '+33612345678',
///   otp: '123456',
/// ));
/// ```
class PhoneSignInParams extends AuthSignInParams {
  /// The E.164-formatted phone number (e.g., `'+33612345678'`).
  final String phoneNumber;

  /// The OTP code sent by SMS (only required for verification).
  final String? otp;

  const PhoneSignInParams({required this.phoneNumber, this.otp});
}

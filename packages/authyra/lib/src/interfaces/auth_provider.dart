import 'package:authyra/src/interfaces/auth_sign_in_params.dart';
import 'package:authyra/src/models/auth_sign_in_result.dart';
import 'package:authyra/src/models/auth_token_result.dart';

/// The authentication strategy implemented by a provider.
///
/// Used by [AuthyraClient] to apply strategy-specific validation and
/// to generate meaningful log messages and error descriptions.
enum AuthProviderType {
  /// Email + password or any custom credentials form.
  credentials,

  /// OAuth 2.0 / OIDC Authorization Code flow (with optional PKCE).
  oauth2,

  // v2 — not yet implemented:
  // magicLink,  // Passwordless email / magic-link flow.
  // phone,      // SMS one-time-password flow.

  /// Custom or composite strategy not covered by the above.
  custom,
}

/// Abstract interface for all Authyra authentication providers.
///
/// Implement this interface to plug a new authentication strategy into
/// [AuthyraClient]. Authyra ships with several built-in providers
/// ([CredentialsProvider], [OAuth2Provider], [GoogleProvider], etc.) but
/// any custom strategy can be added by implementing [AuthProvider].
///
/// ## Design contract
///
/// - [id] must be a unique, lowercase slug within a single [AuthyraClient].
/// - [signIn] is the only **required** method; [signOut] and [refreshToken]
///   have safe default no-op implementations.
/// - Providers are **stateless**: they hold configuration, not session state.
///   Session state lives in [SessionManager].
/// - [signIn] accepts typed [AuthSignInParams]; cast to your expected subclass
///   (e.g., [CredentialsSignInParams]) inside your override.
///
/// ## Minimal example
///
/// ```dart
/// class MyBackendProvider implements AuthProvider {
///   @override
///   String get id => 'my-backend';
///
///   @override
///   AuthProviderType get type => AuthProviderType.credentials;
///
///   @override
///   bool get supportsRefresh => true;
///
///   @override
///   Future<AuthSignInResult?> signIn({AuthSignInParams? params}) async {
///     final creds = params as CredentialsSignInParams?;
///     final response = await myApi.post('/auth/login', body: {
///       'email': creds?.email,
///       'password': creds?.password,
///     });
///     if (response.statusCode != 200) return null;
///     return AuthSignInResult(
///       user: AuthUser(id: response.data['userId']),
///       accessToken: response.data['accessToken'],
///       refreshToken: response.data['refreshToken'],
///       expiresAt: DateTime.parse(response.data['expiresAt']),
///     );
///   }
///
///   @override
///   Future<AuthTokenResult?> refreshToken(String refreshToken) async {
///     final res = await myApi.post('/auth/refresh',
///       body: {'refreshToken': refreshToken});
///     if (res.statusCode != 200) return null;
///     return AuthTokenResult(
///       accessToken: res.data['accessToken'],
///       expiresAt: DateTime.parse(res.data['expiresAt']),
///     );
///   }
/// }
/// ```
///
/// See also:
/// - [AuthyraClient], which registers and invokes providers.
/// - [AuthSignInParams], the typed parameter hierarchy.
/// - [AuthSignInResult], the rich sign-in result that carries user + account + tokens.
/// - [AuthTokenResult], the token-only result for refresh operations.
/// - [AuthSession], the session built from a successful [signIn].
abstract class AuthProvider {
  /// Unique identifier for this provider.
  ///
  /// Lowercase slug (e.g., `'google'`, `'credentials'`, `'github'`).
  /// Must be unique within a single [AuthyraClient]; duplicate IDs are
  /// rejected during registration.
  String get id;

  /// Human-readable display name for this provider.
  ///
  /// Used in logs, error messages, and optionally in UI
  /// (e.g., "Sign in with {name}" buttons). Defaults to [id].
  String get name => id;

  /// The authentication strategy implemented by this provider.
  ///
  /// Enables [AuthyraClient] to apply strategy-specific validation
  /// (e.g., skipping email/password checks for OAuth2 providers).
  AuthProviderType get type => AuthProviderType.custom;

  /// Whether this provider can renew an expired access token silently.
  ///
  /// When `true`, [AuthyraClient] will call [refreshToken] before prompting
  /// the user to re-authenticate. Defaults to `false`; opt-in explicitly.
  bool get supportsRefresh => false;

  /// Whether this provider requires a server-side call during sign-out.
  ///
  /// When `true`, [AuthyraClient] calls [signOut] to revoke tokens or
  /// invalidate server sessions before clearing the local session.
  /// Defaults to `false`.
  bool get supportsSignOut => false;

  /// Authenticates the user and returns the full result, or `null` on failure.
  ///
  /// [params] carries provider-specific input as a typed [AuthSignInParams]
  /// subclass. Cast to the expected type inside your override:
  ///
  /// | Strategy    | Expected type             |
  /// |-------------|---------------------------|
  /// | credentials | [CredentialsSignInParams] |
  /// | oauth2      | [OAuth2SignInParams]       |
  ///
  /// Return `null` when authentication simply fails (e.g., wrong password).
  /// Throw an [AuthException] subclass for infrastructure errors
  /// (network failure, CSRF mismatch, invalid provider config).
  ///
  /// **Always populate [AuthSignInResult.account] and token fields** when the
  /// provider returns them; they are stored in the session and enable
  /// account-linking and silent refresh.
  Future<AuthSignInResult?> signIn({AuthSignInParams? params});

  /// Revokes server-side credentials for [userId].
  ///
  /// Only called by [AuthyraClient] when [supportsSignOut] is `true`.
  /// Default implementation is a no-op; override only when needed.
  ///
  /// **Must never throw**; catch and log errors internally to avoid
  /// blocking the local session cleanup.
  Future<void> signOut({String? userId}) async {}

  /// Exchanges [refreshToken] for a fresh access token.
  ///
  /// Only called when [supportsRefresh] is `true`. Returns `null` when
  /// the refresh token is invalid or expired (the client will then require
  /// a full re-authentication).
  ///
  /// Default implementation returns `null`. Override to enable silent refresh.
  Future<AuthTokenResult?> refreshToken(String refreshToken) async => null;
}

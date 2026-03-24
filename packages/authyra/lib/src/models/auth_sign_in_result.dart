import 'package:authyra/src/models/auth_account.dart';
import 'package:authyra/src/models/auth_user.dart';

/// The full result of a successful [AuthProvider.signIn] call.
///
/// [AuthSignInResult] bundles the authenticated [user] with any tokens and
/// account data returned by the identity provider. All fields except [user]
/// are optional to support cookie-based flows where tokens are managed
/// server-side.
///
/// [AuthyraClient] uses this object to construct an [AuthSession] and to
/// persist the [account] entry. Providers should populate [accessToken],
/// [refreshToken], [expiresAt], and [account] whenever the data is available.
///
/// ```dart
/// // In an OAuth2 provider after the code/token exchange:
/// return AuthSignInResult(
///   user: extractUser(userInfo),
///   account: AuthAccount(
///     id: 'google_${userInfo['sub']}',
///     userId: extractUser(userInfo).id,
///     providerId: 'google',
///     providerAccountId: userInfo['sub'],
///     providerData: {'hd': userInfo['hd']},
///   ),
///   accessToken: tokens['access_token'],
///   refreshToken: tokens['refresh_token'],
///   expiresAt: DateTime.now().add(
///     Duration(seconds: tokens['expires_in'] as int),
///   ),
/// );
/// ```
class AuthSignInResult {
  /// The authenticated user's identity profile.
  final AuthUser user;

  /// The provider-linked account entry for this sign-in.
  ///
  /// When `null`, [AuthyraClient] generates a minimal [AuthAccount] using the
  /// provider ID and user ID as the `providerAccountId`.
  final AuthAccount? account;

  /// Short-lived access token for API requests, if returned by the provider.
  final String? accessToken;

  /// Long-lived refresh token for silent renewal, if returned by the provider.
  final String? refreshToken;

  /// When [accessToken] expires. Falls back to [AuthConfig.tokenLifetimeDuration]
  /// in [AuthyraClient] when `null`.
  final DateTime? expiresAt;

  /// Creates an [AuthSignInResult].
  ///
  /// Only [user] is required. All other fields are optional to support
  /// server-side session flows where tokens are managed opaquely by the backend.
  const AuthSignInResult({
    required this.user,
    this.account,
    this.accessToken,
    this.refreshToken,
    this.expiresAt,
  });

  /// Convenience constructor for flows where the provider only returns the
  /// user profile (e.g., cookie-based backends, proxy OAuth).
  const AuthSignInResult.userOnly(AuthUser user) : this(user: user);
}

/// Token data returned by a successful [AuthProvider.refreshToken] call.
///
/// [AuthyraClient] uses this to build an updated [AuthSession] via
/// [AuthSession.refreshed], preserving the existing [AuthUser] profile.
///
/// ```dart
/// return AuthTokenResult(
///   accessToken: response['access_token'],
///   refreshToken: response['refresh_token'], // null if not rotated
///   expiresAt: DateTime.now().add(
///     Duration(seconds: response['expires_in'] as int),
///   ),
/// );
/// ```
class AuthTokenResult {
  /// The newly issued access token.
  final String accessToken;

  /// A new refresh token, if the provider uses rotating tokens.
  ///
  /// When `null`, the existing refresh token is retained by [AuthyraClient]
  /// (see [AuthSession.refreshed]).
  final String? refreshToken;

  /// When [accessToken] expires.
  final DateTime expiresAt;

  /// Creates an [AuthTokenResult].
  const AuthTokenResult({
    required this.accessToken,
    this.refreshToken,
    required this.expiresAt,
  });
}

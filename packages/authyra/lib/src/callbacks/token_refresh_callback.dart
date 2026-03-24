import 'package:authyra/src/models/auth_session.dart';

/// Signature for a custom token refresh function.
///
/// Receives the current [AuthSession] and must return an updated session
/// with fresh tokens. Used as an escape hatch for custom refresh logic that
/// does not fit the standard [AuthProvider.refreshToken] contract.
///
/// Return a new session built from [AuthSession.refreshed] to preserve all
/// other session fields and update only the token data:
///
/// ```dart
/// Future<AuthSession> myRefresh(AuthSession session) async {
///   final response = await http.post(
///     Uri.parse('https://api.example.com/auth/refresh'),
///     body: {'refresh_token': session.refreshToken},
///   );
///   final data = jsonDecode(response.body) as Map<String, dynamic>;
///   return session.refreshed(
///     newAccessToken: data['access_token'] as String,
///     newExpiresAt: DateTime.now().add(
///       Duration(seconds: data['expires_in'] as int),
///     ),
///   );
/// }
/// ```
///
/// See also:
/// - [AuthSession.refreshed], the preferred way to derive an updated session.
/// - [AuthProvider.refreshToken], the standard token-renewal contract.
typedef TokenRefreshCallback = Future<AuthSession> Function(
    AuthSession session);

import 'package:authyra/src/models/auth_session.dart';

/// Callback function type for refreshing access tokens
///
/// Implement this to provide your custom token refresh logic.
/// The function should return an updated [AuthSession] with new tokens.
///
/// Example:
/// ```dart
/// Future<AuthSession> refreshToken(AuthSession account) async {
///   final response = await http.post(
///     Uri.parse('https://api.example.com/refresh'),
///     body: {'refresh_token': account.refreshToken},
///   );
///   final data = jsonDecode(response.body);
///   return account.copyWith(
///     accessToken: data['access_token'],
///     expiresAt: DateTime.now().add(Duration(seconds: data['expires_in'])).millisecondsSinceEpoch,
///   );
/// }
/// ```
typedef TokenRefreshCallback = Future<AuthSession> Function(AuthSession session);

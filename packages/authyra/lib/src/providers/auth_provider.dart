import 'package:authyra/src/models/auth_user.dart';

/// Abstract provider interface for implementing authentication strategies
///
/// Implement this interface to create custom authentication providers
/// (Google, GitHub, Email/Password, Supabase, etc.)
///
/// Example:
/// ```dart
/// class GoogleAuthProvider implements AuthProvider {
///   @override
///   String get id => 'google';
///
///   @override
///   Future<AuthUser> signIn({Map<String, dynamic>? data}) async {
///     // ... convert to AuthSession
///   }
/// }
/// ```
abstract class AuthProvider {
  /// Unique identifier of the provider (e.g., 'google', 'email-password')
  String get id;

  /// The main login method.
  /// It returns an [AuthUser] containing the user and their tokens.
  Future<AuthUser?> signIn({Map<String, dynamic>? data});

  /// Provider-specific logout (e.g., revoke a token on the server side)
  Future<void> signOut();

  /// Refreshes the session.
  /// Returns the new session with updated tokens.
  Future<AuthUser?> refreshToken(String refreshToken);

  /// Check if this provider supports token refresh
  bool get supportsRefresh => true;
}

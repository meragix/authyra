import 'package:equatable/equatable.dart';
import 'package:authyra/src/models/auth_user.dart';

/// The high-level authentication state of the current user.
///
/// [AuthState] is a **sealed-style value object** that represents one of three
/// mutually exclusive states: authenticated, unauthenticated, or error.
/// It is the primary type emitted by `AuthyraInstance.authStateChanges`.
///
/// ## Usage in reactive UIs
///
/// Because [AuthState] implements value equality via [Equatable], identical
/// consecutive states are deduplicated in streams — preventing unnecessary
/// widget rebuilds or side-effect re-executions.
///
/// ```dart
/// authyra.authStateChanges.listen((state) {
///   if (state.isAuthenticated) {
///     router.go('/dashboard');
///   } else if (state.hasError) {
///     showErrorSnackbar(state.error!);
///   } else {
///     router.go('/login');
///   }
/// });
/// ```
///
/// ## Pattern matching
///
/// Use [type] with a `switch` for exhaustive handling:
///
/// ```dart
/// switch (state.type) {
///   case AuthStateType.authenticated:
///     return DashboardPage(user: state.user!);
///   case AuthStateType.unauthenticated:
///     return LoginPage();
///   case AuthStateType.error:
///     return ErrorPage(message: state.error!);
/// }
/// ```
///
/// See also:
/// - [AuthStateType], the enum that drives the discriminated union.
/// - [AuthSession], the richer session object used internally by the client.
/// - [AuthUser], the user identity surfaced when [isAuthenticated] is `true`.
class AuthState extends Equatable {
  /// The discriminant of this state.
  ///
  /// Use this for exhaustive `switch` matching. See [AuthStateType].
  final AuthStateType type;

  /// The authenticated user, available when [isAuthenticated] is `true`.
  ///
  /// Always `null` for [AuthStateType.unauthenticated] and
  /// [AuthStateType.error] states.
  final AuthUser? user;

  /// Human-readable error message, available when [hasError] is `true`.
  ///
  /// Always `null` for [AuthStateType.authenticated] and
  /// [AuthStateType.unauthenticated] states.
  final String? error;

  const AuthState._(this.type, this.user, this.error);

  // ---------------------------------------------------------------------------
  // Factories
  // ---------------------------------------------------------------------------

  /// Creates an authenticated state carrying the signed-in [user].
  ///
  /// ```dart
  /// final state = AuthState.authenticated(currentUser);
  /// assert(state.isAuthenticated);
  /// assert(state.user != null);
  /// ```
  factory AuthState.authenticated(AuthUser user) {
    return AuthState._(AuthStateType.authenticated, user, null);
  }

  /// Creates an unauthenticated state (no active session).
  ///
  /// This is the initial state before any sign-in attempt and the state
  /// emitted after a successful sign-out.
  ///
  /// ```dart
  /// final state = AuthState.unauthenticated();
  /// assert(state.isUnauthenticated);
  /// ```
  factory AuthState.unauthenticated() {
    return const AuthState._(AuthStateType.unauthenticated, null, null);
  }

  /// Creates an error state carrying a human-readable [error] message.
  ///
  /// Emitted when authentication fails (e.g., wrong credentials, network
  /// error, revoked token). The previous session is considered invalidated.
  ///
  /// ```dart
  /// final state = AuthState.error('Invalid credentials');
  /// assert(state.hasError);
  /// print(state.error); // Invalid credentials
  /// ```
  factory AuthState.error(String error) {
    return AuthState._(AuthStateType.error, null, error);
  }

  // ---------------------------------------------------------------------------
  // Convenience accessors
  // ---------------------------------------------------------------------------

  /// Whether the user is currently signed in.
  ///
  /// When `true`, [user] is guaranteed to be non-null.
  bool get isAuthenticated => type == AuthStateType.authenticated;

  /// Whether no user is currently signed in.
  ///
  /// `true` both before the first sign-in and after sign-out.
  bool get isUnauthenticated => type == AuthStateType.unauthenticated;

  /// Whether the last authentication operation resulted in an error.
  ///
  /// When `true`, [error] is guaranteed to be non-null.
  bool get hasError => type == AuthStateType.error;

  // ---------------------------------------------------------------------------
  // Equatable / Object
  // ---------------------------------------------------------------------------

  @override
  List<Object?> get props => [type, user, error];

  @override
  String toString() =>
      'AuthState(type: $type, userId: ${user?.id}, error: $error)';
}

/// Discriminant enum for [AuthState].
///
/// Used in exhaustive `switch` expressions to pattern-match on the current
/// authentication state without casting.
///
/// ```dart
/// switch (state.type) {
///   case AuthStateType.authenticated:   ...
///   case AuthStateType.unauthenticated: ...
///   case AuthStateType.error:           ...
/// }
/// ```
enum AuthStateType {
  /// A user is signed in and the session is valid.
  authenticated,

  /// No user is signed in (initial state or after sign-out).
  unauthenticated,

  /// Authentication failed or the session was invalidated.
  error,
}

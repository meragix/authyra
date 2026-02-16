import 'package:authyra/src/models/auth_user.dart';

class AuthState {
  final AuthStateType type;
  final AuthUser? user;
  final String? error;

  const AuthState._(this.type, this.user, this.error);

  factory AuthState.authenticated(AuthUser user) {
    return AuthState._(AuthStateType.authenticated, user, null);
  }

  factory AuthState.unauthenticated() {
    return const AuthState._(AuthStateType.unauthenticated, null, null);
  }

  factory AuthState.error(String error) {
    return AuthState._(AuthStateType.error, null, error);
  }

  bool get isAuthenticated => type == AuthStateType.authenticated;
  bool get isUnauthenticated => type == AuthStateType.unauthenticated;
  bool get hasError => type == AuthStateType.error;

  @override
  String toString() => 'AuthState($type, user: ${user?.id}, error: $error)';
}

enum AuthStateType { authenticated, unauthenticated, error }

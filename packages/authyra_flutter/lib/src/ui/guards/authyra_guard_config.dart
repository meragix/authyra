import 'package:authyra/authyra.dart';
import 'package:flutter/widgets.dart';

/// Configuration for AuthyraGuard
class AuthyraGuardConfig {
  /// Route to redirect to when user is not authenticated
  final String? loginRoute;

  /// Widget to show when user is not authenticated (alternative to loginRoute)
  final Widget Function(BuildContext context)? loginBuilder;

  /// Route to redirect to when user is authenticated but shouldn't be
  /// (e.g., already logged in user accessing login page)
  final String? homeRoute;

  /// Widget to show while checking authentication status
  final Widget Function(BuildContext context)? loadingBuilder;

  /// Whether to allow access to the route when authentication check fails
  final bool allowOnError;

  /// Custom authentication check (optional)
  /// Return true to allow access, false to deny
  final Future<bool> Function(AuthSession? session)? customCheck;

  const AuthyraGuardConfig({
    this.loginRoute,
    this.loginBuilder,
    this.homeRoute,
    this.loadingBuilder,
    this.allowOnError = false,
    this.customCheck,
  }) : assert(
          loginRoute != null || loginBuilder != null,
          'Either loginRoute or loginBuilder must be provided',
        );
}

import 'package:flutter/material.dart';
import 'package:authyra/authyra.dart';
import 'package:authyra_flutter/src/ui/guards/authyra_guard_config.dart';

/// Guard for routes that should only be accessible when NOT authenticated
/// (e.g., Login page, Register page)
///
/// # Example
/// ```dart
/// AuthyraInverseGuard(
///   config: AuthyraGuardConfig(
///     homeRoute: '/home',  // Redirect to home if already logged in
///   ),
///   child: LoginPage(),
/// )
/// ```
class AuthyraInverseGuard extends StatefulWidget {
  final AuthyraGuardConfig config;
  final Widget child;

  const AuthyraInverseGuard({
    super.key,
    required this.config,
    required this.child,
  });

  @override
  State<AuthyraInverseGuard> createState() => _AuthyraInverseGuardState();
}

class _AuthyraInverseGuardState extends State<AuthyraInverseGuard> {
  bool _isLoading = true;
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    try {
      final session = await Authyra.instance.getSession();
      final isAuth = session != null && !session.isExpired;

      if (mounted) {
        setState(() {
          _isAuthenticated = isAuth;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAuthenticated = false;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return widget.config.loadingBuilder?.call(context) ??
          const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
    }

    // User is authenticated, redirect to home
    if (_isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.config.homeRoute != null) {
          Navigator.of(context).pushReplacementNamed(
            widget.config.homeRoute!,
          );
        }
      });
      return const SizedBox.shrink();
    }

    // User is not authenticated, show the page (login/register)
    return widget.child;
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:authyra/authyra.dart';

/// Router that automatically handles authentication-based navigation
///
/// # Example
/// ```dart
/// MaterialApp(
///   home: AuthyraRouter(
///     authenticatedBuilder: (context) => HomePage(),
///     unauthenticatedBuilder: (context) => LoginPage(),
///     loadingBuilder: (context) => SplashScreen(),
///   ),
/// )
/// ```
class AuthyraRouter extends StatefulWidget {
  /// Widget to show when user is authenticated
  final Widget Function(BuildContext context) authenticatedBuilder;

  /// Widget to show when user is not authenticated
  final Widget Function(BuildContext context) unauthenticatedBuilder;

  /// Widget to show while checking authentication
  final Widget Function(BuildContext context)? loadingBuilder;

  /// Custom authentication check
  final Future<bool> Function(AuthSession? session)? customCheck;

  const AuthyraRouter({
    super.key,
    required this.authenticatedBuilder,
    required this.unauthenticatedBuilder,
    this.loadingBuilder,
    this.customCheck,
  });

  @override
  State<AuthyraRouter> createState() => _AuthyraRouterState();
}

class _AuthyraRouterState extends State<AuthyraRouter> {
  StreamSubscription<AuthSession?>? _sessionSubscription;
  bool _isLoading = true;
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _checkInitialAuth();
    _listenToSessionChanges();
  }

  Future<void> _checkInitialAuth() async {
    try {
      final session = await Authyra.instance.getSession();
      await _updateAuthState(session);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAuthenticated = false;
          _isLoading = false;
        });
      }
    }
  }

  void _listenToSessionChanges() {
    _sessionSubscription = Authyra.instance.sessionStream.listen(
      (session) async {
        await _updateAuthState(session);
      },
    );
  }

  Future<void> _updateAuthState(AuthSession? session) async {
    bool isAuth = false;

    if (widget.customCheck != null) {
      isAuth = await widget.customCheck!(session);
    } else {
      isAuth = session != null && !session.isExpired;
    }

    if (mounted) {
      setState(() {
        _isAuthenticated = isAuth;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _sessionSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return widget.loadingBuilder?.call(context) ??
          const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
    }

    return _isAuthenticated ? widget.authenticatedBuilder(context) : widget.unauthenticatedBuilder(context);
  }
}

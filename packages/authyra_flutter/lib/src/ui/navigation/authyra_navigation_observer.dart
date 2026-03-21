import 'package:authyra/authyra.dart';
import 'package:flutter/material.dart';

/// Navigation observer that handles authentication-based redirects
///
/// # Example
/// ```dart
/// MaterialApp(
///   navigatorObservers: [
///     AuthyraNavigationObserver(
///       loginRoute: '/login',
///       protectedRoutes: ['/profile', '/settings', '/admin'],
///     ),
///   ],
/// )
/// ```
class AuthyraNavigationObserver extends NavigatorObserver {
  final String loginRoute;
  final List<String> protectedRoutes;
  final Future<bool> Function()? customAuthCheck;

  AuthyraNavigationObserver({
    required this.loginRoute,
    this.protectedRoutes = const [],
    this.customAuthCheck,
  });

  @override
  void didPush(Route route, Route? previousRoute) {
    super.didPush(route, previousRoute);
    _checkRouteAccess(route);
  }

  Future<void> _checkRouteAccess(Route route) async {
    final routeName = route.settings.name;
    if (routeName == null || !protectedRoutes.contains(routeName)) {
      return;
    }

    bool isAuthenticated;

    if (customAuthCheck != null) {
      isAuthenticated = await customAuthCheck!();
    } else {
      isAuthenticated = Authyra.instance.isAuthenticated;
    }

    if (!isAuthenticated && navigator != null) {
      navigator!.pushReplacementNamed(loginRoute);
    }
  }
}

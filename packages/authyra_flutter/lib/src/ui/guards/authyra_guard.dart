import 'package:authyra/authyra.dart';
import 'package:authyra_flutter/src/ui/guards/authyra_guard_config.dart';
import 'package:flutter/material.dart';

// For apps using Navigator, you can create a reusable guard widget:

// When to Use It
// ✅ Use AuthyraGuard when:

// You're using basic Navigator
// You want a simple, declarative API
// Your app has straightforward auth routing (login ↔ home)

// ❌ Don't use AuthyraGuard when:

// You're using GoRouter, AutoRoute, or any declarative router (use their redirect system)
// You need complex routing logic, deep links, or route-level guards
// You want fine-grained control over navigation transitions

// Why Authyra Stays Flexible
// Authyra doesn't ship with AuthyraGuard or force a specific routing pattern because:

// Router diversity: Flutter has GoRouter, AutoRoute, Beamer, VRouter, Routemaster, Navigator 2.0, etc.
// App-specific needs: Some apps need multi-step onboarding, role-based routing, or complex deep-link handling
// Framework philosophy: Authyra is auth logic, not UI or navigation

// By exposing primitives (isAuthenticated, onAccountChanged, toNotifier()), Authyra integrates cleanly with any routing solution.

class AuthyraGuard extends StatefulWidget {
  final AuthyraGuardConfig config;
  final Widget child;

  const AuthyraGuard({
    super.key,
    required this.config,
    required this.child,
  });

  @override
  State<AuthyraGuard> createState() => _AuthyraGuardState();
}

class _AuthyraGuardState extends State<AuthyraGuard> {
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

      // Custom check if provided
      if (widget.config.customCheck != null) {
        final customResult = await widget.config.customCheck!(session);
        if (mounted) {
          setState(() {
            _isAuthenticated = customResult;
            _isLoading = false;
          });
        }
        return;
      }

      // Default check: session exists and not expired
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
          _isAuthenticated = widget.config.allowOnError;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading while checking
    if (_isLoading) {
      return widget.config.loadingBuilder?.call(context) ??
          const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
    }

    // User is authenticated, show the protected content
    if (_isAuthenticated) {
      return widget.child;
    }

    // User is not authenticated
    // Show login widget or navigate to login route
    if (widget.config.loginBuilder != null) {
      return widget.config.loginBuilder!(context);
    }

    // Navigate to login route
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.config.loginRoute != null) {
        Navigator.of(context).pushReplacementNamed(
          widget.config.loginRoute!,
        );
      }
    });

    return const SizedBox.shrink();
  }
}

// class AuthyraGuard extends StatelessWidget {
//   final Widget Function(BuildContext, AuthAccount) authenticatedBuilder;
//   final Widget Function(BuildContext) unauthenticatedBuilder;
//   final Widget Function(BuildContext)? loadingBuilder;

//   const AuthyraGuard({
//     required this.authenticatedBuilder,
//     required this.unauthenticatedBuilder,
//     this.loadingBuilder,
//     super.key,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return StreamBuilder<AuthAccount?>(
//       stream: Authyra.instance.onAccountChanged,
//       initialData: Authyra.instance.currentAccount,
//       builder: (context, snapshot) {
//         if (snapshot.connectionState == ConnectionState.waiting) {
//           return loadingBuilder?.call(context) ?? const SizedBox.shrink();
//         }

//         final account = snapshot.data;
//         if (account == null) {
//           return unauthenticatedBuilder(context);
//         }

//         return authenticatedBuilder(context, account);
//       },
//     );
//   }
// }
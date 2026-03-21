import 'package:authyra_flutter/src/ui/widgets/auth_state_builder.dart';
import 'package:flutter/widgets.dart';

/// Widget that requires specific role from user metadata
///
/// # Example
/// ```dart
/// RequireRole(
///   role: 'admin',
///   fallback: Text('Admin only'),
///   child: AdminPanel(),
/// )
/// ```
class RequireRole extends StatelessWidget {
  final String role;
  final Widget child;
  final Widget fallback;

  const RequireRole({
    super.key,
    required this.role,
    required this.child,
    this.fallback = const SizedBox.shrink(),
  });

  @override
  Widget build(BuildContext context) {
    return AuthStateBuilder(
      builder: (context, session) {
        if (session == null) return fallback;

        final userRole = session.user.metadata['role'] as String?;
        if (userRole != role) return fallback;

        return child;
      },
    );
  }
}

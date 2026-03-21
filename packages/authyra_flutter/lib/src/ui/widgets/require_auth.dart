import 'package:authyra_flutter/src/ui/widgets/auth_state_builder.dart';
import 'package:flutter/widgets.dart';

/// Simple widget that only shows children when authenticated
///
/// # Example
/// ```dart
/// RequireAuth(
///   fallback: Text('Login required'),
///   child: ElevatedButton(
///     onPressed: () => print('Protected action'),
///     child: Text('Delete Account'),
///   ),
/// )
/// ```
class RequireAuth extends StatelessWidget {
  final Widget child;
  final Widget fallback;

  const RequireAuth({
    super.key,
    required this.child,
    this.fallback = const SizedBox.shrink(),
  });

  @override
  Widget build(BuildContext context) {
    return AuthStateBuilder(
      builder: (context, session) {
        if (session == null || session.isExpired) {
          return fallback;
        }
        return child;
      },
    );
  }
}

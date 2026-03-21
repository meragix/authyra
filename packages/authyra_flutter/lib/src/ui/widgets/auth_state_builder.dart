import 'package:authyra/authyra.dart';
import 'package:flutter/widgets.dart';

/// Builder widget that rebuilds based on authentication state
///
/// # Example
/// ```dart
/// AuthStateBuilder(
///   builder: (context, session) {
///     if (session == null) {
///       return Text('Please log in');
///     }
///     return Text('Hello ${session.user.name}');
///   },
/// )
/// ```
class AuthStateBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, AuthSession? session) builder;

  const AuthStateBuilder({
    super.key,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthSession?>(
      stream: Authyra.instance.sessionStream,
      builder: (context, snapshot) {
        return builder(context, snapshot.data);
      },
    );
  }
}

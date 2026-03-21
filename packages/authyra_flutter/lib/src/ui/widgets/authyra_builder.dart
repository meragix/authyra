import 'package:authyra/authyra.dart';
import 'package:authyra_flutter/src/extensions/context_extensions.dart';
import 'package:flutter/widgets.dart';

/// Widget builder that provides authentication state
typedef AuthBuilder = Widget Function(
  BuildContext context,
  AuthSession? session,
  bool isLoading,
);

/// Widget that rebuilds when authentication state changes
///
/// Example:
/// ```dart
/// AuthyraBuilder(
///   builder: (context, session, isLoading) {
///     if (isLoading) return CircularProgressIndicator();
///     if (user == null) return LoginPage();
///     return HomePage(user: session.user);
///   },
/// )
/// ```
class AuthyraBuilder extends StatefulWidget {
  final AuthBuilder builder;

  const AuthyraBuilder({super.key, required this.builder});

  @override
  State<AuthyraBuilder> createState() => _AuthyraBuilderState();
}

class _AuthyraBuilderState extends State<AuthyraBuilder> {
  AuthSession? _session;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAccount();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadAccount();
  }

  Future<void> _loadAccount() async {
    setState(() => _isLoading = true);
    try {
      final session = await context.activeSession;
      if (mounted) {
        setState(() {
          _session = session;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _session = null;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _session, _isLoading);
  }
}

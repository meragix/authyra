import 'package:authyra/authyra.dart';
import 'package:flutter/widgets.dart';

/// InheritedWidget that propagates Authyra state throughout the widget tree
/// 
/// Wrap your app with this widget to enable [BuildContext] extensions
/// and automatic rebuilding when authentication state changes.
/// 
/// Example:
/// ```dart
/// MaterialApp(
///   home: AuthyraScope(
///     child: MyHomePage(),
///   ),
/// )
/// ```
class AuthyraScope extends StatefulWidget {
  final Widget child;
  final Authyra? authyra;

  const AuthyraScope({super.key, required this.child, this.authyra});

  @override
  State<AuthyraScope> createState() => _AuthyraScopeState();

  static Authyra of(BuildContext context) {
    final inherited = context.dependOnInheritedWidgetOfExactType<_InheritedAuthyra>();
    if (inherited == null) {
      throw StateError(
        'No AuthyraScope found in context. '
        'Ensure your widget tree is wrapped with AuthyraScope.',
      );
    }
    return inherited.authyra;
  }

  static Authyra? maybeOf(BuildContext context) {
    final inherited = context.dependOnInheritedWidgetOfExactType<_InheritedAuthyra>();
    return inherited?.authyra;
  }
}

class _AuthyraScopeState extends State<AuthyraScope> {
  late Authyra _authyra;

  @override
  void initState() {
    super.initState();
    _authyra = widget.authyra ?? Authyra.instance;
    // _authyra.addListener(_onAuthChanged);
  }

  @override
  void didUpdateWidget(AuthyraScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.authyra != oldWidget.authyra) {
      //_authyra.removeListener(_onAuthChanged);
      _authyra = widget.authyra ?? Authyra.instance;
      // _authyra.addListener(_onAuthChanged);
    }
  }

  @override
  void dispose() {
    //_authyra.removeListener(_onAuthChanged);
    super.dispose();
  }

  // void _onAuthChanged() {
  //   setState(() {});
  // }

  @override
  Widget build(BuildContext context) {
    return _InheritedAuthyra(
      authyra: _authyra,
      child: widget.child,
    );
  }
}

class _InheritedAuthyra extends InheritedWidget {
  final Authyra authyra;

  const _InheritedAuthyra({
    required this.authyra,
    required super.child,
  });

  @override
  bool updateShouldNotify(_InheritedAuthyra oldWidget) {
    return authyra != oldWidget.authyra;
  }
}

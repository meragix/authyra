import 'package:authyra_flutter/authyra_flutter.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../core/demo/demo_rate_limit_callbacks.dart';
import '../../core/widgets/theme_toggle.dart';
import 'auth_cubit.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController(text: 'demo');
  bool _loading = false;
  String? _error;

  Future<void> _submit(Future<void> Function() action) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await action();
    } on AuthenticationFailedException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Something went wrong: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final callbacks = context.watch<AuthCubit>().callbacks;

    return ColoredBox(
      color: theme.colorScheme.background,
      child: Stack(
        children: [
          Positioned(top: 16, right: 16, child: SafeArea(child: ThemeToggle())),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Authyra Demo', style: theme.textTheme.h2),
                    const SizedBox(height: 4),
                    Text(
                      'A real Flutter app instrumented with Authyra. Try it, then '
                      'inspect exactly what it did.',
                      style: theme.textTheme.muted,
                    ),
                    const SizedBox(height: 24),
                    ShadButton(
                      onPressed: _loading
                          ? null
                          : () => _submit(
                              () => context
                                  .read<AuthCubit>()
                                  .signInWithDemoAccount(),
                            ),
                      child: const Text('Continue with demo account'),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ShadSeparator.horizontal(
                            color: theme.colorScheme.border,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text('or', style: theme.textTheme.muted),
                        ),
                        Expanded(
                          child: ShadSeparator.horizontal(
                            color: theme.colorScheme.border,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ShadInput(
                      controller: _email,
                      placeholder: const Text('Email (anything works)'),
                    ),
                    const SizedBox(height: 8),
                    ShadInput(
                      controller: _password,
                      obscureText: true,
                      placeholder: const Text('Password'),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Password is "demo". Try a wrong one a few times to see the '
                      'rate-limit callback kick in.',
                      style: theme.textTheme.muted,
                    ),
                    const SizedBox(height: 12),
                    ShadButton.outline(
                      onPressed: _loading
                          ? null
                          : () => _submit(
                              () => context.read<AuthCubit>().signIn(
                                email: _email.text.trim().isEmpty
                                    ? 'you@example.com'
                                    : _email.text.trim(),
                                password: _password.text,
                              ),
                            ),
                      child: const Text('Sign in'),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      ShadAlert.destructive(
                        title: const Text('Sign-in failed'),
                        description: Text(_error!),
                      ),
                    ],
                    const SizedBox(height: 12),
                    _RateLimitStatus(callbacks: callbacks),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RateLimitStatus extends StatelessWidget {
  final DemoRateLimitCallbacks callbacks;
  const _RateLimitStatus({required this.callbacks});

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Text(
      'Failed attempts: ${callbacks.failedAttempts}/${callbacks.maxAttempts}'
      '${callbacks.isBlocked ? ' (blocked)' : ''}',
      style: theme.textTheme.small.copyWith(
        color: theme.colorScheme.mutedForeground,
      ),
    );
  }
}

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../core/widgets/section_card.dart';
import '../auth/auth_cubit.dart';

/// Demonstrates the one distinction that trips people up most: plugins
/// observe, callbacks can block. Both react to the same sign-in attempts,
/// only one of them can stop one.
class PlaygroundPage extends StatefulWidget {
  const PlaygroundPage({super.key});

  @override
  State<PlaygroundPage> createState() => _PlaygroundPageState();
}

class _PlaygroundPageState extends State<PlaygroundPage> {
  String? _lastResult;

  Future<void> _attemptWrongPassword(BuildContext context) async {
    try {
      await context.read<AuthCubit>().signIn(email: 'playground@authyra.dev', password: 'wrong');
      setState(() => _lastResult = 'Unexpectedly succeeded.');
    } catch (e) {
      setState(() => _lastResult = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final callbacks = context.watch<AuthCubit>().callbacks;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Playground', style: theme.textTheme.h2),
        const SizedBox(height: 4),
        Text(
          'AuthyraPlugin and AuthCallbacks both react to a sign-in attempt. '
          'Only one of them can stop it.',
          style: theme.textTheme.muted,
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'AuthCallbacks: can block',
          description: 'DemoRateLimitCallbacks denies sign-in after '
              '${callbacks.maxAttempts} failed attempts, right here in this app.',
          footer: ShadButton(
            onPressed: () => _attemptWrongPassword(context),
            child: const Text('Try a wrong password'),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Failed attempts: ${callbacks.failedAttempts}/${callbacks.maxAttempts}'
                '${callbacks.isBlocked ? ', further attempts are denied' : ''}',
                style: theme.textTheme.small,
              ),
              if (_lastResult != null) ...[
                const SizedBox(height: 8),
                Text(_lastResult!, style: theme.textTheme.small.copyWith(fontFamily: 'monospace')),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'AuthyraPlugin: observes only',
          description: 'DemoAuditPlugin logs onBeforeSignIn/onAfterSignIn/onSessionExpired to '
              'the Events tab. Even if it threw, AuthyraClient would catch and log that '
              'exception internally; the sign-in would proceed unaffected.',
          child: const Text('Check the Events tab, every attempt above is logged with the '
              '"plugin" badge alongside the "callback" denial.'),
        ),
      ],
    );
  }
}

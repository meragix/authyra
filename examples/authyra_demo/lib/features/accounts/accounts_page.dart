import 'package:authyra_flutter/authyra_flutter.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../core/widgets/section_card.dart';
import 'accounts_cubit.dart';

class AccountsPage extends StatelessWidget {
  const AccountsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    return BlocBuilder<AccountsCubit, AccountsState>(
      builder: (context, state) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Accounts', style: theme.textTheme.h2),
            const SizedBox(height: 4),
            Text(
              '${state.sessions.length} account(s) signed in on this device, '
              'switchable without re-authenticating. Not the same thing as '
              'linking two providers to one identity, see the note below.',
              style: theme.textTheme.muted,
            ),
            const SizedBox(height: 16),
            for (final session in state.sessions)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _AccountTile(
                  session: session,
                  isActive: session.user.id == state.activeUserId,
                ),
              ),
            ShadButton.outline(
              onPressed: () => context.read<AccountsCubit>().addDemoAccount(),
              child: const Text('+ Add another demo account'),
            ),
            const SizedBox(height: 24),
            ShadAlert(
              title: const Text('Multi-account, not account-linking'),
              description: const Text(
                'Each "Add account" here is a wholly separate signed-in '
                'identity (its own AuthUser.id), stored side by side in '
                'SessionRegistry. Authyra does not merge them into one '
                'account: linkedAccounts exists in the model, but no '
                'built-in provider populates it today.',
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AccountTile extends StatelessWidget {
  final AuthSession session;
  final bool isActive;

  const _AccountTile({required this.session, required this.isActive});

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return SectionCard(
      title: session.user.name ?? session.user.email ?? session.user.id,
      description: '${session.providerId} · ${session.isExpired ? 'expired' : 'active'}',
      footer: Wrap(
        spacing: 8,
        children: [
          if (!isActive)
            ShadButton(
              onPressed: () => context.read<AccountsCubit>().switchTo(session.user.id),
              child: const Text('Switch to this account'),
            )
          else
            ShadBadge(backgroundColor: theme.colorScheme.primary, child: const Text('Active')),
          ShadButton.outline(
            onPressed: () => context.read<AccountsCubit>().signOut(session.user.id),
            child: const Text('Sign out'),
          ),
        ],
      ),
      child: const SizedBox.shrink(),
    );
  }
}

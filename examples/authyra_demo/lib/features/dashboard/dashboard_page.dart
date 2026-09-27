import 'dart:async';

import 'package:authyra_flutter/authyra_flutter.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_json/flutter_json.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../core/widgets/section_card.dart';
import '../auth/auth_cubit.dart';
import 'session_cubit.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    return BlocBuilder<SessionCubit, SessionState>(
      builder: (context, state) {
        final session = state.session;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Dashboard', style: theme.textTheme.h2),
            const SizedBox(height: 4),
            Text(
              'This is the live state Authyra is holding for the active account.',
              style: theme.textTheme.muted,
            ),
            const SizedBox(height: 16),
            if (session == null)
              const SectionCard(title: 'No active session', child: SizedBox.shrink())
            else ...[
              SectionCard(
                title: session.user.name ?? session.user.email ?? session.user.id,
                description: 'Provider: ${session.providerId}',
                footer: Wrap(
                  spacing: 8,
                  children: [
                    ShadButton(
                      onPressed: state.refreshing
                          ? null
                          : () => context.read<SessionCubit>().forceRefresh(),
                      child: Text(state.refreshing ? 'Refreshing...' : 'Force refresh now'),
                    ),
                    ShadButton.outline(
                      onPressed: () => context.read<AuthCubit>().signOut(),
                      child: const Text('Sign out'),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Row(
                      label: 'Status',
                      value: session.isExpired ? 'Expired' : 'Active',
                      badgeColor: session.isExpired
                          ? theme.colorScheme.destructive
                          : theme.colorScheme.primary,
                    ),
                    _ExpiryRow(session: session),
                    _Row(label: 'Can refresh', value: session.canRefresh ? 'yes' : 'no'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SectionCard(
                title: 'Raw AuthSession',
                description:
                    'Exactly what session.toJson() returns, this is what SessionManager persists.',
                child: SizedBox(
                  height: 320,
                  child: JsonWidget(
                    json: session.toJson(),
                    initialExpandDepth: 2,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Owns its own ticker so the countdown updates every second without
/// rebuilding the rest of the dashboard (and without keeping a frame
/// perpetually scheduled at the page level).
class _ExpiryRow extends StatefulWidget {
  final AuthSession session;
  const _ExpiryRow({required this.session});

  @override
  State<_ExpiryRow> createState() => _ExpiryRowState();
}

class _ExpiryRowState extends State<_ExpiryRow> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    return _Row(
      label: 'Expires in',
      value: session.isExpired ? 'expired' : '${session.timeUntilExpiration.inSeconds}s',
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final Color? badgeColor;

  const _Row({required this.label, required this.value, this.badgeColor});

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 110, child: Text(label, style: theme.textTheme.muted)),
          if (badgeColor != null)
            ShadBadge(
              backgroundColor: badgeColor,
              child: Text(value),
            )
          else
            Text(value, style: theme.textTheme.p),
        ],
      ),
    );
  }
}

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../core/demo/event_log_cubit.dart';

class EventsPage extends StatelessWidget {
  const EventsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    return BlocBuilder<EventLogCubit, List<EventLogEntry>>(
      builder: (context, entries) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Events', style: theme.textTheme.h2),
                        Text(
                          'Live feed from AuthEventBus, plus what the demo plugin and '
                          'callback observed. Newest first.',
                          style: theme.textTheme.muted,
                        ),
                      ],
                    ),
                  ),
                  ShadButton.outline(
                    onPressed: () => context.read<EventLogCubit>().clear(),
                    child: const Text('Clear'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: entries.isEmpty
                  ? Center(child: Text('Nothing yet, sign in or switch accounts.', style: theme.textTheme.muted))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: entries.length,
                      itemBuilder: (context, index) => _EventRow(entry: entries[index]),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _EventRow extends StatelessWidget {
  final EventLogEntry entry;
  const _EventRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final time = entry.timestamp;
    final stamp =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:'
        '${time.second.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(stamp, style: theme.textTheme.small.copyWith(fontFamily: 'monospace')),
          const SizedBox(width: 8),
          _SourceBadge(source: entry.source),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              entry.message,
              style: theme.textTheme.small.copyWith(fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceBadge extends StatelessWidget {
  final EventLogSource source;
  const _SourceBadge({required this.source});

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final (label, color) = switch (source) {
      EventLogSource.authEvent => ('event', theme.colorScheme.primary),
      EventLogSource.plugin => ('plugin', theme.colorScheme.secondary),
      EventLogSource.callback => ('callback', theme.colorScheme.destructive),
    };
    return ShadBadge(backgroundColor: color, child: Text(label));
  }
}

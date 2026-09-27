import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum EventLogSource { authEvent, plugin, callback }

class EventLogEntry extends Equatable {
  final DateTime timestamp;
  final EventLogSource source;
  final String message;

  const EventLogEntry({
    required this.timestamp,
    required this.source,
    required this.message,
  });

  @override
  List<Object?> get props => [timestamp, source, message];
}

/// Live console fed by `AuthEventBus` (real events), the demo plugin
/// (observation only), and the demo callback (denials). Capped so a long
/// session doesn't grow the list forever.
class EventLogCubit extends Cubit<List<EventLogEntry>> {
  static const _maxEntries = 200;

  EventLogCubit() : super(const []);

  void add(EventLogSource source, String message) {
    final entry = EventLogEntry(timestamp: DateTime.now(), source: source, message: message);
    final next = [entry, ...state];
    emit(next.length > _maxEntries ? next.sublist(0, _maxEntries) : next);
  }

  void clear() => emit(const []);
}

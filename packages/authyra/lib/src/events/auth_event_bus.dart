import 'dart:async';

import 'package:authyra/src/events/auth_events.dart';
import 'package:authyra/src/internal/logger.dart';

/// Event listener callback
typedef EventListener<T extends AuthEvent> = void Function(T event);

/// Global event bus for Authyra
class AuthEventBus with AuthyraLogging {
  static final AuthEventBus _instance = AuthEventBus._();
  static AuthEventBus get instance => _instance;

  AuthEventBus._();

  final Map<Type, List<EventListener>> _listeners = {};
  final _controller = StreamController<AuthEvent>.broadcast();

  /// Stream of all events
  Stream<AuthEvent> get stream => _controller.stream;

  /// Listen to a specific event type
  void on<T extends AuthEvent>(EventListener<T> listener) {
    final listeners = _listeners[T] ?? [];
    listeners.add(listener as EventListener);
    _listeners[T] = listeners;
    logDebug('Event listener registered for ${T.toString()}');
  }

  /// Remove a specific listener
  void off<T extends AuthEvent>(EventListener<T> listener) {
    final listeners = _listeners[T];
    if (listeners != null) {
      listeners.remove(listener);
      if (listeners.isEmpty) {
        _listeners.remove(T);
      }
      logDebug('Event listener removed for ${T.toString()}');
    }
  }

  /// Emit an event
  void emit(AuthEvent event) {
    logDebug('Event emitted: ${event.runtimeType}', event.toJson());

    // Add to stream
    if (!_controller.isClosed) {
      _controller.add(event);
    }

    // Call type-specific listeners
    final listeners = _listeners[event.runtimeType];
    if (listeners != null) {
      for (final listener in listeners) {
        try {
          listener(event);
        } catch (e, stackTrace) {
          logError('Error in event listener', e, stackTrace);
        }
      }
    }
  }

  /// Clear all listeners
  void clearAll() {
    _listeners.clear();
    logDebug('All event listeners cleared');
  }

  /// Close the event bus
  void dispose() {
    _controller.close();
    _listeners.clear();
    logDebug('Event bus disposed');
  }
}

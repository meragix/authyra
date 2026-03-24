import 'dart:async';

import 'package:authyra/src/events/auth_events.dart';
import 'package:authyra/src/internal/logger.dart';

/// Callback type for typed event listeners.
typedef EventListener<T extends AuthEvent> = void Function(T event);

/// Scoped event bus for a single [AuthyraClient] instance.
///
/// [AuthEventBus] is **not a singleton**; each [AuthyraClient] owns its own
/// instance, which is injected into the session layer. This guarantees full
/// isolation between multiple clients in the same process (multi-tenant apps,
/// test suites, etc.).
///
/// ## Usage
///
/// ```dart
/// // Subscribe to a specific event type
/// client.events.on<SignInEvent>((event) {
///   print('Signed in: ${event.user.email}');
/// });
///
/// // Subscribe to all events via the raw stream
/// client.events.stream.listen((event) {
///   myAuditLogger.log(event.toJson());
/// });
///
/// // Unsubscribe
/// client.events.off<SignInEvent>(myListener);
/// ```
///
/// See also:
/// - [AuthEvent] and its subclasses for the full event catalogue.
/// - [AuthyraClient.events], the public accessor to this bus.
class AuthEventBus with AuthyraLogging {
  AuthEventBus();

  // Stored as Function to avoid contravariance cast issues:
  // void Function(SignInEvent) is not a subtype of void Function(AuthEvent).
  final Map<Type, List<Function>> _listeners = {};
  final _controller = StreamController<AuthEvent>.broadcast();

  /// Broadcast stream of all events emitted by the owning client.
  Stream<AuthEvent> get stream => _controller.stream;

  /// Subscribes [listener] to events of type [T].
  ///
  /// The listener is called synchronously during [emit]. Any exception thrown
  /// inside a listener is caught and logged; it will not propagate to the
  /// emitter.
  ///
  /// ```dart
  /// client.events.on<TokenRefreshEvent>((e) {
  ///   if (!e.success) refreshMyUi();
  /// });
  /// ```
  void on<T extends AuthEvent>(EventListener<T> listener) {
    final listeners = _listeners[T] ?? [];
    listeners.add(listener);
    _listeners[T] = listeners;
    logDebug('Event listener registered for ${T.toString()}');
  }

  /// Unsubscribes [listener] from events of type [T].
  ///
  /// A no-op if [listener] was never registered.
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

  /// Emits [event] to the [stream] and all matching type listeners.
  ///
  /// Called internally by [AuthyraClient] after each auth action.
  void emit(AuthEvent event) {
    logDebug('Event emitted: ${event.runtimeType}', event.toJson());

    if (!_controller.isClosed) {
      _controller.add(event);
    }

    final listeners = _listeners[event.runtimeType];
    if (listeners != null) {
      for (final listener in List.of(listeners)) {
        try {
          (listener as dynamic)(event);
        } catch (e, stackTrace) {
          logError('Error in event listener for ${event.runtimeType}', e, stackTrace);
        }
      }
    }
  }

  /// Removes all registered listeners.
  void clearAll() {
    _listeners.clear();
    logDebug('All event listeners cleared');
  }

  /// Closes the stream and releases all resources.
  ///
  /// Called by [AuthyraClient.dispose]. The bus must not be used after disposal.
  void dispose() {
    _controller.close();
    _listeners.clear();
    logDebug('Event bus disposed');
  }
}

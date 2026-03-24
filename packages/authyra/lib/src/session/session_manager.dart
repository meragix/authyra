import 'dart:async';
import 'dart:convert';

import 'package:authyra/src/exceptions/auth_exceptions.dart';
import 'package:authyra/src/internal/logger.dart';
import 'package:authyra/src/models/auth_session.dart';
import 'package:authyra/src/models/auth_user.dart';
import 'package:authyra/src/session/session_registry.dart';
import 'package:authyra/src/interfaces/auth_storage.dart';

/// Callback invoked whenever the active [AuthSession] changes.
///
/// Receives `null` when all accounts are signed out or the last session is
/// removed. Used by [AccountManager] and `AuthyraInstance` to propagate
/// reactive state changes.
typedef SessionChangeCallback = void Function(AuthSession? session);

/// Stateful manager for multi-account session persistence and lifecycle.
///
/// [SessionManager] is the **single source of truth** for all authenticated
/// sessions. It orchestrates three layers:
///
/// 1. **In-memory registry**: fast synchronous access via [activeSession],
///    [allUsers], etc.
/// 2. **Persistent storage**: serialises the full [SessionRegistry] to
///    [AuthStorage] on every mutation.
/// 3. **Reactive notifications**: broadcasts session changes via
///    [sessionStream] and registered [SessionChangeCallback]s.
///
/// ## Concurrency
///
/// All mutating operations (save, remove, update, switch, clean) are
/// serialised through an [_AsyncMutex]. This prevents corrupt state from
/// concurrent writes in multi-isolate or rapid-tap scenarios.
///
/// ## Lifecycle
///
/// ```dart
/// final manager = SessionManager(storage: myStorage);
/// await manager.initialize(); // Restores persisted sessions
///
/// await manager.saveSession(session);
/// await manager.switchAccount(otherUserId);
/// await manager.clearAllSessions();
///
/// await manager.dispose(); // Release streams and callbacks
/// ```
///
/// See also:
/// - [SessionRegistry], the immutable value object managed by this class.
/// - [AccountManager], the higher-level API exposed to consumers.
/// - [AuthStorage], the pluggable persistence backend.
class SessionManager with AuthyraLogging {
  /// The persistence backend used to read/write the serialised registry.
  final AuthStorage storage;

  /// Whether expiry-based auto-refresh hints should be surfaced.
  ///
  /// When `true`, [getActiveSession] logs a warning and signals via the
  /// stream that the active token is expired, allowing callers to trigger a
  /// refresh. Actual token renewal is delegated to the provider layer.
  final bool autoRefresh;

  /// Storage key under which the serialised [SessionRegistry] is persisted.
  static const String _registryKey = 'authyra_session_registry';

  /// Broadcast stream controller for active session changes.
  final _sessionController = StreamController<AuthSession?>.broadcast();

  /// Current in-memory registry (always consistent with storage after init).
  SessionRegistry _registry = const SessionRegistry();

  /// Serialises all mutating operations to prevent concurrent state corruption.
  final _mutex = _AsyncMutex();

  /// Registered change listeners (callback-based, complementary to the stream).
  final _listeners = <SessionChangeCallback>[];

  /// Creates a [SessionManager].
  ///
  /// Call [initialize] before invoking any other method.
  SessionManager({
    required this.storage,
    this.autoRefresh = true,
  });

  // ---------------------------------------------------------------------------
  // Public accessors (synchronous, in-memory)
  // ---------------------------------------------------------------------------

  /// Broadcast stream emitting the active [AuthSession] on every change.
  ///
  /// Emits `null` when no account is active (e.g., after sign-out).
  /// Subscribe in `AuthyraInstance` or reactive state containers.
  Stream<AuthSession?> get sessionStream => _sessionController.stream;

  /// The currently active session, or `null` if no account is signed in.
  AuthSession? get activeSession => _registry.activeSession;

  /// The currently active user, or `null`.
  AuthUser? get activeUser => _registry.activeSession?.user;

  /// All registered users, sorted by most recently used.
  List<AuthUser> get allUsers => _registry.allUsers;

  /// Total number of registered accounts (including expired ones).
  int get accountCount => _registry.accountCount;

  /// Whether there is an active, non-expired session.
  bool get hasActiveSession => _registry.hasActiveSession;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  /// Initialises the manager by loading persisted sessions from [storage].
  ///
  /// - Calls [AuthStorage.initialize] on the underlying backend.
  /// - Deserialises the stored [SessionRegistry].
  /// - Automatically prunes expired sessions found at startup.
  /// - Emits the restored active session (or `null`) to all listeners.
  ///
  /// Must be called and awaited once before any other method.
  ///
  /// Throws [StorageException] if the storage backend cannot be initialised.
  Future<void> initialize() async {
    try {
      logInfo('Initializing SessionManager');

      await storage.initialize();
      await _loadRegistry();

      // Prune stale sessions from a previous app run.
      if (_registry.hasAnySession) {
        final cleaned = _registry.removeExpiredSessions();
        final removedCount = _registry.accountCount - cleaned.accountCount;
        if (removedCount > 0) {
          logInfo('Pruned $removedCount expired session(s) at startup');
          await _saveRegistry(cleaned);
        }
      }

      logInfo(
        'SessionManager ready — ${_registry.accountCount} account(s) loaded',
      );
      _notifyListeners(_registry.activeSession);
    } catch (e, stackTrace) {
      logError('Failed to initialize SessionManager', e, stackTrace);
      throw StorageException('initialize', e);
    }
  }

  /// Releases the session stream and clears all registered listeners.
  ///
  /// Call this when the owning object is being disposed (e.g., in
  /// `AuthyraInstance.dispose`). The manager must not be used after disposal.
  Future<void> dispose() async {
    await _sessionController.close();
    _listeners.clear();
    logDebug('SessionManager disposed');
  }

  // ---------------------------------------------------------------------------
  // Listener management
  // ---------------------------------------------------------------------------

  /// Registers [callback] to be invoked on every active session change.
  ///
  /// Prefer [sessionStream] for reactive frameworks; use callbacks for
  /// lightweight, non-reactive integrations (e.g., Dart CLI, backend).
  void addListener(SessionChangeCallback callback) {
    _listeners.add(callback);
  }

  /// Removes a previously registered [callback].
  ///
  /// A no-op if [callback] was never registered.
  void removeListener(SessionChangeCallback callback) {
    _listeners.remove(callback);
  }

  // ---------------------------------------------------------------------------
  // Session CRUD
  // ---------------------------------------------------------------------------

  /// Persists [session] and optionally makes it the active account.
  ///
  /// If a session already exists for [session.user.id] it is replaced.
  /// When [setAsActive] is `true` (default), the stream and listeners are
  /// notified immediately.
  ///
  /// Throws [StorageException] if the write fails.
  Future<void> saveSession(
    AuthSession session, {
    bool setAsActive = true,
  }) async {
    return _mutex.synchronized(() async {
      try {
        logDebug('Saving session for user: ${session.user.id}');

        final newRegistry =
            _registry.addSession(session, setAsActive: setAsActive);
        await _saveRegistry(newRegistry);

        if (setAsActive) {
          _notifyListeners(newRegistry.activeSession);
        }

        logInfo('Session saved for user: ${session.user.id}');
      } catch (e, stackTrace) {
        logError('Failed to save session', e, stackTrace);
        throw StorageException('save session', e);
      }
    });
  }

  /// Returns the active session, or `null` if no account is signed in.
  ///
  /// Throws [TokenExpiredException] when the active session exists but its
  /// access token has already expired. Callers with [autoRefresh] enabled
  /// should catch this and trigger a token refresh via their provider.
  ///
  /// Throws [StorageException] for unexpected internal errors.
  Future<AuthSession?> getActiveSession() async {
    try {
      final session = _registry.activeSession;

      if (session != null && session.isExpired) {
        logWarning('Active session expired for user: ${session.user.id}');
        throw TokenExpiredException(
          'Session for user ${session.user.id} has expired. '
          'Trigger a refresh via your provider.',
        );
      }

      return session;
    } on AuthException {
      rethrow;
    } catch (e, stackTrace) {
      logError('Failed to get active session', e, stackTrace);
      throw StorageException('get active session', e);
    }
  }

  /// Returns the session for [userId], or `null` if not found.
  Future<AuthSession?> getSession(String userId) async {
    return _registry.sessions[userId];
  }

  /// Returns all sessions, sorted by most recently used.
  Future<List<AuthSession>> getAllSessions() async {
    return _registry.allSessions;
  }

  /// Replaces the session for [userId] with [session].
  ///
  /// Typically called after a token refresh to apply new credentials without
  /// changing the active account. Notifies listeners when [userId] is the
  /// current active account.
  ///
  /// Returns without effect if [userId] is not registered.
  ///
  /// Throws [SessionOperationException] on failure.
  Future<void> updateSession(String userId, AuthSession session) async {
    return _mutex.synchronized(() async {
      try {
        logDebug('Updating session for user: $userId');

        final newRegistry = _registry.updateSession(userId, session);
        await _saveRegistry(newRegistry);

        if (_registry.activeUserId == userId) {
          _notifyListeners(newRegistry.activeSession);
        }

        logDebug('Session updated for user: $userId');
      } catch (e, stackTrace) {
        logError('Failed to update session', e, stackTrace);
        throw SessionOperationException('update session', e);
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Account management
  // ---------------------------------------------------------------------------

  /// Switches the active account to [userId].
  ///
  /// Marks the target session as used (updating its `lastUsedAt`) and
  /// persists the change. Notifies all listeners.
  ///
  /// Throws [AccountNotFoundException] if [userId] has no registered session.
  /// Throws [TokenExpiredException] if the target session is expired.
  /// Throws [SessionOperationException] for other failures.
  Future<void> switchAccount(String userId) async {
    return _mutex.synchronized(() async {
      try {
        logInfo('Switching to account: $userId');

        if (!_registry.hasUser(userId)) {
          throw AccountNotFoundException(userId);
        }

        final session = _registry.sessions[userId]!;
        if (session.isExpired) {
          throw TokenExpiredException(
            'Cannot switch to account $userId — session has expired',
          );
        }

        final newRegistry = _registry.switchTo(userId);
        await _saveRegistry(newRegistry);
        _notifyListeners(newRegistry.activeSession);

        logInfo('Switched to account: $userId');
      } on AuthException {
        rethrow;
      } catch (e, stackTrace) {
        logError('Failed to switch account', e, stackTrace);
        throw SessionOperationException('switch account', e);
      }
    });
  }

  /// Removes the session for [userId] from the registry.
  ///
  /// If [userId] was the active account, the most recently used remaining
  /// account (if any) is automatically elected as the new active account.
  /// Listeners are notified only when the active account changes.
  ///
  /// Returns without effect if [userId] is not registered.
  ///
  /// Throws [SessionOperationException] on failure.
  Future<void> removeSession(String userId) async {
    return _mutex.synchronized(() async {
      try {
        logInfo('Removing session for user: $userId');

        if (!_registry.hasUser(userId)) {
          logWarning('Session not found for user: $userId — skipping removal');
          return;
        }

        final wasActive = _registry.activeUserId == userId;
        final newRegistry = _registry.removeSession(userId);
        await _saveRegistry(newRegistry);

        if (wasActive) {
          _notifyListeners(newRegistry.activeSession);
        }

        logInfo('Session removed for user: $userId');
      } catch (e, stackTrace) {
        logError('Failed to remove session', e, stackTrace);
        throw SessionOperationException('remove session', e);
      }
    });
  }

  /// Signs out the currently active account.
  ///
  /// A convenience wrapper around [removeSession] for the active user.
  /// Returns without effect if there is no active session.
  ///
  /// Throws [SessionOperationException] on failure.
  Future<void> clearActiveSession() async {
    return _mutex.synchronized(() async {
      try {
        final activeUserId = _registry.activeUserId;
        if (activeUserId == null) {
          logDebug('No active session to clear');
          return;
        }

        logInfo('Clearing active session for user: $activeUserId');

        final newRegistry = _registry.removeSession(activeUserId);
        await _saveRegistry(newRegistry);
        _notifyListeners(newRegistry.activeSession);

        logInfo('Active session cleared');
      } catch (e, stackTrace) {
        logError('Failed to clear active session', e, stackTrace);
        throw SessionOperationException('clear active session', e);
      }
    });
  }

  /// Signs out all accounts and clears the registry.
  ///
  /// Emits `null` to all listeners after clearing.
  ///
  /// Throws [SessionOperationException] on failure.
  Future<void> clearAllSessions() async {
    return _mutex.synchronized(() async {
      try {
        logInfo('Clearing all sessions');

        final newRegistry = _registry.clearAll();
        await _saveRegistry(newRegistry);
        _notifyListeners(null);

        logInfo('All sessions cleared');
      } catch (e, stackTrace) {
        logError('Failed to clear all sessions', e, stackTrace);
        throw SessionOperationException('clear all sessions', e);
      }
    });
  }

  /// Removes all expired sessions from the registry and persists the result.
  ///
  /// When the previously active session was expired, the most recently used
  /// non-expired account is automatically elected as the new active account.
  /// Listeners are notified if the active account changes.
  ///
  /// Returns the number of sessions that were removed.
  ///
  /// Throws [SessionOperationException] on failure.
  Future<int> cleanExpiredSessions() async {
    return _mutex.synchronized(() async {
      try {
        final cleaned = _registry.removeExpiredSessions();
        final removedCount = _registry.accountCount - cleaned.accountCount;

        if (removedCount > 0) {
          logInfo('Removing $removedCount expired session(s)');
          await _saveRegistry(cleaned);
          _notifyListeners(cleaned.activeSession);
        }

        return removedCount;
      } catch (e, stackTrace) {
        logError('Failed to clean expired sessions', e, stackTrace);
        throw SessionOperationException('clean expired sessions', e);
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Token helpers
  // ---------------------------------------------------------------------------

  /// Returns the access token for the active session, or `null`.
  ///
  /// Throws [TokenExpiredException] if the active session is expired.
  Future<String?> getAccessToken() async {
    final session = await getActiveSession();
    return session?.accessToken;
  }

  /// Returns the access token for [userId] without switching accounts.
  ///
  /// Useful for background API calls on behalf of a non-active account.
  /// Returns `null` if [userId] has no registered session.
  Future<String?> getAccessTokenForUser(String userId) async {
    final session = await getSession(userId);
    return session?.accessToken;
  }

  /// Returns `true` if [userId] has a registered, non-expired session.
  Future<bool> hasValidSession(String userId) async {
    final session = await getSession(userId);
    return session != null && !session.isExpired;
  }

  // ---------------------------------------------------------------------------
  // Advanced / debug
  // ---------------------------------------------------------------------------

  /// Exposes the current in-memory [SessionRegistry].
  ///
  /// Intended for debugging, testing, or advanced integrations. Avoid using
  /// this in production feature code; prefer the typed accessor methods.
  SessionRegistry getRegistry() => _registry;

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Deserialises the registry from [storage] into [_registry].
  Future<void> _loadRegistry() async {
    try {
      final data = await storage.read(_registryKey);

      if (data == null || data.isEmpty) {
        logDebug('No persisted registry found — starting with empty state');
        _registry = const SessionRegistry();
        return;
      }

      final json = jsonDecode(data) as Map<String, dynamic>;
      _registry = SessionRegistry.fromJson(json);

      logDebug('Registry loaded: ${_registry.accountCount} account(s)');
    } on FormatException catch (e, stackTrace) {
      // Corrupted data — reset to a clean state rather than hard-failing.
      logError(
          'Registry JSON corrupted — resetting to empty state', e, stackTrace);
      _registry = const SessionRegistry();
      await storage.delete(_registryKey);
    }
  }

  /// Serialises [registry] to [storage] and updates the in-memory state.
  Future<void> _saveRegistry(SessionRegistry registry) async {
    try {
      _registry = registry;
      final json = jsonEncode(registry.toJson());
      await storage.write(_registryKey, json);

      logDebug('Registry persisted: ${registry.accountCount} account(s)');
    } catch (e, stackTrace) {
      logError('Failed to persist registry', e, stackTrace);
      throw StorageException('save registry', e);
    }
  }

  /// Emits [session] to the broadcast stream and invokes all callbacks.
  void _notifyListeners(AuthSession? session) {
    if (!_sessionController.isClosed) {
      _sessionController.add(session);
    }

    for (final listener in List.of(_listeners)) {
      try {
        listener(session);
      } catch (e, stackTrace) {
        logError('Unhandled error in SessionChangeCallback', e, stackTrace);
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Internal: async mutex
// ---------------------------------------------------------------------------

/// A non-reentrant async mutex that serialises concurrent operations.
///
/// Ensures that only one [synchronized] block executes at a time, preventing
/// read-modify-write races in async Dart code. Safe for use with Dart's
/// single-threaded event loop; does NOT use `dart:isolate` primitives.
class _AsyncMutex {
  final _queue = <Completer<void>>[];
  bool _locked = false;

  /// Acquires the lock, runs [operation], then releases the lock.
  ///
  /// If the lock is held by another operation, this call suspends until the
  /// lock becomes available. Operations are granted the lock in FIFO order.
  ///
  /// The lock is always released; even if [operation] throws; preventing
  /// deadlocks.
  Future<T> synchronized<T>(Future<T> Function() operation) async {
    while (_locked) {
      final completer = Completer<void>();
      _queue.add(completer);
      await completer.future;
    }

    _locked = true;
    try {
      return await operation();
    } finally {
      _locked = false;

      if (_queue.isNotEmpty) {
        _queue.removeAt(0).complete();
      }
    }
  }
}

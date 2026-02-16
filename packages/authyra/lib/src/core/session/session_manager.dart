import 'dart:async';
import 'dart:convert';

import 'package:authyra/src/core/exceptions.dart';
import 'package:authyra/src/core/logger.dart';
import 'package:authyra/src/models/auth_session.dart';
import 'package:authyra/src/models/auth_user.dart';
import 'package:authyra/src/models/session_registry.dart';
import 'package:authyra/src/storage/auth_storage.dart';

/// Callback for when the active session changes
typedef SessionChangeCallback = void Function(AuthSession? session);

/// Manager for handling multiple authenticated sessions
class SessionManager with AuthyraLogging {
  final AuthStorage storage;
  final bool autoRefresh;

  static const String _registryKey = 'authyra_session_registry';

  /// Stream controller for session changes
  final _sessionController = StreamController<AuthSession?>.broadcast();

  /// Current in-memory registry
  SessionRegistry _registry = const SessionRegistry();

  /// Lock for atomic operations
  final _lock = _StorageLock();

  /// List of session change listeners
  final _listeners = <SessionChangeCallback>[];

  SessionManager({
    required this.storage,
    this.autoRefresh = true,
  });

  /// Stream of active session changes
  Stream<AuthSession?> get sessionStream => _sessionController.stream;

  /// Current active session (synchronous access)
  AuthSession? get activeSession => _registry.activeSession;

  /// Current active user
  AuthUser? get activeUser => _registry.activeSession?.user;

  /// All registered users
  List<AuthUser> get allUsers => _registry.allUsers;

  /// Number of registered accounts
  int get accountCount => _registry.accountCount;

  /// Check if there's an active session
  bool get hasActiveSession => _registry.hasActiveSession;

  /// Initialize the session manager
  Future<void> initialize() async {
    try {
      logInfo('Initializing SessionManager...');

      await storage.initialize();
      await _loadRegistry();

      // Clean up expired sessions on init
      if (_registry.hasAnySession) {
        final cleaned = _registry.removeExpiredSessions();
        if (cleaned.accountCount != _registry.accountCount) {
          logInfo('Removed ${_registry.accountCount - cleaned.accountCount} expired sessions');
          await _saveRegistry(cleaned);
        }
      }

      logInfo('SessionManager initialized with ${_registry.accountCount} accounts');
      _notifyListeners(_registry.activeSession);
    } catch (e, stackTrace) {
      logError('Failed to initialize SessionManager', e, stackTrace);
      throw StorageException('initialize', e);
    }
  }

  /// Add a session change listener
  void addListener(SessionChangeCallback callback) {
    _listeners.add(callback);
  }

  /// Remove a session change listener
  void removeListener(SessionChangeCallback callback) {
    _listeners.remove(callback);
  }

  /// Save or update a session
  Future<void> saveSession(
    AuthSession session, {
    bool setAsActive = true,
  }) async {
    return _lock.synchronized(() async {
      try {
        logDebug('Saving session for user: ${session.user.id}');

        final newRegistry = _registry.addSession(session, setAsActive: setAsActive);
        await _saveRegistry(newRegistry);

        if (setAsActive) {
          _notifyListeners(newRegistry.activeSession);
        }

        logInfo('Session saved successfully for user: ${session.user.id}');
      } catch (e, stackTrace) {
        logError('Failed to save session', e, stackTrace);
        throw StorageException('save session', e);
      }
    });
  }

  /// Get the active session
  Future<AuthSession?> getActiveSession() async {
    try {
      // Return in-memory active session if available
      final session = _registry.activeSession;

      if (session != null && session.isExpired) {
        logWarning('Active session expired for user: ${session.user.id}');

        // Try to refresh if possible
        if (autoRefresh && session.canRefresh) {
          logInfo('Attempting auto-refresh for expired session');
          // Note: Token refresh logic should be handled by the provider
          // This is just detection and notification
        }

        throw TokenExpiredException();
      }

      return session;
    } catch (e, stackTrace) {
      if (e is AuthyraException) rethrow;
      logError('Failed to get active session', e, stackTrace);
      throw StorageException('get active session', e);
    }
  }

  /// Get a specific session by user ID
  Future<AuthSession?> getSession(String userId) async {
    return _registry.sessions[userId];
  }

  /// Get all sessions
  Future<List<AuthSession>> getAllSessions() async {
    return _registry.allSessions;
  }

  /// Switch to a different account
  Future<void> switchAccount(String userId) async {
    return _lock.synchronized(() async {
      try {
        logInfo('Switching to account: $userId');

        if (!_registry.hasUser(userId)) {
          throw AccountNotFoundException(userId);
        }

        final session = _registry.sessions[userId]!;

        // Check if session is expired
        if (session.isExpired) {
          logWarning('Cannot switch to expired session: $userId');
          throw TokenExpiredException('Session for user $userId has expired');
        }

        final newRegistry = _registry.switchTo(userId);
        await _saveRegistry(newRegistry);

        _notifyListeners(newRegistry.activeSession);

        logInfo('Switched to account: $userId');
      } catch (e, stackTrace) {
        if (e is AuthyraException) rethrow;
        logError('Failed to switch account', e, stackTrace);
        throw SessionOperationException('switch account', e);
      }
    });
  }

  /// Remove a specific session
  Future<void> removeSession(String userId) async {
    return _lock.synchronized(() async {
      try {
        logInfo('Removing session for user: $userId');

        if (!_registry.hasUser(userId)) {
          logWarning('Session not found for user: $userId');
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

  /// Clear the active session (sign out current user)
  Future<void> clearActiveSession() async {
    return _lock.synchronized(() async {
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

  /// Clear all sessions (sign out all accounts)
  Future<void> clearAllSessions() async {
    return _lock.synchronized(() async {
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

  /// Update a session (e.g., after token refresh)
  Future<void> updateSession(String userId, AuthSession session) async {
    return _lock.synchronized(() async {
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

  /// Get the current access token
  Future<String?> getAccessToken() async {
    final session = await getActiveSession();
    return session?.accessToken;
  }

  /// Get access token for a specific user
  Future<String?> getAccessTokenForUser(String userId) async {
    final session = await getSession(userId);
    return session?.accessToken;
  }

  /// Check if a specific user has a valid session
  Future<bool> hasValidSession(String userId) async {
    final session = await getSession(userId);
    return session != null && !session.isExpired;
  }

  /// Get the session registry (for debugging or advanced use)
  SessionRegistry getRegistry() => _registry;

  /// Load registry from storage
  Future<void> _loadRegistry() async {
    try {
      final data = await storage.read(_registryKey);

      if (data == null || data.isEmpty) {
        logDebug('No existing registry found, starting fresh');
        _registry = const SessionRegistry();
        return;
      }

      final json = jsonDecode(data) as Map<String, dynamic>;
      _registry = SessionRegistry.fromJson(json);

      logDebug('Registry loaded with ${_registry.accountCount} accounts');
    } on FormatException catch (e, stackTrace) {
      logError('Registry data corrupted, resetting', e, stackTrace);
      _registry = const SessionRegistry();
      await storage.delete(_registryKey);
    }
  }

  /// Save registry to storage
  Future<void> _saveRegistry(SessionRegistry registry) async {
    try {
      _registry = registry;
      final json = jsonEncode(registry.toJson());
      await storage.write(_registryKey, json);

      logDebug('Registry saved with ${registry.accountCount} accounts');
    } catch (e, stackTrace) {
      logError('Failed to save registry', e, stackTrace);
      throw StorageException('save registry', e);
    }
  }

  /// Notify all listeners of session change
  void _notifyListeners(AuthSession? session) {
    // Stream
    if (!_sessionController.isClosed) {
      _sessionController.add(session);
    }

    // Callbacks
    for (final listener in _listeners) {
      try {
        listener(session);
      } catch (e, stackTrace) {
        logError('Error in session listener', e, stackTrace);
      }
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    await _sessionController.close();
    _listeners.clear();
    logDebug('SessionManager disposed');
  }
}

/// Simple lock for atomic storage operations
class _StorageLock {
  final _queue = <Completer<void>>[];
  bool _locked = false;

  Future<T> synchronized<T>(Future<T> Function() operation) async {
    // Wait for previous operations to complete
    while (_locked) {
      final completer = Completer<void>();
      _queue.add(completer);
      await completer.future;
    }

    // Lock and execute
    _locked = true;
    try {
      return await operation();
    } finally {
      _locked = false;

      // Release next operation in queue
      if (_queue.isNotEmpty) {
        final next = _queue.removeAt(0);
        next.complete();
      }
    }
  }
}

// abstract class AuthStorage {
//   Future<void> initialize();
//   Future<void> write(String key, String value);
//   Future<String?> read(String key);
//   Future<String?> delete(String key);
// }

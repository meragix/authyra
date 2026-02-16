import 'package:authyra/src/core/exceptions.dart';
import 'package:authyra/src/core/logger.dart';
import 'package:authyra/src/core/session/session_manager.dart';
import 'package:authyra/src/models/auth_session.dart';
import 'package:authyra/src/models/auth_state.dart';
import 'package:authyra/src/models/auth_user.dart';

/// Advanced multi-account management
///
/// This class provides features for managing multiple authenticated accounts.
/// Access it via `Authyra.instance.accounts`.
///
/// # Examples
///
/// ```dart
/// // Get all registered accounts
/// final accounts = await Authyra.instance.accounts.getAll();
///
/// // Switch to a different account
/// await Authyra.instance.accounts.switchTo('userId');
///
/// // Sign out a specific account
/// await Authyra.instance.accounts.signOut('userId');
///
/// // Sign out all accounts
/// await Authyra.instance.accounts.signOutAll();
///
/// // Check account count
/// final count = Authyra.instance.accounts.count;
/// ```
class MultiAccountManager with AuthyraLogging {
  final SessionManager sessionManager;
  //final BackendLinker? linker;
  final void Function(AuthState) onStateChange;

  MultiAccountManager({
    required this.sessionManager,
    //required this.linker,
    required this.onStateChange,
  });

  // ==========================================
  // Account Information
  // ==========================================

  /// Get all registered accounts
  ///
  /// Returns a list of all users that have active sessions.
  /// The list is sorted by last used (most recent first).
  ///
  /// Example:
  /// ```dart
  /// final accounts = await Authyra.instance.accounts.getAll();
  /// for (final user in accounts) {
  ///   print('${user.name} - ${user.email}');
  /// }
  /// ```
  Future<List<AuthUser>> getAll() async {
    try {
      return sessionManager.allUsers;
    } catch (e, stackTrace) {
      logError('Failed to get accounts', e, stackTrace);
      throw SessionOperationException('get accounts', e);
    }
  }

  /// Get all sessions (includes tokens and expiration info)
  ///
  /// Returns complete session information for all accounts.
  ///
  /// Example:
  /// ```dart
  /// final sessions = await Authyra.instance.accounts.getAllSessions();
  /// for (final session in sessions) {
  ///   print('${session.user.email} expires in ${session.timeUntilExpiration}');
  /// }
  /// ```
  Future<List<AuthSession>> getAllSessions() async {
    try {
      return await sessionManager.getAllSessions();
    } catch (e, stackTrace) {
      logError('Failed to get sessions', e, stackTrace);
      throw SessionOperationException('get sessions', e);
    }
  }

  /// Number of registered accounts
  ///
  /// Example:
  /// ```dart
  /// final count = Authyra.instance.accounts.count;
  /// if (count > 1) {
  ///   print('You have $count accounts');
  /// }
  /// ```
  int get count => sessionManager.accountCount;

  /// Check if there are multiple accounts
  ///
  /// Example:
  /// ```dart
  /// if (Authyra.instance.accounts.hasMultiple) {
  ///   // Show account switcher UI
  /// }
  /// ```
  bool get hasMultiple => sessionManager.accountCount > 1;

  /// Get the currently active user
  ///
  /// Example:
  /// ```dart
  /// final activeUser = Authyra.instance.accounts.active;
  /// print('Active: ${activeUser?.email}');
  /// ```
  AuthUser? get active => sessionManager.activeUser;

  // ==========================================
  // Account Switching
  // ==========================================

  /// Switch to a different account
  ///
  /// Changes the active account to the specified user.
  /// The user must already have a registered session.
  ///
  /// Throws [AccountNotFoundException] if the user doesn't exist.
  /// Throws [TokenExpiredException] if the session is expired.
  ///
  /// Example:
  /// ```dart
  /// try {
  ///   await Authyra.instance.accounts.switchTo('user123');
  ///   print('Switched successfully');
  /// } on AccountNotFoundException {
  ///   print('Account not found');
  /// }
  /// ```
  Future<void> switchTo(String userId) async {
    try {
      logInfo('Switching to account: $userId');
      await sessionManager.switchAccount(userId);

      final session = await sessionManager.getActiveSession();
      if (session != null) {
        onStateChange(AuthState.authenticated(session.user));
      }

      logInfo('Switched to account: $userId');
    } on AuthyraException {
      rethrow;
    } catch (e, stackTrace) {
      logError('Failed to switch account', e, stackTrace);
      throw SessionOperationException('switch account', e);
    }
  }

  /// Check if a specific user has a valid session
  ///
  /// Returns true if the user exists and their session is not expired.
  ///
  /// Example:
  /// ```dart
  /// if (await Authyra.instance.accounts.isValid('user123')) {
  ///   await Authyra.instance.accounts.switchTo('user123');
  /// }
  /// ```
  Future<bool> isValid(String userId) async {
    return sessionManager.hasValidSession(userId);
  }

  /// Get access token for a specific user
  ///
  /// Useful when making API calls on behalf of a specific account
  /// without switching the active account.
  ///
  /// Example:
  /// ```dart
  /// final token = await Authyra.instance.accounts.getTokenFor('user123');
  /// // Use token for API call
  /// ```
  Future<String?> getTokenFor(String userId) async {
    return sessionManager.getAccessTokenForUser(userId);
  }

  // ==========================================
  // Account Removal
  // ==========================================

  /// Sign out a specific account
  ///
  /// Removes the session for the specified user.
  /// If the user is currently active, switches to the next available account.
  ///
  /// Example:
  /// ```dart
  /// await Authyra.instance.accounts.signOut('user123');
  /// ```
  Future<void> signOut(String userId) async {
    try {
      logInfo('Signing out account: $userId');

      //final session = await sessionManager.getSession(userId);
      // if (session != null && linker != null) {
      //   try {
      //     //await linker!.onSignOut(session.user);
      //   } catch (e) {
      //     logWarning('Backend sign out notification failed', e);
      //   }
      // }

      await sessionManager.removeSession(userId);
      logInfo('Account signed out: $userId');
    } catch (e, stackTrace) {
      logError('Failed to sign out account', e, stackTrace);
      throw AuthyraErrorHandler.handleError(e, stackTrace);
    }
  }

  /// Sign out all accounts
  ///
  /// Clears all sessions and signs out from all accounts.
  ///
  /// Example:
  /// ```dart
  /// await Authyra.instance.accounts.signOutAll();
  /// // All accounts are now signed out
  /// ```
  Future<void> signOutAll() async {
    try {
      logInfo('Signing out all accounts');

      //final sessions = await sessionManager.getAllSessions();

      // // Notify backend for all sessions
      // if (linker != null) {
      //   for (final session in sessions) {
      //     try {
      //       await linker!.onSignOut(session.user);
      //     } catch (e) {
      //       logWarning('Backend sign out failed for ${session.user.id}', e);
      //     }
      //   }
      // }

      await sessionManager.clearAllSessions();
      onStateChange(AuthState.unauthenticated());

      logInfo('All accounts signed out');
    } catch (e, stackTrace) {
      logError('Failed to sign out all accounts', e, stackTrace);
      throw AuthyraErrorHandler.handleError(e, stackTrace);
    }
  }

  // ==========================================
  // Advanced Features
  // ==========================================

  /// Update session for a specific user
  ///
  /// This is typically used internally after token refresh,
  /// but can be used manually if needed.
  ///
  /// Example:
  /// ```dart
  /// final updatedSession = session.refreshed(
  ///   newAccessToken: 'new_token',
  ///   newExpiresAt: DateTime.now().add(Duration(hours: 1)),
  /// );
  /// await Authyra.instance.accounts.updateSession('user123', updatedSession);
  /// ```
  Future<void> updateSession(String userId, AuthSession session) async {
    try {
      await sessionManager.updateSession(userId, session);
      logDebug('Session updated for user: $userId');
    } catch (e, stackTrace) {
      logError('Failed to update session', e, stackTrace);
      throw SessionOperationException('update session', e);
    }
  }

  /// Remove expired sessions
  ///
  /// Cleans up any sessions that have expired tokens.
  /// This is called automatically on initialization, but can be
  /// called manually if needed.
  ///
  /// Example:
  /// ```dart
  /// await Authyra.instance.accounts.cleanExpired();
  /// ```
  Future<void> cleanExpired() async {
    try {
      final registry = sessionManager.getRegistry();
      final cleaned = registry.removeExpiredSessions();

      if (cleaned.accountCount != registry.accountCount) {
        await sessionManager.saveSession(cleaned.activeSession!);
        logInfo(
          'Removed ${registry.accountCount - cleaned.accountCount} expired sessions',
        );
      }
    } catch (e, stackTrace) {
      logError('Failed to clean expired sessions', e, stackTrace);
    }
  }
}

import 'package:authyra/src/core/exceptions.dart';
import 'package:authyra/src/core/logger.dart';
import 'package:authyra/src/core/session/session_manager.dart';
import 'package:authyra/src/models/auth_session.dart';
import 'package:authyra/src/models/auth_state.dart';
import 'package:authyra/src/models/auth_user.dart';

/// High-level multi-account management API.
///
/// [AccountManager] is the consumer-facing facade over [SessionManager].
/// It coordinates account switching, sign-out, and session maintenance while
/// propagating [AuthState] changes to the reactive layer via [onStateChange].
///
/// Access it through `AuthyraInstance.accounts` — do not construct it
/// directly in application code.
///
/// ## Example
///
/// ```dart
/// // Read all signed-in accounts (sorted by most recently used)
/// final accounts = await Authyra.instance.accounts.getAll();
///
/// // Switch the active account
/// await Authyra.instance.accounts.switchTo(userId);
///
/// // Sign out a specific account
/// await Authyra.instance.accounts.signOut(userId);
///
/// // Sign out every account at once
/// await Authyra.instance.accounts.signOutAll();
///
/// // Remove stale expired sessions
/// final removed = await Authyra.instance.accounts.cleanExpired();
/// ```
///
/// See also:
/// - [SessionManager], the persistence layer delegated to by this class.
/// - [AuthSession], the token + identity payload per account.
/// - [AuthState], the reactive state type emitted on every change.
class AccountManager with AuthyraLogging {
  /// The underlying session persistence and lifecycle manager.
  final SessionManager sessionManager;

  /// Callback invoked whenever the authentication state changes.
  ///
  /// Implementations should update the reactive state container
  /// (e.g., `StateNotifier`, `ChangeNotifier`, `BLoC`) held by
  /// `AuthyraInstance`.
  final void Function(AuthState) onStateChange;

  /// Creates an [AccountManager].
  ///
  /// Both [sessionManager] and [onStateChange] are required.
  AccountManager({
    required this.sessionManager,
    required this.onStateChange,
  });

  // ---------------------------------------------------------------------------
  // Account information
  // ---------------------------------------------------------------------------

  /// Returns all signed-in users, sorted by most recently used.
  ///
  /// The list reflects only the in-memory registry — no storage round-trip
  /// is made. Returns an empty list when no accounts are registered.
  ///
  /// ```dart
  /// final accounts = await Authyra.instance.accounts.getAll();
  /// for (final user in accounts) {
  ///   print('${user.name} — ${user.email}');
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

  /// Returns the full [AuthSession] for every registered account,
  /// sorted by most recently used.
  ///
  /// Prefer [getAll] for UI rendering. Use this when you need token or
  /// expiry information (e.g., to highlight accounts that need re-auth).
  ///
  /// ```dart
  /// final sessions = await Authyra.instance.accounts.getAllSessions();
  /// for (final s in sessions) {
  ///   print('${s.user.email} — expires in ${s.timeUntilExpiration}');
  /// }
  /// ```
  Future<List<AuthSession>> getAllSessions() async {
    try {
      return sessionManager.getAllSessions();
    } catch (e, stackTrace) {
      logError('Failed to get sessions', e, stackTrace);
      throw SessionOperationException('get sessions', e);
    }
  }

  /// Total number of registered accounts, including expired ones.
  ///
  /// ```dart
  /// if (Authyra.instance.accounts.count > 1) {
  ///   showAccountSwitcher();
  /// }
  /// ```
  int get count => sessionManager.accountCount;

  /// Whether more than one account is registered.
  ///
  /// Use this to conditionally show account-switcher UI.
  bool get hasMultiple => sessionManager.accountCount > 1;

  /// The currently active user, or `null` if no account is signed in.
  ///
  /// ```dart
  /// final user = Authyra.instance.accounts.active;
  /// print('Active: ${user?.email}');
  /// ```
  AuthUser? get active => sessionManager.activeUser;

  // ---------------------------------------------------------------------------
  // Account switching
  // ---------------------------------------------------------------------------

  /// Switches the active account to [userId] and notifies the reactive layer.
  ///
  /// Marks the target session as used (`lastUsedAt = now`) and persists the
  /// updated registry. [onStateChange] is called with
  /// [AuthState.authenticated] for the new active user.
  ///
  /// Throws [AccountNotFoundException] if [userId] has no registered session.
  /// Throws [TokenExpiredException] if the target session has expired.
  /// Throws [SessionOperationException] for other storage failures.
  ///
  /// ```dart
  /// try {
  ///   await Authyra.instance.accounts.switchTo('usr_01');
  /// } on AccountNotFoundException {
  ///   showError('Account not found');
  /// } on TokenExpiredException {
  ///   showError('Session expired — please sign in again');
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

  /// Returns `true` if [userId] has a registered, non-expired session.
  ///
  /// Use this before calling [switchTo] if you want to guard against
  /// switching to a stale account without surfacing an exception.
  ///
  /// ```dart
  /// if (await Authyra.instance.accounts.isValid(userId)) {
  ///   await Authyra.instance.accounts.switchTo(userId);
  /// }
  /// ```
  Future<bool> isValid(String userId) async {
    return sessionManager.hasValidSession(userId);
  }

  /// Returns the access token for [userId] without switching the active account.
  ///
  /// Useful for making background API calls on behalf of a non-active account
  /// (e.g., syncing data while the user is viewing a different account).
  /// Returns `null` if [userId] has no registered session.
  ///
  /// ```dart
  /// final token = await Authyra.instance.accounts.getTokenFor(userId);
  /// if (token != null) {
  ///   await myApi.sync(bearerToken: token);
  /// }
  /// ```
  Future<String?> getTokenFor(String userId) async {
    return sessionManager.getAccessTokenForUser(userId);
  }

  // ---------------------------------------------------------------------------
  // Account removal
  // ---------------------------------------------------------------------------

  /// Signs out the account identified by [userId].
  ///
  /// Removes the session from the registry and persists the change. When
  /// [userId] is the currently active account:
  ///
  /// - If another account exists, [onStateChange] is called with
  ///   [AuthState.authenticated] for the newly elected active account.
  /// - If no accounts remain, [onStateChange] is called with
  ///   [AuthState.unauthenticated].
  ///
  /// Returns without effect if [userId] has no registered session.
  ///
  /// ```dart
  /// await Authyra.instance.accounts.signOut(userId);
  /// ```
  Future<void> signOut(String userId) async {
    try {
      logInfo('Signing out account: $userId');

      final wasActive = sessionManager.activeUser?.id == userId;
      await sessionManager.removeSession(userId);

      // Propagate the resulting auth state when the active account changed.
      if (wasActive) {
        final newSession = sessionManager.activeSession;
        onStateChange(
          newSession != null
              ? AuthState.authenticated(newSession.user)
              : AuthState.unauthenticated(),
        );
      }

      logInfo('Account signed out: $userId');
    } catch (e, stackTrace) {
      logError('Failed to sign out account: $userId', e, stackTrace);
      throw AuthyraErrorHandler.handleError(e, stackTrace);
    }
  }

  /// Signs out all registered accounts.
  ///
  /// Clears the entire [SessionRegistry] and emits [AuthState.unauthenticated]
  /// via [onStateChange].
  ///
  /// ```dart
  /// await Authyra.instance.accounts.signOutAll();
  /// ```
  Future<void> signOutAll() async {
    try {
      logInfo('Signing out all accounts');

      await sessionManager.clearAllSessions();
      onStateChange(AuthState.unauthenticated());

      logInfo('All accounts signed out');
    } catch (e, stackTrace) {
      logError('Failed to sign out all accounts', e, stackTrace);
      throw AuthyraErrorHandler.handleError(e, stackTrace);
    }
  }

  // ---------------------------------------------------------------------------
  // Session maintenance
  // ---------------------------------------------------------------------------

  /// Replaces the session for [userId] with an updated [session].
  ///
  /// Typically called by the provider layer after a token refresh, or
  /// externally when server-side user data changes (e.g., name update).
  ///
  /// ```dart
  /// final renewed = session.refreshed(
  ///   newAccessToken: response.accessToken,
  ///   newExpiresAt: response.expiresAt,
  /// );
  /// await Authyra.instance.accounts.updateSession(userId, renewed);
  /// ```
  Future<void> updateSession(String userId, AuthSession session) async {
    try {
      await sessionManager.updateSession(userId, session);
      logDebug('Session updated for user: $userId');
    } catch (e, stackTrace) {
      logError('Failed to update session for user: $userId', e, stackTrace);
      throw SessionOperationException('update session', e);
    }
  }

  /// Removes all expired sessions and returns the count of removed entries.
  ///
  /// Called automatically during [SessionManager.initialize]. You may also
  /// call this manually on app foreground events or periodic background tasks
  /// to reclaim storage and keep the registry clean.
  ///
  /// Does not throw — errors are logged and swallowed, returning `0`.
  ///
  /// ```dart
  /// final removed = await Authyra.instance.accounts.cleanExpired();
  /// if (removed > 0) {
  ///   print('Cleaned $removed expired session(s)');
  /// }
  /// ```
  Future<int> cleanExpired() async {
    try {
      return await sessionManager.cleanExpiredSessions();
    } catch (e, stackTrace) {
      logError('Failed to clean expired sessions', e, stackTrace);
      return 0;
    }
  }
}

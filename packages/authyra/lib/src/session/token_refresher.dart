import 'dart:async';

import 'package:authyra/src/interfaces/auth_provider.dart';
import 'package:authyra/src/internal/logger.dart';
import 'package:authyra/src/models/auth_session.dart';

/// Provides fresh [AuthTokenResult] for [session].
///
/// Return `null` when the provider does not support refresh, the refresh
/// token is invalid or expired, or the session has no refresh token.
/// The refresher will treat a `null` return as a retryable failure and
/// exhaust [TokenRefresher.maxRetries] before expiring the session.
typedef RefreshProvider = Future<AuthTokenResult?> Function(AuthSession session);

/// Proactive token-refresh scheduler with linear retry and back-off.
///
/// [TokenRefresher] is owned by [SessionManager] and wired up by
/// [AuthyraClient] at construction time. A periodic timer polls the active
/// session; when its token is expiring within [threshold], the
/// [RefreshProvider] callback is invoked to obtain fresh tokens and the
/// session is updated in-place.
///
/// ## Retry policy
///
/// On a transient failure (provider returns `null` or throws), the refresher
/// retries up to [maxRetries] additional times with [retryDelay] between
/// attempts. If all attempts are exhausted, the session is expired by
/// calling the `onExpired` callback supplied to [start].
///
/// ## Lifecycle
///
/// ```dart
/// final refresher = TokenRefresher(provider: myProvider, threshold: config.refreshThreshold);
///
/// // Called by SessionManager.initialize when autoRefresh is true:
/// refresher.start(
///   getSession: () => registry.activeSession,
///   onRefreshed: (userId, updated) async { ... },
///   onExpired:   (session, error) async { ... },
/// );
///
/// // Called by SessionManager.dispose:
/// refresher.stop();
///
/// // Called by SessionManager.refreshActiveSession for on-demand refresh:
/// final updated = await refresher.refreshNow(session);
/// ```
///
/// See also:
/// - [SessionManager], which owns and starts this refresher.
/// - [AuthyraClient], which wires up the [RefreshProvider] callback.
class TokenRefresher with AuthyraLogging {
  final RefreshProvider _provider;
  final Duration _threshold;
  final Duration _checkInterval;
  final int _maxRetries;
  final Duration _retryDelay;

  Timer? _timer;
  bool _running = false;

  /// Creates a [TokenRefresher].
  ///
  /// [provider] is invoked with the current session when its token is expiring.
  /// [threshold] controls how far ahead of the expiry the refresh is triggered.
  /// [checkInterval] is the polling frequency of the background timer.
  /// [maxRetries] is the number of additional attempts after the first failure.
  /// [retryDelay] is the pause between each retry attempt.
  TokenRefresher({
    required RefreshProvider provider,
    required Duration threshold,
    Duration checkInterval = const Duration(minutes: 1),
    int maxRetries = 2,
    Duration retryDelay = const Duration(seconds: 5),
  })  : _provider = provider,
        _threshold = threshold,
        _checkInterval = checkInterval,
        _maxRetries = maxRetries,
        _retryDelay = retryDelay;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  /// Whether the background timer is currently running.
  bool get isRunning => _running;

  /// Starts the periodic expiry-check loop.
  ///
  /// On each tick, [getSession] is called to obtain the current active session.
  /// When a session is found to be expiring within [threshold] and has a
  /// refresh token:
  ///
  /// - On success: [onRefreshed] is called with `(userId, updatedSession)`.
  /// - On unrecoverable failure: [onExpired] is called with
  ///   `(session, errorMessage)`.
  ///
  /// Calling [start] while already running is a no-op.
  void start({
    required AuthSession? Function() getSession,
    required Future<void> Function(String userId, AuthSession updated) onRefreshed,
    required Future<void> Function(AuthSession session, String? error) onExpired,
  }) {
    if (_running) return;
    _running = true;

    _timer = Timer.periodic(_checkInterval, (_) async {
      final session = getSession();
      if (session == null) return;
      if (!session.shouldRefresh(threshold: _threshold)) return;

      if (!session.canRefresh) {
        logWarning(
          'Session expiring without a refresh token; '
          'expiring user: ${session.user.id}',
        );
        await onExpired(session, 'No refresh token available');
        return;
      }

      logInfo(
        'Proactive refresh triggered for user: ${session.user.id} '
        '(${session.timeUntilExpiration.inSeconds}s remaining)',
      );

      final updated = await _attemptRefresh(session);
      if (updated != null) {
        await onRefreshed(session.user.id, updated);
      } else {
        await onExpired(
          session,
          'Token refresh failed after ${_maxRetries + 1} attempt(s)',
        );
      }
    });

    logDebug(
      'TokenRefresher started '
      '(interval: ${_checkInterval.inSeconds}s, '
      'threshold: ${_threshold.inSeconds}s, '
      'maxRetries: $_maxRetries)',
    );
  }

  /// Stops the background timer without disposing the refresher.
  ///
  /// The refresher can be restarted by calling [start] again.
  void stop() {
    _timer?.cancel();
    _timer = null;
    _running = false;
    logDebug('TokenRefresher stopped');
  }

  // ---------------------------------------------------------------------------
  // On-demand refresh
  // ---------------------------------------------------------------------------

  /// Performs an immediate refresh of [session], bypassing the timer schedule.
  ///
  /// Applies the same retry policy as the background loop.
  /// Returns the updated [AuthSession] on success, or `null` when all
  /// attempts fail or the provider returns `null`.
  ///
  /// Used by [SessionManager.refreshActiveSession] for explicit refresh calls.
  Future<AuthSession?> refreshNow(AuthSession session) {
    logInfo('On-demand refresh for user: ${session.user.id}');
    return _attemptRefresh(session);
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  Future<AuthSession?> _attemptRefresh(AuthSession session) async {
    final totalAttempts = _maxRetries + 1;

    for (int attempt = 1; attempt <= totalAttempts; attempt++) {
      try {
        final result = await _provider(session);
        if (result != null) {
          logInfo(
            'Token refreshed for user: ${session.user.id} '
            '(attempt $attempt/$totalAttempts)',
          );
          return session.refreshed(
            newAccessToken: result.accessToken,
            newRefreshToken: result.refreshToken,
            newExpiresAt: result.expiresAt,
          );
        }
        logWarning(
          'Refresh returned null for user: ${session.user.id} '
          '(attempt $attempt/$totalAttempts)',
        );
      } catch (e, stackTrace) {
        logError(
          'Refresh error for user: ${session.user.id} '
          '(attempt $attempt/$totalAttempts)',
          e,
          stackTrace,
        );
      }

      if (attempt < totalAttempts) {
        logDebug('Retrying refresh in ${_retryDelay.inSeconds}s...');
        await Future.delayed(_retryDelay);
      }
    }

    logWarning(
      'All $totalAttempts refresh attempt(s) exhausted '
      'for user: ${session.user.id}',
    );
    return null;
  }
}

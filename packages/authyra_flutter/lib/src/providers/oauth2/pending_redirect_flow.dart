import 'dart:async';

/// Mixin providing a single-pending-request rendezvous with an external
/// redirect: a browser-based OAuth flow, a backend-driven deep link, or any
/// other "launch something, wait for a callback" pattern.
///
/// Call [awaitRedirect] to launch the flow and wait for [resolveRedirect] to
/// be invoked later from the app's deep-link handler. Starting a new flow
/// while a previous one is still unresolved cancels the stale one with
/// [buildCancelledError] instead of leaving it to hang until its own
/// timeout, so a second sign-in attempt never silently strands the first.
mixin PendingRedirectFlow<T> {
  Completer<T>? _pending;

  /// Whether a redirect is currently awaited (not yet resolved or timed out).
  bool get hasPendingRedirect => _pending != null && !_pending!.isCompleted;

  /// Starts a new pending redirect.
  ///
  /// Cancels any previous unresolved flow, invokes [launch] to kick off the
  /// external redirect, then waits up to [timeout] for [resolveRedirect].
  /// [buildCancelledError] is called lazily, both to cancel a stale flow and
  /// on timeout; each call may return a distinct exception instance.
  ///
  /// Rethrows whatever [launch] throws; the pending state is cleared first
  /// so a failed launch never leaves a dangling completer.
  Future<T> awaitRedirect({
    required Future<void> Function() launch,
    required Duration timeout,
    required Object Function() buildCancelledError,
  }) async {
    if (hasPendingRedirect) {
      _pending!.completeError(buildCancelledError());
    }

    final completer = Completer<T>();
    _pending = completer;

    try {
      await launch();
    } catch (_) {
      _pending = null;
      rethrow;
    }

    return completer.future.timeout(
      timeout,
      onTimeout: () => throw buildCancelledError(),
    );
  }

  /// Resolves the currently pending redirect with [value].
  ///
  /// Silently ignored when no flow is pending or it already resolved, so a
  /// stray or duplicate deep link never crashes the app.
  void resolveRedirect(T value) {
    if (!hasPendingRedirect) return;
    _pending!.complete(value);
  }

  /// Clears the pending flow state. Call from a `finally` block once
  /// [awaitRedirect] settles, successfully or not.
  void cleanupRedirect() {
    _pending = null;
  }
}

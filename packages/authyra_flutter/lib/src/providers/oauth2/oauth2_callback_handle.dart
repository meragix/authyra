import 'package:authyra/logging.dart';

/// Global deep-link dispatcher for [OAuth2Provider] instances.
///
/// Routes an incoming redirect [Uri] to the pending sign-in attempt whose
/// `state` query parameter matches. `state` is a fresh, cryptographically
/// random value generated per sign-in attempt (CSRF protection, RFC 6749
/// §10.12), so routing on it means two providers can safely share the same
/// redirect URI scheme; there is no scheme-collision risk to manage.
///
/// [OAuth2Provider] registers and unregisters itself automatically around
/// each [OAuth2Provider.signIn] call. Most apps only ever call
/// [handleCallback]; [registerPendingState] / [unregisterPendingState] are
/// internal plumbing exposed for custom [AuthProvider] implementations that
/// want to reuse the same dispatcher.
///
/// ## Setup (once, at app startup)
///
/// ```dart
/// // With package:app_links:
/// AppLinks().uriLinkStream.listen(OAuth2CallbackHandler.handleCallback);
/// ```
///
/// No per-provider registration step is needed: each [OAuth2Provider.signIn]
/// call registers its own `state` for the duration of the flow.
///
/// ## Testing
///
/// ```dart
/// tearDown(OAuth2CallbackHandler.clearAll);
/// ```
///
/// See also:
/// - [OAuth2Provider.handleRedirectCallback], invoked once routing succeeds.
/// - [ProxyOAuthProvider], which routes its own deep link directly via
///   [ProxyOAuthProvider.handleDeepLink] instead of this dispatcher.
class OAuth2CallbackHandler {
  OAuth2CallbackHandler._();

  static final Map<String, void Function(Uri uri)> _pendingByState = {};

  // ---------------------------------------------------------------------------
  // Registration (internal plumbing)
  // ---------------------------------------------------------------------------

  /// Registers [onCallback] to receive the deep link whose `state` query
  /// parameter equals [state].
  ///
  /// Called internally by [OAuth2Provider] at the start of each sign-in
  /// attempt. Registering under a [state] that is already registered
  /// replaces the previous registration.
  static void registerPendingState(
    String state,
    void Function(Uri uri) onCallback,
  ) {
    _pendingByState[state] = onCallback;
    AuthyraLogger.debug(
        '[OAuth2CallbackHandler] pending state registered: $state');
  }

  /// Removes the pending registration for [state], if any.
  ///
  /// Safe to call even if [state] was never registered or already resolved.
  static void unregisterPendingState(String state) {
    final removed = _pendingByState.remove(state);
    if (removed != null) {
      AuthyraLogger.debug(
          '[OAuth2CallbackHandler] pending state unregistered: $state');
    }
  }

  // ---------------------------------------------------------------------------
  // Dispatch
  // ---------------------------------------------------------------------------

  /// Routes an incoming deep-link [uri] to the matching pending sign-in.
  ///
  /// Reads `state` from the query parameters, falling back to the URI
  /// fragment for implicit-flow redirects. Logs a warning and does nothing
  /// if `state` is missing or does not match any pending sign-in (already
  /// resolved, timed out, or never registered).
  ///
  /// ```dart
  /// AppLinks().uriLinkStream.listen(OAuth2CallbackHandler.handleCallback);
  /// ```
  static void handleCallback(Uri uri) {
    final params = uri.queryParameters.isNotEmpty
        ? uri.queryParameters
        : (uri.fragment.isNotEmpty
            ? Uri.splitQueryString(uri.fragment)
            : const <String, String>{});

    final state = params['state'];
    if (state == null) {
      AuthyraLogger.warning(
        '[OAuth2CallbackHandler] callback has no "state" parameter, ignored: $uri',
      );
      return;
    }

    final onCallback = _pendingByState[state];
    if (onCallback == null) {
      AuthyraLogger.warning(
        '[OAuth2CallbackHandler] no pending sign-in for state "$state" '
        '(unknown, already resolved, or timed out)',
      );
      return;
    }

    onCallback(uri);
  }

  // ---------------------------------------------------------------------------
  // Teardown
  // ---------------------------------------------------------------------------

  /// Removes all pending registrations.
  ///
  /// Useful in test teardowns to prevent state from leaking between tests.
  static void clearAll() {
    _pendingByState.clear();
    AuthyraLogger.debug('[OAuth2CallbackHandler] all pending states cleared');
  }
}

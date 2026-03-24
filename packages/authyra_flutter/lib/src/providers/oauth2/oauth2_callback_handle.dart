import 'package:authyra/logging.dart';
import 'package:authyra_flutter/src/providers/oauth2/oauth2_provider.dart';

/// Global deep-link router for [OAuth2Provider] instances.
///
/// [OAuth2CallbackHandler] maintains a registry of active [OAuth2Provider]s
/// keyed by their redirect URI scheme (e.g., `'myapp'` from
/// `myapp://auth/callback`). When a deep link arrives, [handleCallback]
/// locates the matching provider and forwards the URI to
/// [OAuth2Provider.handleRedirectCallback].
///
/// ## Setup (once, at app startup)
///
/// ```dart
/// // Register each provider against its URI scheme:
/// OAuth2CallbackHandler.registerProvider('myapp', googleProvider);
/// OAuth2CallbackHandler.registerProvider('myapp', githubProvider);
/// // Note: if multiple providers share the same scheme, the last one wins.
/// // Use unique schemes per provider if you need parallel multi-provider support.
/// ```
///
/// ## Wiring the deep-link stream
///
/// Wire your platform deep-link handler to [handleCallback]:
///
/// ```dart
/// // With package:app_links:
/// AppLinks().uriLinkStream.listen(OAuth2CallbackHandler.handleCallback);
///
/// // Or manually in onGenerateRoute / GoRouter redirect:
/// final incoming = Uri.parse(link);
/// OAuth2CallbackHandler.handleCallback(incoming);
/// ```
///
/// ## Cleanup
///
/// Unregister providers when they are no longer needed (e.g., on dispose):
///
/// ```dart
/// OAuth2CallbackHandler.unregisterProvider('myapp');
/// ```
///
/// Or clear everything in tests:
///
/// ```dart
/// tearDown(OAuth2CallbackHandler.clearAll);
/// ```
///
/// ## Routing strategy
///
/// Callbacks are routed by `uri.scheme`. This means:
/// - Each unique custom scheme routes to exactly one registered provider.
/// - If two providers share a scheme (e.g., both use `myapp://`), register
///   them under distinct schemes or use [ProxyOAuthProvider] which handles
///   its own callback routing.
///
/// See also:
/// - [OAuth2Provider.handleRedirectCallback], the per-provider handler.
/// - [ProxyOAuthProvider], which manages its own deep-link routing via
///   [ProxyOAuthProvider.handleDeepLink].
class OAuth2CallbackHandler {
  OAuth2CallbackHandler._();

  static final Map<String, OAuth2Provider> _providers = {};

  // ---------------------------------------------------------------------------
  // Registration
  // ---------------------------------------------------------------------------

  /// Registers [provider] to receive deep-link callbacks for URIs whose
  /// scheme matches [scheme].
  ///
  /// [scheme] should be the URI scheme without `://`, e.g.:
  /// - Custom scheme: `'myapp'` (matches `myapp://auth/callback?code=…`)
  /// - Reverse client ID (Google): `'com.example.myapp'`
  ///
  /// Registering a second provider under the same [scheme] silently replaces
  /// the first. Use distinct schemes for parallel multi-provider support.
  static void registerProvider(String scheme, OAuth2Provider provider) {
    _providers[scheme] = provider;
    AuthyraLogger.debug(
        '[OAuth2CallbackHandler] registered provider "${provider.id}" for scheme "$scheme"');
  }

  /// Unregisters the provider associated with [scheme].
  ///
  /// Safe to call even if [scheme] was never registered.
  static void unregisterProvider(String scheme) {
    final removed = _providers.remove(scheme);
    if (removed != null) {
      AuthyraLogger.debug(
          '[OAuth2CallbackHandler] unregistered provider "${removed.id}" for scheme "$scheme"');
    }
  }

  // ---------------------------------------------------------------------------
  // Dispatch
  // ---------------------------------------------------------------------------

  /// Routes an incoming deep-link [uri] to the matching registered provider.
  ///
  /// Looks up the provider by `uri.scheme` and delegates to
  /// [OAuth2Provider.handleRedirectCallback]. Logs a warning if no provider
  /// is registered for that scheme.
  ///
  /// Typically called from the platform's deep-link stream:
  ///
  /// ```dart
  /// AppLinks().uriLinkStream.listen(OAuth2CallbackHandler.handleCallback);
  /// ```
  static void handleCallback(Uri uri) {
    AuthyraLogger.debug(
        '[OAuth2CallbackHandler] incoming callback — ${uri.toString()}');

    final provider = _providers[uri.scheme];
    if (provider != null) {
      provider.handleRedirectCallback(uri);
    } else {
      AuthyraLogger.warning(
        '[OAuth2CallbackHandler] no provider registered for scheme "${uri.scheme}"',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Teardown
  // ---------------------------------------------------------------------------

  /// Removes all registered providers.
  ///
  /// Useful in test teardowns to prevent state from leaking between tests.
  static void clearAll() {
    _providers.clear();
    AuthyraLogger.debug('[OAuth2CallbackHandler] all providers cleared');
  }
}

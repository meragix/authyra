import 'package:authyra/src/core/logger.dart';
import 'package:authyra/src/providers/oauth2/oauth2_provider.dart';

/// Global callback handler for OAuth2 providers
class OAuth2CallbackHandler {
  static final Map<String, OAuth2Provider> _providers = {};

   /// Register a provider to handle callbacks for a specific scheme
  static void registerProvider(String scheme, OAuth2Provider provider) {
    _providers[scheme] = provider;
    AuthyraLogger.debug('OAuth2 provider registered for scheme: $scheme');
  }

  /// Unregister a provider
  static void unregisterProvider(String scheme) {
    _providers.remove(scheme);
    AuthyraLogger.debug('OAuth2 provider unregistered for scheme: $scheme');
  }

  /// Handle incoming deep link callback
  static void handleCallback(Uri uri) {
    AuthyraLogger.debug('Handling OAuth2 callback: ${uri.toString()}');
    
    final scheme = uri.scheme;
    final provider = _providers[scheme];

    if (provider != null) {
      provider.handleRedirectCallback(uri);
    } else {
      AuthyraLogger.warning(
        'No OAuth2 provider registered for scheme: $scheme',
      );
    }
  }

  /// Clear all registered providers
  static void clearAll() {
    _providers.clear();
    AuthyraLogger.debug('All OAuth2 providers cleared');
  }
}

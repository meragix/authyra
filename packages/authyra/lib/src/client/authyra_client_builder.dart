import 'package:authyra/src/callbacks/auth_callbacks.dart';
import 'package:authyra/src/client/authyra_client.dart';
import 'package:authyra/src/exceptions/auth_exceptions.dart';
import 'package:authyra/src/interfaces/auth_provider.dart';
import 'package:authyra/src/interfaces/auth_storage.dart';
import 'package:authyra/src/models/auth_config.dart';
import 'package:authyra/src/plugins/auth_plugin.dart';

/// Fluent builder for [AuthyraClient].
///
/// Provides a chainable API for constructing an [AuthyraClient] without
/// long positional constructor arguments. Useful when configuring providers
/// and options conditionally at startup.
///
/// ## Basic usage
///
/// ```dart
/// final client = AuthyraClientBuilder()
///   .addProvider(CredentialsProvider(
///     id: 'email',
///     authorize: myAuthorize,
///   ))
///   .addProvider(GoogleProvider(clientId: 'YOUR_CLIENT_ID'))
///   .setStorage(SecureAuthStorage())
///   .build();
///
/// await client.initialize();
/// ```
///
/// ## With optional configuration
///
/// ```dart
/// final client = AuthyraClientBuilder()
///   .addProvider(CredentialsProvider(id: 'email', authorize: myAuthorize))
///   .setStorage(SecureAuthStorage())
///   .setConfig(const AuthConfig(
///     tokenLifetime: 1800,
///     refreshBeforeExpiry: 120,
///   ))
///   .setCallbacks(MyAuthCallbacks())
///   .build();
/// ```
///
/// ## Validation
///
/// [build] throws [InvalidConfigurationException] if [setStorage] was not
/// called or no providers were added via [addProvider].
///
/// See also:
/// - [AuthyraClient], the object produced by [build].
/// - [AuthConfig], for token lifetime and auto-refresh settings.
/// - [AuthCallbacks], for middleware hooks (sign-in guards, audit logging).
class AuthyraClientBuilder {
  final List<AuthProvider> _providers = [];
  final List<AuthyraPlugin> _plugins = [];
  AuthStorage? _storage;
  AuthConfig _config = const AuthConfig();
  AuthCallbacks? _callbacks;

  /// Appends [provider] to the provider list.
  ///
  /// Providers are registered in the order they are added. Multiple providers
  /// with distinct [AuthProvider.id] values are accepted; duplicate IDs are
  /// rejected by [AuthyraClient] at [build] time.
  ///
  /// Returns `this` for chaining.
  ///
  /// ```dart
  /// builder
  ///   .addProvider(CredentialsProvider(id: 'email', authorize: myAuthorize))
  ///   .addProvider(GoogleProvider(clientId: 'YOUR_CLIENT_ID'));
  /// ```
  AuthyraClientBuilder addProvider(AuthProvider provider) {
    _providers.add(provider);
    return this;
  }

  /// Sets the storage backend used to persist sessions across app restarts.
  ///
  /// Required; [build] throws [InvalidConfigurationException] if omitted.
  /// Pass an encrypted implementation; never use plaintext storage for tokens.
  ///
  /// Returns `this` for chaining.
  ///
  /// See also: [AuthStorage], the pluggable persistence interface.
  AuthyraClientBuilder setStorage(AuthStorage storage) {
    _storage = storage;
    return this;
  }

  /// Overrides the default [AuthConfig].
  ///
  /// Optional; defaults to `const AuthConfig()` when not called.
  ///
  /// Returns `this` for chaining.
  ///
  /// ```dart
  /// builder.setConfig(const AuthConfig(
  ///   tokenLifetime: 3600,
  ///   autoRefresh: false, // disable for CLI / backend use
  /// ));
  /// ```
  AuthyraClientBuilder setConfig(AuthConfig config) {
    _config = config;
    return this;
  }

  /// Appends [plugin] to the plugin list.
  ///
  /// Plugins are installed in the order they are added. Each plugin's
  /// [AuthyraPlugin.install] is called once during [build].
  ///
  /// Returns `this` for chaining.
  ///
  /// ```dart
  /// builder
  ///   .addPlugin(AuditLogPlugin(myLogger))
  ///   .addPlugin(RateLimitPlugin(maxAttempts: 5));
  /// ```
  AuthyraClientBuilder addPlugin(AuthyraPlugin plugin) {
    _plugins.add(plugin);
    return this;
  }

  /// Attaches an [AuthCallbacks] middleware instance to the client.
  ///
  /// Optional. When provided, callback methods are invoked before sign-in,
  /// sign-out, session creation, account switching, and token refresh.
  /// Returning [CallbackResult.deny] from any hook blocks the corresponding
  /// operation.
  ///
  /// Returns `this` for chaining.
  AuthyraClientBuilder setCallbacks(AuthCallbacks callbacks) {
    _callbacks = callbacks;
    return this;
  }

  /// Builds and returns a fully configured [AuthyraClient].
  ///
  /// Throws [InvalidConfigurationException] if:
  /// - No storage backend was set via [setStorage].
  /// - No providers were added via [addProvider].
  ///
  /// The returned client is **not yet initialised**; call
  /// [AuthyraClient.initialize] before invoking sign-in or session accessors.
  ///
  /// ```dart
  /// final client = AuthyraClientBuilder()
  ///   .addProvider(myProvider)
  ///   .setStorage(myStorage)
  ///   .build();
  ///
  /// await client.initialize();
  /// ```
  AuthyraClient build() {
    if (_storage == null) {
      throw InvalidConfigurationException(
        'AuthyraClientBuilder: storage is required; call setStorage() before build().',
      );
    }
    if (_providers.isEmpty) {
      throw InvalidConfigurationException(
        'AuthyraClientBuilder: at least one provider is required; call addProvider() before build().',
      );
    }
    return AuthyraClient(
      providers: List.unmodifiable(_providers),
      storage: _storage!,
      config: _config,
      callbacks: _callbacks,
      plugins: _plugins,
    );
  }
}

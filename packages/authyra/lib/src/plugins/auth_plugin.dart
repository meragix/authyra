import 'package:authyra/src/client/authyra_client.dart';
import 'package:authyra/src/interfaces/auth_sign_in_params.dart';
import 'package:authyra/src/models/auth_session.dart';

/// Extension point for adding cross-cutting behaviour to [AuthyraClient].
///
/// Implement [AuthyraPlugin] to hook into the authentication lifecycle without
/// modifying the client or wrapping it. Plugins are installed once at
/// construction time via [AuthyraClient.plugins]; from that point on the
/// client calls the appropriate hooks automatically.
///
/// ## Difference from [AuthCallbacks]
///
/// [AuthCallbacks] is a single middleware object with allow/deny semantics
/// (it can block operations). [AuthyraPlugin] is an **observer with side
/// effects**: hooks are `Future<void>`; they cannot block sign-in, but they
/// can maintain their own state, call external services, or listen to
/// [AuthyraClient.events] for richer integrations.
///
/// ## Implementing a plugin
///
/// ```dart
/// class AuditLogPlugin extends AuthyraPlugin {
///   final Logger _logger;
///
///   AuditLogPlugin(this._logger);
///
///   @override
///   String get name => 'audit_log';
///
///   @override
///   void install(AuthyraClient client) {
///     // Wire up to the event bus for additional events not covered by hooks.
///     client.events.on<AccountSwitchEvent>((e) {
///       _logger.info('Account switched: ${e.fromUser.id} → ${e.toUser.id}');
///     });
///   }
///
///   @override
///   Future<void> onAfterSignIn(AuthSession session) async {
///     await _logger.info('Sign in: ${session.user.email}');
///   }
/// }
/// ```
///
/// ## Registration
///
/// ```dart
/// final client = AuthyraClientBuilder()
///   .addProvider(myProvider)
///   .setStorage(myStorage)
///   .addPlugin(AuditLogPlugin(myLogger))
///   .addPlugin(RateLimitPlugin(maxAttempts: 5))
///   .build();
/// ```
///
/// See also:
/// - [AuthyraClient.plugins], the list of installed plugins.
/// - [AuthCallbacks], for blocking middleware (allow/deny gates).
/// - [AuthEventBus], for subscribing to typed events inside [install].
abstract class AuthyraPlugin {
  /// Unique identifier for this plugin.
  ///
  /// Used in log output. Convention: `snake_case` (e.g., `'rate_limit'`,
  /// `'audit_log'`, `'two_factor'`).
  String get name;

  /// Called once when this plugin is registered with [AuthyraClient].
  ///
  /// Use [install] to store a reference to [client], subscribe to
  /// [AuthyraClient.events], or perform any one-time setup. The client is
  /// fully constructed but **not yet initialised** when [install] is called;
  /// do not call [AuthyraClient.signIn] or session accessors here.
  ///
  /// ```dart
  /// @override
  /// void install(AuthyraClient client) {
  ///   client.events.on<SignInFailedEvent>((e) => _recordFailure(e));
  /// }
  /// ```
  void install(AuthyraClient client);

  /// Called before the authentication provider processes a sign-in request.
  ///
  /// Receives the target [providerId] and the (possibly `null`) [params].
  /// This hook is **not a gate**; returning normally always allows the
  /// sign-in to proceed. To block sign-ins, use [AuthCallbacks.onBeforeSignIn]
  /// instead.
  ///
  /// Default implementation: no-op.
  Future<void> onBeforeSignIn(
    String providerId,
    AuthSignInParams? params,
  ) async {}

  /// Called after a successful sign-in and the session is persisted.
  ///
  /// [session] is the newly created or updated active session.
  ///
  /// Default implementation: no-op.
  Future<void> onAfterSignIn(AuthSession session) async {}

  /// Called when an active session expires and is cleared from the registry.
  ///
  /// Triggered by both background token-refresh exhaustion and explicit
  /// expiry checks. [session] is the expired session before removal.
  ///
  /// Default implementation: no-op.
  Future<void> onSessionExpired(AuthSession session) async {}
}

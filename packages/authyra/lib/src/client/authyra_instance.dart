import 'dart:async';

import 'package:authyra/src/client/authyra_client.dart';
import 'package:authyra/src/exceptions/auth_exceptions.dart';
import 'package:authyra/src/interfaces/auth_sign_in_params.dart';
import 'package:authyra/src/internal/logger.dart';
import 'package:authyra/src/session/account_manager.dart';
import 'package:authyra/src/models/auth_session.dart';
import 'package:authyra/src/models/auth_state.dart';
import 'package:authyra/src/models/auth_user.dart';

/// Singleton wrapper around [AuthyraClient] for Flutter applications.
///
/// [AuthyraInstance] adds:
///
/// - **Global access** via [instance] — no need to pass the client down the
///   widget tree.
/// - **Synchronous state** — [currentUser], [currentState], and
///   [isAuthenticated] reflect the latest state without awaiting a `Future`.
/// - **Reactive streams** — [authStateChanges] and [sessionStream] for
///   Riverpod, BLoC, `StreamBuilder`, or any reactive framework.
/// - **Multi-account API** — [accounts] surfaces the full [AccountManager].
///
/// ## Initialization (once, at app startup)
///
/// ```dart
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///
///   await Authyra.initialize(
///     client: AuthyraClient(
///       providers: [
///         CredentialsProvider(id: 'email', authorize: myAuthorize),
///         GoogleProvider(clientId: 'YOUR_CLIENT_ID'),
///       ],
///       storage: SecureAuthStorage(),
///     ),
///   );
///
///   runApp(const MyApp());
/// }
/// ```
///
/// ## Usage
///
/// ```dart
/// // Sign in
/// await Authyra.instance.signIn('email', params: {
///   'email': 'alice@example.com',
///   'password': 's3cr3t',
/// });
///
/// // Synchronous state check
/// if (Authyra.instance.isAuthenticated) {
///   print('Hello, ${Authyra.instance.currentUser!.displayName}');
/// }
///
/// // Reactive state
/// StreamBuilder<AuthState>(
///   stream: Authyra.instance.authStateChanges,
///   builder: (context, snapshot) {
///     final state = snapshot.data ?? AuthState.unauthenticated();
///     return state.isAuthenticated
///         ? DashboardPage(user: state.user!)
///         : LoginPage();
///   },
/// )
/// ```
///
/// ## Teardown
///
/// ```dart
/// // In tests or when switching accounts environments:
/// await Authyra.instance.dispose();
/// ```
///
/// See also:
/// - [AuthyraClient], the underlying stateless orchestrator.
/// - [AccountManager], for multi-account switching and sign-out.
/// - [AuthState], the reactive state type emitted by [authStateChanges].
class AuthyraInstance with AuthyraLogging {
  // ---------------------------------------------------------------------------
  // Singleton
  // ---------------------------------------------------------------------------

  static AuthyraInstance? _instance;

  /// The global [AuthyraInstance] singleton.
  ///
  /// Throws [NotInitializedException] if accessed before [initialize] has
  /// completed successfully.
  static AuthyraInstance get instance {
    if (_instance == null) throw NotInitializedException();
    return _instance!;
  }

  /// Whether [initialize] has been called and completed successfully.
  static bool get isInitialized => _instance != null;

  AuthyraInstance._();

  // ---------------------------------------------------------------------------
  // Internal state
  // ---------------------------------------------------------------------------

  late AuthyraClient _client;

  /// Cached latest [AuthState] for synchronous access.
  AuthState _currentState = AuthState.unauthenticated();

  final _stateController = StreamController<AuthState>.broadcast();
  StreamSubscription<AuthState>? _stateSub;
  bool _disposed = false;

  // ---------------------------------------------------------------------------
  // Initialization
  // ---------------------------------------------------------------------------

  /// Initialises the singleton with [client] and restores persisted sessions.
  ///
  /// - Calls [AuthyraClient.initialize] to load sessions from storage.
  /// - Seeds [currentState] from any restored session.
  /// - Subscribes to [AuthyraClient.authStateStream] to keep [currentState]
  ///   in sync with all subsequent auth events.
  ///
  /// Calling [initialize] a second time before [dispose] is a **no-op** —
  /// the existing instance is returned unchanged.
  ///
  /// Throws [StorageException] or other [AuthyraException] subclasses when
  /// the underlying client cannot be initialised.
  static Future<AuthyraInstance> initialize({
    required AuthyraClient client,
  }) async {
    if (_instance != null) {
      AuthyraLogger.info('AuthyraInstance already initialised — skipping');
      return _instance!;
    }

    AuthyraLogger.info('Initialising AuthyraInstance');
    final inst = AuthyraInstance._();
    inst._client = client;

    try {
      await client.initialize();

      // Mirror the client's auth state stream into our own controller.
      inst._stateSub = client.authStateStream.listen((state) {
        inst._currentState = state;
        if (!inst._stateController.isClosed) {
          inst._stateController.add(state);
        }
      });

      // Seed the initial state from any session restored from storage.
      final session = await client.getSession();
      if (session != null) {
        inst._currentState = AuthState.authenticated(session.user);
        if (!inst._stateController.isClosed) {
          inst._stateController.add(inst._currentState);
        }
      }

      _instance = inst;
      AuthyraLogger.info('AuthyraInstance ready');
      return inst;
    } catch (e, stackTrace) {
      AuthyraLogger.error(
          'AuthyraInstance initialisation failed', e, stackTrace);
      rethrow;
    }
  }

  /// Releases all resources and resets the global singleton.
  ///
  /// After disposal, [instance] will throw [NotInitializedException] until
  /// [initialize] is called again. Safe to call multiple times.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;

    await _stateSub?.cancel();
    await _stateController.close();
    await _client.dispose();

    _instance = null;
    logDebug('AuthyraInstance disposed');
  }

  // ---------------------------------------------------------------------------
  // Synchronous state (no async needed)
  // ---------------------------------------------------------------------------

  /// The currently active [AuthUser], or `null` if not signed in.
  ///
  /// Updated synchronously on every [authStateChanges] emission — safe to
  /// read in build methods without awaiting.
  AuthUser? get currentUser => _currentState.user;

  /// The latest [AuthState] snapshot.
  ///
  /// Use [authStateChanges] to react to future changes.
  AuthState get currentState => _currentState;

  /// `true` when there is an active, non-expired session.
  bool get isAuthenticated => _currentState.isAuthenticated;

  // ---------------------------------------------------------------------------
  // Async session accessors
  // ---------------------------------------------------------------------------

  /// Returns the currently active [AuthSession], or `null`.
  ///
  /// Throws [TokenExpiredException] when the session exists but has expired.
  Future<AuthSession?> getSession() => _client.getSession();

  /// Returns the currently active [AuthUser], or `null`.
  Future<AuthUser?> getUser() => _client.getUser();

  /// Returns the active access token, or `null`.
  ///
  /// Throws [TokenExpiredException] when the session is expired.
  Future<String?> getAccessToken() => _client.getAccessToken();

  // ---------------------------------------------------------------------------
  // Reactive streams
  // ---------------------------------------------------------------------------

  /// Broadcast stream of [AuthState] changes.
  ///
  /// Emits whenever the authentication state changes (sign-in, sign-out,
  /// token refresh, account switch, error). Because [AuthState] uses
  /// [Equatable], identical consecutive states are deduplicated.
  ///
  /// ```dart
  /// Authyra.instance.authStateChanges.listen((state) {
  ///   switch (state.type) {
  ///     case AuthStateType.authenticated:   router.go('/dashboard');
  ///     case AuthStateType.unauthenticated: router.go('/login');
  ///     case AuthStateType.error:           showBanner(state.error!);
  ///   }
  /// });
  /// ```
  Stream<AuthState> get authStateChanges => _stateController.stream;

  /// Broadcast stream of raw [AuthSession] changes.
  ///
  /// Emits `null` when no account is active. Prefer [authStateChanges]
  /// for most use cases.
  Stream<AuthSession?> get sessionStream => _client.sessionStream;

  // ---------------------------------------------------------------------------
  // Authentication actions
  // ---------------------------------------------------------------------------

  /// Signs in using the provider identified by [providerId].
  ///
  /// Delegates to [AuthyraClient.signIn] — see its documentation for the
  /// full contract, param table, and throwable exceptions.
  ///
  /// ```dart
  /// final user = await Authyra.instance.signIn('email', params: {
  ///   'email': 'alice@example.com',
  ///   'password': 's3cr3t',
  /// });
  /// ```
  Future<AuthUser> signIn(
    String providerId, {
    AuthSignInParams? params,
  }) =>
      _client.signIn(providerId, params: params);

  /// Signs out the currently active account.
  ///
  /// Delegates to [AuthyraClient.signOut]. See its documentation for the full
  /// contract including multi-account behaviour and server-side revocation.
  ///
  /// ```dart
  /// await Authyra.instance.signOut();
  /// ```
  Future<void> signOut() => _client.signOut();

  /// Silently refreshes the active session's access token.
  ///
  /// Delegates to [AuthyraClient.refreshSession].
  ///
  /// Returns `true` when the refresh succeeded.
  Future<bool> refreshSession() => _client.refreshSession();

  // ---------------------------------------------------------------------------
  // Multi-account
  // ---------------------------------------------------------------------------

  /// Multi-account management API.
  ///
  /// ```dart
  /// final users = await Authyra.instance.accounts.getAll();
  /// await Authyra.instance.accounts.switchTo(userId);
  /// await Authyra.instance.accounts.signOutAll();
  /// ```
  AccountManager get accounts => _client.accounts;

  // ---------------------------------------------------------------------------
  // Advanced
  // ---------------------------------------------------------------------------

  /// Direct access to the underlying [AuthyraClient].
  ///
  /// Prefer the typed methods on [AuthyraInstance]. Use this only for advanced
  /// integrations (e.g., dynamic [AuthProvider] registration).
  AuthyraClient get client => _client;
}

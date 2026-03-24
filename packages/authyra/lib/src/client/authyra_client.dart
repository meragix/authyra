import 'dart:async';

import 'package:authyra/src/callbacks/auth_callbacks.dart';
import 'package:authyra/src/models/auth_sign_in_result.dart';
import 'package:authyra/src/plugins/auth_plugin.dart';
import 'package:authyra/src/events/auth_events.dart';
import 'package:authyra/src/events/auth_event_bus.dart';
import 'package:authyra/src/exceptions/auth_exceptions.dart';
import 'package:authyra/src/internal/logger.dart';
import 'package:authyra/src/models/auth_account.dart';
import 'package:authyra/src/session/account_manager.dart';
import 'package:authyra/src/session/session_manager.dart';
import 'package:authyra/src/models/auth_config.dart';
import 'package:authyra/src/models/auth_session.dart';
import 'package:authyra/src/models/auth_state.dart';
import 'package:authyra/src/models/auth_user.dart';
import 'package:authyra/src/interfaces/auth_provider.dart';
import 'package:authyra/src/interfaces/auth_sign_in_params.dart';
import 'package:authyra/src/interfaces/auth_storage.dart';

/// Stateless authentication orchestrator: the core of the Authyra framework.
///
/// [AuthyraClient] manages provider registration, session lifecycle, and token
/// operations. It has **no global state** and runs on any Dart platform:
/// Flutter, backend (Shelf / Dart Frog), or CLI.
///
/// For Flutter applications, prefer `AuthyraInstance` which wraps this client
/// with a singleton, reactive streams, and a simplified initialization API.
///
/// ## Setup
///
/// ```dart
/// final client = AuthyraClient(
///   providers: [
///     CredentialsProvider(
///       id: 'email',
///       authorize: (creds) async {
///         final res = await myApi.post('/login', body: {
///           'email': creds?.email,
///           'password': creds?.password,
///         });
///         if (res.statusCode != 200) return null;
///         return AuthUser(id: res.data['userId'], email: res.data['email']);
///       },
///     ),
///     GoogleProvider(clientId: 'YOUR_CLIENT_ID'),
///   ],
///   storage: SecureAuthStorage(),
/// );
///
/// await client.initialize();
/// ```
///
/// ## Sign in
///
/// ```dart
/// final user = await client.signIn('email', params: CredentialsSignInParams(
///   email: 'alice@example.com',
///   password: 's3cr3t',
/// ));
/// ```
///
/// ## Reactive state
///
/// ```dart
/// client.authStateStream.listen((state) {
///   if (state.isAuthenticated) navigateToDashboard();
/// });
/// ```
///
/// ## Events
///
/// ```dart
/// client.events.on<SignInEvent>((event) {
///   print('Signed in: ${event.user.email}');
/// });
/// ```
///
/// ## Multi-account
///
/// ```dart
/// await client.accounts.switchTo(otherUserId);
/// await client.accounts.signOut(userId);
/// ```
///
/// See also:
/// - [AuthyraInstance], the singleton wrapper for Flutter apps.
/// - [AuthProvider], the interface for adding authentication strategies.
/// - [AuthStorage], the pluggable session persistence backend.
/// - [AccountManager], the multi-account management API.
class AuthyraClient with AuthyraLogging {
  /// Authentication providers registered with this client.
  ///
  /// Providers are registered at construction time. Use [registerProvider]
  /// to add providers dynamically after construction.
  final List<AuthProvider> providers;

  /// Storage backend used to persist sessions across app restarts.
  final AuthStorage storage;

  /// Configuration controlling token lifetime and auto-refresh behaviour.
  final AuthConfig config;

  /// Plugins installed on this client.
  ///
  /// Each plugin's [AuthyraPlugin.install] is called once during construction.
  final List<AuthyraPlugin> plugins;

  // Internal provider registry (id → provider).
  final Map<String, AuthProvider> _providerMap = {};

  // Session management layer (created internally).
  late final SessionManager _sessionManager;

  // Lazy-initialised multi-account facade.
  AccountManager? _accountManager;

  // Custom callbacks (middleware).
  AuthCallbacks? _callbacks;

  // Scoped event bus — one instance per client, no global singleton.
  final AuthEventBus _eventBus = AuthEventBus();

  // Broadcast stream for AuthState changes.
  final _authStateController = StreamController<AuthState>.broadcast();

  bool _initialized = false;

  /// Creates an [AuthyraClient].
  ///
  /// Providers are registered immediately from [providers]. Call [initialize]
  /// before using sign-in or session accessor methods.
  ///
  /// Throws [ProviderAlreadyRegisteredException] if two providers share the
  /// same [AuthProvider.id].
  AuthyraClient({
    required this.providers,
    required this.storage,
    AuthCallbacks? callbacks,
    this.config = const AuthConfig(),
    List<AuthyraPlugin>? plugins,
  })  : plugins = List.unmodifiable(plugins ?? const []) {
    for (final provider in providers) {
      if (_providerMap.containsKey(provider.id)) {
        throw ProviderAlreadyRegisteredException(provider.id);
      }
      _providerMap[provider.id] = provider;
    }

    _sessionManager = SessionManager(
      storage: storage,
      autoRefresh: config.autoRefresh,
      refreshThreshold: config.refreshThreshold,
      refreshProvider: (session) async {
        final provider = _providerMap[session.providerId];
        if (provider == null || !provider.supportsRefresh || !session.canRefresh) {
          return null;
        }
        return provider.refreshToken(session.refreshToken!);
      },
    );
    _sessionManager.addListener(_onSessionChanged);
    _sessionManager.setRefreshCallbacks(
      onSuccess: (session) {
        _eventBus.emit(TokenRefreshEvent(user: session.user, success: true));
        _emitAuthState(AuthState.authenticated(session.user));
      },
      onFailure: (session, error) async {
        _eventBus.emit(TokenRefreshEvent(
          user: session.user,
          success: false,
          errorMessage: error,
        ));
        _eventBus.emit(SessionExpiredEvent(
          user: session.user,
          expiredAt: session.expirationOrNow,
        ));
        _emitAuthState(AuthState.unauthenticated());
        await _notifyPluginsSessionExpired(session);
      },
    );

    if (callbacks != null) {
      _callbacks = callbacks;
      logInfo('Custom callbacks registered');
    }

    for (final plugin in this.plugins) {
      plugin.install(this);
      logDebug('Plugin installed: ${plugin.name}');
    }
  }

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  /// Initialises the client by restoring persisted sessions from [storage].
  ///
  /// Must be called and awaited once before [signIn], [signOut], or any
  /// session accessor. A second call is a no-op.
  ///
  /// Throws [StorageException] if the storage backend cannot be started.
  Future<void> initialize() async {
    if (_initialized) return;
    try {
      logInfo(
        'Initializing AuthyraClient — providers: '
        '[${_providerMap.keys.join(', ')}]',
      );
      await _sessionManager.initialize();
      _initialized = true;
      final count = _sessionManager.accountCount;
      logInfo(count > 0
          ? 'AuthyraClient ready — $count account(s) restored'
          : 'AuthyraClient ready');
    } catch (e, stackTrace) {
      logError('Failed to initialize AuthyraClient', e, stackTrace);
      rethrow;
    }
  }

  /// Releases all resources held by this client.
  ///
  /// After disposal the client must not be used. When using [AuthyraInstance],
  /// call its own `dispose()` method instead.
  Future<void> dispose() async {
    await _sessionManager.dispose();
    await _authStateController.close();
    _eventBus.dispose();
    logDebug('AuthyraClient disposed');
  }

  // ---------------------------------------------------------------------------
  // Provider management
  // ---------------------------------------------------------------------------

  /// Dynamically registers an additional [provider] after construction.
  ///
  /// Useful for lazy-loading providers (e.g., only registering an OAuth
  /// provider when the user taps "Sign in with X").
  ///
  /// Throws [InvalidProviderConfigException] if [provider.id] is empty.
  /// Throws [ProviderAlreadyRegisteredException] if the id is already in use.
  void registerProvider(AuthProvider provider) {
    if (provider.id.isEmpty) {
      throw InvalidProviderConfigException(
          provider.id, 'Provider id cannot be empty');
    }
    if (_providerMap.containsKey(provider.id)) {
      throw ProviderAlreadyRegisteredException(provider.id);
    }
    _providerMap[provider.id] = provider;
    logInfo('Provider "${provider.id}" registered dynamically');
  }

  // ---------------------------------------------------------------------------
  // Events
  // ---------------------------------------------------------------------------

  /// Scoped event bus for this client instance.
  ///
  /// Subscribe to auth events without global state leakage:
  ///
  /// ```dart
  /// client.events.on<SignInEvent>((e) => print('Signed in: ${e.user.id}'));
  /// client.events.on<TokenRefreshEvent>((e) => print('Refreshed: ${e.success}'));
  /// ```
  AuthEventBus get events => _eventBus;

  // ---------------------------------------------------------------------------
  // Authentication
  // ---------------------------------------------------------------------------

  /// Signs in using the provider identified by [providerId].
  ///
  /// [params] is forwarded verbatim to [AuthProvider.signIn]. Pass the
  /// appropriate [AuthSignInParams] subclass for the target provider:
  /// [CredentialsSignInParams], [OAuth2SignInParams], etc.
  ///
  /// When the user already has an active session, the profile is updated and
  /// the account is activated; no duplicate session is created.
  ///
  /// Returns the authenticated [AuthUser] on success.
  ///
  /// Throws [ProviderNotFoundException] if [providerId] is not registered.
  /// Throws [AuthenticationFailedException] if the provider rejects the sign-in.
  ///
  /// ```dart
  /// final user = await client.signIn('email', params: CredentialsSignInParams(
  ///   email: 'alice@example.com',
  ///   password: 's3cr3t',
  /// ));
  /// ```
  Future<AuthUser> signIn(
    String providerId, {
    AuthSignInParams? params,
  }) async {
    final startTime = DateTime.now();
    _assertInitialized();
    try {
      logInfo('Sign in started — provider: $providerId');

      if (_callbacks != null) {
        final result = await _callbacks!.onBeforeSignIn(providerId, params);
        if (result.isDenied) {
          throw AuthenticationFailedException(
            result.errorMessage ?? 'Sign in denied by callback',
            providerName: providerId,
          );
        }
      }

      await _notifyPluginsBeforeSignIn(providerId, params);

      final provider = _findProvider(providerId);
      final result = await provider.signIn(params: params);

      if (result == null) {
        throw AuthenticationFailedException(
          'Provider "$providerId" returned null — credentials may be invalid',
          providerName: providerId,
        );
      }

      final user = result.user;

      // If the user already has a session, update it and switch to it.
      final existingSession = await _sessionManager.getSession(user.id);
      final isNewUser = existingSession == null;

      if (_callbacks != null) {
        final cbResult =
            await _callbacks!.onBeforeSessionCreate(user, providerId);
        if (cbResult.isDenied) {
          throw AuthenticationFailedException(
            cbResult.errorMessage ?? 'Session creation denied by callback',
            providerName: providerId,
          );
        }
      }

      if (existingSession != null) {
        logInfo('Existing session found for ${user.id} — refreshing');
        await _refreshExistingSession(user, result, providerId);

        final activatedSession = _sessionManager.activeSession;
        if (activatedSession != null) {
          await _notifyPluginsAfterSignIn(activatedSession);
        }

        final duration = DateTime.now().difference(startTime);
        _eventBus.emit(SignInEvent(
          user: user,
          providerName: providerId,
          isNewUser: false,
          duration: duration,
        ));

        return user;
      }

      final now = DateTime.now();
      final account = result.account ??
          AuthAccount(
            id: '${providerId}_${user.id}',
            userId: user.id,
            providerId: providerId,
            providerAccountId: user.id,
            accessToken: result.accessToken,
            refreshToken: result.refreshToken,
            tokenExpiresAt: result.expiresAt ?? now.add(config.tokenLifetimeDuration),
          );

      final session = AuthSession(
        user: user,
        activeAccountId: account.id,
        linkedAccounts: [account],
        createdAt: now,
        lastUsedAt: now,
      );

      await _sessionManager.saveSession(session, setAsActive: true);
      await _notifyPluginsAfterSignIn(session);

      _eventBus.emit(SessionCreatedEvent(
        session: session,
        isNewUser: isNewUser,
      ));

      logInfo('Sign in successful — user: ${user.id}');
      _emitAuthState(AuthState.authenticated(user));

      final duration = DateTime.now().difference(startTime);
      _eventBus.emit(SignInEvent(
        user: user,
        providerName: providerId,
        isNewUser: isNewUser,
        duration: duration,
      ));

      return user;
    } on AuthException catch (e) {
      logError('Sign in failed', e);
      _emitAuthState(AuthState.error(e.message));

      _eventBus.emit(SignInFailedEvent(
        providerName: providerId,
        errorMessage: e.message,
        errorCode: e.code,
      ));
      rethrow;
    } catch (e, stackTrace) {
      logError('Sign in failed unexpectedly', e, stackTrace);
      _emitAuthState(AuthState.error(e.toString()));

      _eventBus.emit(SignInFailedEvent(
        providerName: providerId,
        errorMessage: e.toString(),
      ));

      throw AuthyraErrorHandler.handleError(e, stackTrace);
    }
  }

  /// Signs out the currently active account.
  ///
  /// If other accounts are registered, the most recently used one is
  /// automatically elected as active. If no accounts remain, the state
  /// transitions to [AuthState.unauthenticated].
  ///
  /// When the active provider has [AuthProvider.supportsSignOut] `true`,
  /// [AuthProvider.signOut] is called first to revoke server-side tokens.
  /// A failure there is logged but does NOT block the local sign-out.
  ///
  /// Throws [SessionOperationException] on local storage failure.
  Future<void> signOut() async {
    _assertInitialized();
    try {
      logInfo('Sign out started');
      final session = _sessionManager.activeSession;
      if (session == null) {
        logDebug('No active session — sign out is a no-op');
        return;
      }

      if (_callbacks != null) {
        final result = await _callbacks!.onBeforeSignOut(session.user);
        if (result.isDenied) {
          throw AuthenticationFailedException(
            result.errorMessage ?? 'Sign out denied by callback',
            providerName: session.providerId,
          );
        }
      }

      final sessionDuration = DateTime.now().difference(session.createdAt);

      // Attempt server-side token revocation.
      final provider = _providerMap[session.providerId];
      if (provider != null && provider.supportsSignOut) {
        try {
          await provider.signOut(userId: session.user.id);
        } catch (e) {
          logWarning(
            'Provider sign-out failed for "${session.providerId}" — '
            'continuing with local session removal',
          );
        }
      }

      await _sessionManager.clearActiveSession();
      logInfo('Signed out — user: ${session.user.id}');

      _eventBus.emit(SignOutEvent(
        user: session.user,
        sessionDuration: sessionDuration,
      ));

      final next = _sessionManager.activeSession;
      _emitAuthState(
          next != null
              ? AuthState.authenticated(next.user)
              : AuthState.unauthenticated());
    } catch (e, stackTrace) {
      logError('Sign out failed', e, stackTrace);
      throw AuthyraErrorHandler.handleError(e, stackTrace);
    }
  }

  /// Silently refreshes the active session's access token.
  ///
  /// Delegates to [SessionManager.refreshActiveSession], which invokes the
  /// [TokenRefresher] with the configured retry policy. On success the session
  /// is updated and [TokenRefreshEvent] is emitted. On failure the session is
  /// cleared and [SessionExpiredEvent] + [AuthState.unauthenticated] are emitted.
  ///
  /// Returns `true` when the refresh succeeded, `false` when the provider
  /// does not support refresh or no refresh token is available.
  ///
  /// Throws [SessionNotFoundException] when there is no active session.
  Future<bool> refreshSession() async {
    _assertInitialized();
    try {
      final session = _sessionManager.activeSession;
      if (session == null) throw SessionNotFoundException();

      final provider = _findProvider(session.providerId);
      if (!provider.supportsRefresh) {
        logDebug('Provider "${session.providerId}" does not support refresh');
        return false;
      }
      if (!session.canRefresh) {
        logWarning('No refresh token for user: ${session.user.id}');
        return false;
      }

      logInfo('Manual refresh requested — user: ${session.user.id}');
      return await _sessionManager.refreshActiveSession();
    } on AuthException {
      rethrow;
    } catch (e, stackTrace) {
      logError('Session refresh failed', e, stackTrace);
      throw AuthyraErrorHandler.handleError(e, stackTrace);
    }
  }

  // ---------------------------------------------------------------------------
  // Session accessors
  // ---------------------------------------------------------------------------

  /// Returns the currently active [AuthUser], or `null` if not signed in.
  Future<AuthUser?> getUser() async => (await getSession())?.user;

  /// Returns the currently active [AuthSession], or `null`.
  ///
  /// When [AuthConfig.autoRefresh] is `true` and the session is expiring soon
  /// (within [AuthConfig.refreshThreshold]), the token is refreshed silently
  /// before returning. If the refresh fails (provider error, no refresh token),
  /// the session is cleared, [SessionExpiredEvent] is emitted, and `null` is
  /// returned.
  ///
  /// When `autoRefresh` is `false` and the session is expired, `null` is
  /// returned and callers should prompt re-authentication.
  Future<AuthSession?> getSession() async {
    final rawSession = _sessionManager.activeSession;
    if (rawSession == null) return null;

    if (config.autoRefresh &&
        rawSession.shouldRefresh(threshold: config.refreshThreshold)) {
      logInfo(
          'Session expiring soon — refreshing for user: ${rawSession.user.id}');
      final succeeded = await _sessionManager.refreshActiveSession();
      if (!succeeded) return null;
      final refreshedSession = _sessionManager.activeSession;
      if (refreshedSession == null || refreshedSession.isExpired) return null;
      return refreshedSession;
    }

    if (rawSession.isExpired) {
      logWarning(
          'Session expired, autoRefresh disabled — user: ${rawSession.user.id}');
      return null;
    }

    return rawSession;
  }

  /// Returns the active access token, or `null`.
  Future<String?> getAccessToken() async => (await getSession())?.accessToken;

  /// Returns `true` when there is an active, non-expired session.
  Future<bool> isAuthenticated() async {
    try {
      final session = await getSession();
      return session != null;
    } catch (_) {
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Streams
  // ---------------------------------------------------------------------------

  /// Broadcast stream of raw [AuthSession] changes.
  ///
  /// Emits `null` when no account is active. Prefer [authStateStream] for
  /// reactive UI consumption.
  Stream<AuthSession?> get sessionStream => _sessionManager.sessionStream;

  /// Broadcast stream of [AuthState] changes.
  ///
  /// Because [AuthState] extends [Equatable], identical consecutive states are
  /// deduplicated; no spurious rebuilds.
  ///
  /// ```dart
  /// client.authStateStream.listen((state) {
  ///   switch (state.type) {
  ///     case AuthStateType.authenticated:   showDashboard(state.user!);
  ///     case AuthStateType.unauthenticated: showLoginPage();
  ///     case AuthStateType.error:           showError(state.error!);
  ///   }
  /// });
  /// ```
  Stream<AuthState> get authStateStream => _authStateController.stream;

  // ---------------------------------------------------------------------------
  // Multi-account
  // ---------------------------------------------------------------------------

  /// Multi-account management API; lazily initialised on first access.
  ///
  /// ```dart
  /// final users = await client.accounts.getAll();
  /// await client.accounts.switchTo(userId);
  /// await client.accounts.signOut(userId);
  /// await client.accounts.signOutAll();
  /// ```
  AccountManager get accounts {
    return _accountManager ??= AccountManager(
      sessionManager: _sessionManager,
      onStateChange: _emitAuthState,
    );
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Updates and activates an existing session after a repeated sign-in.
  Future<void> _refreshExistingSession(
    AuthUser user,
    AuthSignInResult result,
    String providerId,
  ) async {
    final existing = await _sessionManager.getSession(user.id);
    if (existing == null) return;

    // Update the active account's tokens if the provider returned new ones.
    AuthSession updated = existing.copyWith(user: user);
    final activeAcc = existing.activeAccount;
    if (activeAcc != null) {
      final updatedAcc = activeAcc.copyWith(
        accessToken: result.accessToken ?? activeAcc.accessToken,
        refreshToken: result.refreshToken ?? activeAcc.refreshToken,
        tokenExpiresAt: result.expiresAt ?? activeAcc.tokenExpiresAt,
      );
      updated = updated.copyWith(
        linkedAccounts: existing.linkedAccounts
            .map((a) => a.id == activeAcc.id ? updatedAcc : a)
            .toList(),
      );
    }

    await _sessionManager.updateSession(user.id, updated);
    await _sessionManager.switchAccount(user.id);
    _emitAuthState(AuthState.authenticated(user));
    logInfo('Existing session updated and activated: ${user.id}');
  }

  /// Returns the provider for [id] or throws [ProviderNotFoundException].
  AuthProvider _findProvider(String id) {
    final provider = _providerMap[id];
    if (provider == null) throw ProviderNotFoundException(id);
    return provider;
  }

  /// Maps raw [SessionManager] callbacks to [AuthState] emissions.
  void _onSessionChanged(AuthSession? session) {
    if (session != null) {
      _emitAuthState(AuthState.authenticated(session.user));
    } else if (_sessionManager.accountCount == 0) {
      _emitAuthState(AuthState.unauthenticated());
    }
  }

  void _emitAuthState(AuthState state) {
    if (!_authStateController.isClosed) {
      _authStateController.add(state);
    }
  }

  void _assertInitialized() {
    if (!_initialized) throw NotInitializedException();
  }

  // ---------------------------------------------------------------------------
  // Plugin notification helpers
  // ---------------------------------------------------------------------------

  Future<void> _notifyPluginsBeforeSignIn(
    String providerId,
    AuthSignInParams? params,
  ) async {
    for (final plugin in plugins) {
      try {
        await plugin.onBeforeSignIn(providerId, params);
      } catch (e, st) {
        logError('Plugin "${plugin.name}" threw in onBeforeSignIn', e, st);
      }
    }
  }

  Future<void> _notifyPluginsAfterSignIn(AuthSession session) async {
    for (final plugin in plugins) {
      try {
        await plugin.onAfterSignIn(session);
      } catch (e, st) {
        logError('Plugin "${plugin.name}" threw in onAfterSignIn', e, st);
      }
    }
  }

  Future<void> _notifyPluginsSessionExpired(AuthSession session) async {
    for (final plugin in plugins) {
      try {
        await plugin.onSessionExpired(session);
      } catch (e, st) {
        logError('Plugin "${plugin.name}" threw in onSessionExpired', e, st);
      }
    }
  }
}

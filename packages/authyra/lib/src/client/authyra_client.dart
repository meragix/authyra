import 'dart:async';

import 'package:authyra/src/exceptions/auth_exceptions.dart';
import 'package:authyra/src/internal/logger.dart';
import 'package:authyra/src/session/account_manager.dart';
import 'package:authyra/src/session/session_manager.dart';
import 'package:authyra/src/internal/validators.dart';
import 'package:authyra/src/models/auth_config.dart';
import 'package:authyra/src/models/auth_session.dart';
import 'package:authyra/src/models/auth_state.dart';
import 'package:authyra/src/models/auth_user.dart';
import 'package:authyra/src/interfaces/auth_provider.dart';
import 'package:authyra/src/interfaces/auth_storage.dart';

/// Stateless authentication orchestrator — the core of the Authyra framework.
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
///         final res = await myApi.post('/login', body: creds);
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
/// final user = await client.signIn('email', params: {
///   'email': 'alice@example.com',
///   'password': 's3cr3t',
/// });
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

  // Internal provider registry (id → provider).
  final Map<String, AuthProvider> _providerMap = {};

  // Session management layer (created internally).
  late final SessionManager _sessionManager;

  // Lazy-initialised multi-account facade.
  AccountManager? _accountManager;

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
    this.config = const AuthConfig(),
  }) {
    for (final provider in providers) {
      if (_providerMap.containsKey(provider.id)) {
        throw ProviderAlreadyRegisteredException(provider.id);
      }
      _providerMap[provider.id] = provider;
    }

    _sessionManager = SessionManager(
      storage: storage,
      autoRefresh: config.autoRefresh,
    );
    _sessionManager.addListener(_onSessionChanged);
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
  // Authentication
  // ---------------------------------------------------------------------------

  /// Signs in using the provider identified by [providerId].
  ///
  /// [params] is forwarded verbatim to [AuthProvider.signIn]. Expected keys
  /// depend on the provider type — see [AuthProvider.signIn] for the full
  /// table.
  ///
  /// When the user already has an active session, the profile is updated and
  /// the account is activated — no duplicate session is created.
  ///
  /// Returns the authenticated [AuthUser] on success.
  ///
  /// Throws [ProviderNotFoundException] if [providerId] is not registered.
  /// Throws [AuthenticationFailedException] if the provider rejects the sign-in.
  ///
  /// ```dart
  /// final user = await client.signIn('email', params: {
  ///   'email': 'alice@example.com',
  ///   'password': 's3cr3t',
  /// });
  /// ```
  Future<AuthUser> signIn(
    String providerId, {
    Map<String, dynamic>? params,
  }) async {
    _assertInitialized();
    try {
      logInfo('Sign in started — provider: $providerId');
      final provider = _findProvider(providerId);

      AuthValidators.validateSignInParams(providerId, params);

      final result = await provider.signIn(params: params);
      if (result == null) {
        throw AuthenticationFailedException(
          'Provider "$providerId" returned null — credentials may be invalid',
          providerName: providerId,
        );
      }

      final user = result.user;
      AuthValidators.validateUserData(user.toJson());

      // If the user already has a session, update it and switch to it.
      final existing = await _sessionManager.getSession(user.id);
      if (existing != null) {
        logInfo('Existing session found for ${user.id} — refreshing');
        await _refreshExistingSession(user, result, providerId);
        return user;
      }

      // Create a new session from the sign-in result.
      final session = AuthSession(
        providerId: providerId,
        user: user,
        accessToken: result.accessToken,
        refreshToken: result.refreshToken,
        expiresAt: result.expiresAt ??
            DateTime.now().add(config.tokenLifetimeDuration),
        createdAt: DateTime.now(),
        lastUsedAt: DateTime.now(),
      );

      await _sessionManager.saveSession(session, setAsActive: true);
      logInfo('Sign in successful — user: ${user.id}');
      _emitAuthState(AuthState.authenticated(user));
      return user;
    } on AuthException catch (e) {
      logError('Sign in failed', e);
      _emitAuthState(AuthState.error(e.message));
      rethrow;
    } catch (e, stackTrace) {
      logError('Sign in failed unexpectedly', e, stackTrace);
      _emitAuthState(AuthState.error(e.toString()));
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
      final session = await _sessionManager.getActiveSession();
      if (session == null) {
        logDebug('No active session — sign out is a no-op');
        return;
      }

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

      final next = _sessionManager.activeSession;
      _emitAuthState(next != null
          ? AuthState.authenticated(next.user)
          : AuthState.unauthenticated());
    } catch (e, stackTrace) {
      logError('Sign out failed', e, stackTrace);
      throw AuthyraErrorHandler.handleError(e, stackTrace);
    }
  }

  /// Silently refreshes the active session's access token.
  ///
  /// Delegates to [AuthProvider.refreshToken] for the active session's
  /// provider. On success the session is updated with new tokens. On failure
  /// (expired or invalid refresh token) the session is removed and
  /// [AuthState.unauthenticated] is emitted.
  ///
  /// Returns `true` when the refresh succeeded, `false` when the provider
  /// does not support refresh or no refresh token is available.
  ///
  /// Throws [SessionNotFoundException] when there is no active session.
  Future<bool> refreshSession() async {
    _assertInitialized();
    try {
      final session = await _sessionManager.getActiveSession();
      if (session == null) throw SessionNotFoundException();

      final provider = _findProvider(session.providerId);
      if (!provider.supportsRefresh) {
        logDebug('Provider "${session.providerId}" does not support refresh');
        return false;
      }
      if (session.refreshToken == null) {
        logWarning('No refresh token for user: ${session.user.id}');
        return false;
      }

      logInfo('Refreshing session — user: ${session.user.id}');
      final result = await provider.refreshToken(session.refreshToken!);

      if (result == null) {
        logWarning(
          'Refresh returned null — forcing re-auth for user: ${session.user.id}',
        );
        await _sessionManager.clearActiveSession();
        _emitAuthState(AuthState.unauthenticated());
        return false;
      }

      final refreshed = session.refreshed(
        newAccessToken: result.accessToken,
        newRefreshToken: result.refreshToken,
        newExpiresAt: result.expiresAt,
      );

      await _sessionManager.updateSession(session.user.id, refreshed);
      logInfo('Session refreshed — user: ${session.user.id}');
      return true;
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
  /// Throws [TokenExpiredException] when the session exists but has expired.
  Future<AuthSession?> getSession() => _sessionManager.getActiveSession();

  /// Returns the active access token, or `null`.
  ///
  /// Throws [TokenExpiredException] when the session is expired.
  Future<String?> getAccessToken() => _sessionManager.getAccessToken();

  /// Returns `true` when there is an active, non-expired session.
  Future<bool> isAuthenticated() async {
    try {
      final session = await getSession();
      return session != null && !session.isExpired;
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
  /// deduplicated — no spurious rebuilds.
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

  /// Multi-account management API — lazily initialised on first access.
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

    final updated = existing.copyWith(
      user: user,
      accessToken: result.accessToken ?? existing.accessToken,
      refreshToken: result.refreshToken ?? existing.refreshToken,
      expiresAt: result.expiresAt ?? existing.expiresAt,
    );

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
}

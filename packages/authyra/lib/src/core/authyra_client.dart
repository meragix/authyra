import 'dart:async';

import 'package:authyra/authyra.dart';
import 'package:authyra/src/core/exceptions.dart';
import 'package:authyra/src/core/logger.dart';
import 'package:authyra/src/core/session/multi_account_manager.dart';
import 'package:authyra/src/core/session/session_manager.dart';
import 'package:authyra/src/core/validators.dart';
import 'package:authyra/src/models/auth_config.dart';
import 'package:authyra/src/models/auth_session.dart';
import 'package:authyra/src/providers/auth_provider.dart';

/// Authyra Authentication Client
///
/// **Responsibility**: Orchestrate the providers and storage.
///
/// This class contains all the authentication business logic,
/// but maintains NO global state. It is designed to be
/// used in any context (Flutter, backend, CLI).
///
/// ## Usage
///
/// ```dart
/// // Dart Backend
/// final client = AuthyraClient(
/// providers: [
///   CredentialsProvider(
///     id: 'email-login',
///     authorize: (creds) async {
///       final response = await myApi.post('/login', data: creds);
///
///      if (response.statusCode == 200) {
///        return AuthUser.fromMap(response.data);
///      }
///      return null;
///    },
///  ),
/// ],
/// storage: RedisAuthStorage(),
/// );
///
/// final account = await client.signInWithCredentials(
///  providerId: 'email-login',
///  credentials: {
///    'email': _emailController.text,
///    'password': _passwordController.text,
///    'rememberMe': true,
///  },
///);
// ```
///
/// ## For Flutter
///
/// Instead, use `Authyra.instance` which wraps this client
/// and adds the necessary responsiveness for Flutter.
class AuthyraClient with AuthyraLogging {
  final List<AuthProvider> providers;

  final AuthStorage storage;

  /// Configuration optionnelle
  final AuthConfig? config;

  final SessionManager sessionManager;

  final Map<String, AuthProvider> _providers = {};

  MultiAccountManager? _multiAccountManager;

  final _authStateController = StreamController<AuthState>.broadcast();

  AuthyraClient({
    required this.providers,
    required this.storage,
    required this.sessionManager,
    this.config,
  }) {
    sessionManager.addListener(_onSessionChanged);
  }

  Future<AuthUser?> signIn(
    String provider, {
    Map<String, dynamic>? params,
  }) async {
    //final startTime = DateTime.now();

    try {
      logInfo('Starting sign in with provider: $provider');

      //final provider = _providers[providerName];
      final authProvider = providers.firstWhere((p) => p.id == provider);
      if (authProvider == null) {
        throw ProviderNotFoundException(provider);
      }

      // Validate sign-in parameters
      AuthValidators.validateSignInParams(provider, params);

      // Attempt sign in with provider
      logDebug('Calling provider sign in...');
      final user = await authProvider.signIn(data: params);

      if (user == null) user;

      // Validate user data
      AuthValidators.validateUserData(user!.toJson());

      // Check for duplicate account
      final existingSession = await sessionManager.getSession(user.id);
      if (existingSession != null) {
        logWarning('User ${user.id} already has an active session');
        // Update existing session instead
        await _updateExistingSession(user, provider);
        return user;
      }

      // Create new session
      final session = AuthSession(
        providerId: provider,
        user: user,
        accessToken: params?['accessToken'] as String? ?? '',
        refreshToken: params?['refreshToken'] as String?,
        // expiresAt: DateTime.now().add(
        //   config.tokenRefreshThreshold * 12, // ~1 hour default
        // ),
        lastUsedAt: DateTime.now(),
        createdAt: DateTime.now(),
      );

      logDebug('Saving session...');
      await sessionManager.saveSession(session, setAsActive: true);

      logInfo('Sign in successful for user: ${user.id}');
      _emitAuthState(AuthState.authenticated(user));

      return user;
    } on AuthyraException catch (e) {
      logError('Sign in failed', e);
      rethrow;
    } catch (e, stackTrace) {
      logError('Sign in failed', e, stackTrace);
      _emitAuthState(AuthState.error(e.toString()));
      throw AuthyraErrorHandler.handleError(e, stackTrace);
    }
  }

  /// The client must expose a specific method for credentials,
  /// because unlike OAuth, the data comes from the UI (the form).
  Future<AuthUser?> signInWithCredentials({
    required String providerId,
    required Map<String, dynamic> credentials,
  }) async {
    // 1. Trouver le provider
    final provider = _providers[providerId];
    if (provider == null) {
      throw ProviderNotFoundException(providerId);
    }

    // 2. Appeler la logique d'autorisation
    final user = await provider.signIn(data: credentials);

    if (user != null) {
      // Check for duplicate account
      final existingSession = await sessionManager.getSession(user.id);
      if (existingSession != null) {
        logWarning('User ${user.id} already has an active session');
        // Update existing session instead
        await _updateExistingSession(user, providerId);
        return user;
      }

      // Create new session
      final session = AuthSession(
        providerId: providerId,
        user: user,
        accessToken: '',
        lastUsedAt: DateTime.now(),
        createdAt: DateTime.now(),
      );

      logDebug('Saving session...');
      await sessionManager.saveSession(session, setAsActive: true);

      logInfo('Sign in successful for user: ${user.id}');
      _emitAuthState(AuthState.authenticated(user));
    }

    return user;
  }

  Future<void> signOut() async {
    try {
      logInfo('Signing out...');
      throw UnimplementedError();
    } catch (e, stackTrace) {
      logError('Sign in failed', e, stackTrace);

      throw AuthyraErrorHandler.handleError(e, stackTrace);
    }
  }

  Future<AuthUser?> refreshToken(String refreshToken) {
    throw UnimplementedError();
  }

  /// Validate a JWT token
  ///
  /// Useful for backend middleware
  Future<AuthUser?> validateToken(String token) async {
    /// Decode and verify the token
    /// Return the associated account if valid
    // TODO: Implement with jwt_decoder
    throw UnimplementedError('validateToken not implemented yet');
  }

  // ==========================================
  // Internal Methods
  // ==========================================

  Future<void> _updateExistingSession(
    AuthUser user,
    String providerName,
  ) async {
    final existingSession = await sessionManager.getSession(user.id);
    if (existingSession == null) return;

    final updatedSession = existingSession.copyWith(user: user);
    await sessionManager.updateSession(user.id, updatedSession);
    await sessionManager.switchAccount(user.id);

    logInfo('Updated and switched to existing session: ${user.id}');
  }

  void _onSessionChanged(AuthSession? session) {
    if (session != null) {
      _emitAuthState(AuthState.authenticated(session.user));
    } else if (sessionManager.accountCount == 0) {
      _emitAuthState(AuthState.unauthenticated());
    }
  }

  void _emitAuthState(AuthState state) {
    if (!_authStateController.isClosed) {
      _authStateController.add(state);
    }
  }

  AuthProvider _findProvider(String providerId) {
    try {
      return providers.firstWhere((p) => p.id == providerId);
    } catch (e) {
      throw ProviderNotFoundException(providerId);
    }
  }

  Future<void> dispose() async {
    await sessionManager.dispose();
    await _authStateController.close();
    logDebug('Authyra disposed');
  }
}

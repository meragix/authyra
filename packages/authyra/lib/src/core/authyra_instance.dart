import 'package:authyra/src/core/authyra_client.dart';
import 'package:authyra/src/core/logger.dart';
import 'package:authyra/src/models/auth_session.dart';

/// Authyra Singleton Instance
///
/// **Responsibility**: Reactive wrapper around [AuthyraClient].
///
/// This class adds:
/// - Global access via singleton
/// - Reactive state (Stream, Listenable)
/// - In-memory cache
/// - Simplified API for Flutter
///
/// ## Usage
///
/// ```dart
/// // Configuration (once at startup)
/// void main() async {
///   Authyra.instance.initialize(
///     AuthyraClient(
///     providers: [EmailAuthProvider()],
///     storage: SecureAuthStorage(),
///   ),
/// );
///
///  runApp(MyApp());
/// }
///
/// // Usage in the app
/// final isAuth = Authyra.instance.isAuthenticated;
/// final account = Authyra.instance.currentAccount;
///
/// // Listen for changes
/// Authyra.instance.onAccountChanged.listen((account) {
/// print('Auth changed: ${account?.email}');
/// });
// ```
class AuthyraInstance {
  static AuthyraInstance? _instance;
  static AuthyraInstance get instance => _instance ??= AuthyraInstance._();

  AuthyraInstance._();

  AuthyraClient? _client;

  AuthSession? _currentSession;
  bool _isInitialized = false;

  /// L'unique point d'entrée pour démarrer Authyra
  Future<void> initialize({required AuthyraClient client}) async {
    if (_isInitialized) return;

    _client = client;

    try {
      // 1. Restaurer la session
      //_currentAccount = await _client!.restoreSession();

      // 2. Écouter les changements internes du client (multi-compte, logout, etc.)
      // _client!.onAccountChanged.listen((account) {
      //   _currentAccount = account;
      //   _accountController.add(account);
      //   // Ici, notifie ton Notifier Flutter (ChangeNotifier)
      // });

      //_accountController.add(_currentAccount);
    } catch (e) {
      AuthyraLogger.error('Initialization failed', e);
      // _currentAccount = null;
    } finally {
      // _isInitialized = true;
    }
  }

  /// Connexion avec un provider
  Future<AuthSession?> signIn({
    required String provider,
    required Map<String, dynamic> credentials,
  }) async {
    try {
      // _currentAccount = await client.signIn(
      //   provider: provider,
      //   credentials: credentials,
      // );

      // _accountController.add(_currentAccount);
      // _notifier._notify();

      return _currentSession;
    } catch (e) {
      rethrow;
    }
  }

  /// Déconnexion
  Future<void> signOut() async {
    try {
      // await client.signOut();

      //  _currentAccount = null;
      // _accountController.add(null);
      //_notifier._notify();
    } catch (e) {
      rethrow;
    }
  }

  /// Helper pour accéder au client sans forcer le null-check partout
  AuthyraClient get client {
    if (!_isInitialized) throw StateError('Authyra must be initialized first.');
    return _client!;
  }
}

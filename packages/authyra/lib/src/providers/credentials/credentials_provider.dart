import 'package:authyra/src/core/logger.dart';
import 'package:authyra/src/models/auth_user.dart';
import 'package:authyra/src/providers/auth_provider.dart';

typedef AuthorizeCallback = Future<AuthUser?> Function(Map<String, dynamic>? credentials);

class CredentialsProvider with AuthyraLogging implements AuthProvider {
  final String _id;
  final AuthorizeCallback authorize;

  CredentialsProvider({
    required String id,
    required this.authorize,
  }) : _id = id;

  @override
  String get id => _id;

  @override
  bool get supportsRefresh => true;

  @override
  Future<AuthUser?> signIn({Map<String, dynamic>? data}) async {
    try {
      AuthyraLogger.info('Tentative de connexion via CredentialsProvider[$id]');

      final account = await authorize(data);

      if (account == null) {
        AuthyraLogger.warning('Échec de connexion : Authorize a retourné null');
        return null;
      }

      return account;
    } catch (e, stack) {
      AuthyraLogger.error('Erreur lors de l\'autorisation Credentials', e, stack);
      rethrow;
    }
  }

  @override
  Future<void> signOut() async {
    logDebug('Sign out called for ${id}');
    // Backend should handle session invalidation
  }

  @override
  Future<AuthUser?> refreshToken(String freshToken) {
    logDebug('Refreshing token via backend');
    throw UnimplementedError();
  }

  // ==========================================
  // Private Methods
  // ==========================================
}

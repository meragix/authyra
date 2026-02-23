import 'package:authyra/src/core/logger.dart';
import 'package:authyra/src/models/auth_user.dart';
import 'package:authyra/src/providers/auth_provider.dart';

/// Callback that validates credentials and returns the authenticated user.
///
/// Return `null` when credentials are invalid; throw for infrastructure errors.
///
/// For backends that also return tokens, use [AuthorizeWithTokensCallback]
/// and [CredentialsProvider.withTokens] instead.
///
/// ```dart
/// Future<AuthUser?> myAuthorize(Map<String, dynamic>? creds) async {
///   final res = await myApi.post('/auth/login', body: creds);
///   if (res.statusCode != 200) return null;
///   return AuthUser(id: res.data['id'], email: res.data['email']);
/// }
/// ```
typedef AuthorizeCallback = Future<AuthUser?> Function(
  Map<String, dynamic>? credentials,
);

/// Extended callback that returns the full [AuthSignInResult] with tokens.
///
/// Use when your backend returns access/refresh tokens in the sign-in response.
///
/// ```dart
/// Future<AuthSignInResult?> myAuthorize(Map<String, dynamic>? creds) async {
///   final res = await myApi.post('/auth/login', body: creds);
///   if (res.statusCode != 200) return null;
///   return AuthSignInResult(
///     user: AuthUser(id: res.data['id'], email: res.data['email']),
///     accessToken: res.data['accessToken'],
///     refreshToken: res.data['refreshToken'],
///     expiresAt: DateTime.parse(res.data['expiresAt']),
///   );
/// }
/// ```
typedef AuthorizeWithTokensCallback = Future<AuthSignInResult?> Function(
  Map<String, dynamic>? credentials,
);

/// Authentication provider for email + password (or any custom credentials).
///
/// Delegates credential validation to a callback supplied at construction —
/// you own the logic and connect it to any backend.
///
/// ## Basic usage (user profile only)
///
/// ```dart
/// CredentialsProvider(
///   id: 'email',
///   authorize: (creds) async {
///     final res = await myApi.post('/login', body: creds);
///     if (res.statusCode != 200) return null;
///     return AuthUser(id: res.data['id'], email: res.data['email']);
///   },
/// )
/// ```
///
/// ## With tokens (recommended for JWT backends)
///
/// ```dart
/// CredentialsProvider.withTokens(
///   id: 'email',
///   authorize: (creds) async {
///     final res = await myApi.post('/login', body: creds);
///     if (res.statusCode != 200) return null;
///     return AuthSignInResult(
///       user: AuthUser(id: res.data['userId']),
///       accessToken: res.data['accessToken'],
///       refreshToken: res.data['refreshToken'],
///       expiresAt: DateTime.parse(res.data['expiresAt']),
///     );
///   },
/// )
/// ```
///
/// See also:
/// - [AuthProvider], the base interface.
/// - [OAuth2Provider], for social / OIDC flows.
class CredentialsProvider with AuthyraLogging implements AuthProvider {
  final String _id;
  final AuthorizeCallback? _authorize;
  final AuthorizeWithTokensCallback? _authorizeWithTokens;

  /// Creates a [CredentialsProvider] with a simple [AuthorizeCallback].
  ///
  /// Prefer [CredentialsProvider.withTokens] when your backend also returns
  /// tokens in the sign-in response.
  CredentialsProvider({
    required String id,
    required AuthorizeCallback authorize,
  })  : _id = id,
        _authorize = authorize,
        _authorizeWithTokens = null;

  /// Creates a [CredentialsProvider] with a token-aware callback.
  ///
  /// Use this when your backend returns access and refresh tokens in the
  /// login response — ensures Authyra stores them in the session.
  CredentialsProvider.withTokens({
    required String id,
    required AuthorizeWithTokensCallback authorize,
  })  : _id = id,
        _authorizeWithTokens = authorize,
        _authorize = null;

  @override
  String get id => _id;

  @override
  String get name => 'Credentials';

  @override
  AuthProviderType get type => AuthProviderType.credentials;

  @override
  bool get supportsRefresh => false;

  @override
  bool get supportsSignOut => false;

  @override
  Future<AuthSignInResult?> signIn({Map<String, dynamic>? params}) async {
    try {
      logInfo('Sign in via CredentialsProvider[$id]');

      final authorizeWithTokens = _authorizeWithTokens;
      if (authorizeWithTokens != null) {
        final result = await authorizeWithTokens(params);
        if (result == null) logWarning('Authorization returned null for provider: $id');
        return result;
      }

      final user = await _authorize!(params);
      if (user == null) {
        logWarning('Authorization returned null for provider: $id');
        return null;
      }

      return AuthSignInResult.userOnly(user);
    } catch (e, stackTrace) {
      logError('Authorization error in CredentialsProvider[$id]', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> signOut({String? userId}) async {
    logDebug('signOut — no-op (session invalidation handled by the backend)');
  }

  @override
  Future<AuthTokenResult?> refreshToken(String refreshToken) async => null;
}

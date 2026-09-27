import 'package:authyra_flutter/authyra_flutter.dart';

/// A fake backend so anyone can try the demo in two clicks, no OAuth client
/// ID or real server required. Any email works; the password must be
/// [demoPassword].
///
/// Unlike [CredentialsProvider], this implements [AuthProvider] directly so
/// it can set `supportsRefresh: true` and actually participate in Authyra's
/// background token refresh, the dashboard's "force refresh" and the
/// automatic refresh you'll see fire on its own are both real Authyra
/// behaviour, only the "server" behind [signIn]/[refreshToken] is mocked.
class DemoAuthProvider implements AuthProvider {
  static const demoPassword = 'demo';
  static const defaultEmail = 'demo@authyra.dev';

  int refreshCount = 0;

  @override
  String get id => 'demo';

  @override
  String get name => 'Demo account';

  @override
  bool get supportsRefresh => true;

  @override
  bool get supportsSignOut => false;

  @override
  Future<AuthSignInResult?> signIn({AuthSignInParams? params}) async {
    final creds = params is CredentialsSignInParams ? params : null;
    final email = creds?.email.trim();
    final password = creds?.password;

    await Future.delayed(
      const Duration(milliseconds: 350),
    ); // feel like a real call

    if (email == null || email.isEmpty) return null;
    if (password != demoPassword) return null;

    final now = DateTime.now();
    return AuthSignInResult(
      user: AuthUser(id: email, email: email, name: _displayName(email)),
      accessToken: _token('access'),
      refreshToken: _token('refresh'),
      // Short-lived on purpose: within a minute or two you'll see the
      // background TokenRefresher renew it on its own.
      expiresAt: now.add(const Duration(seconds: 60)),
    );
  }

  @override
  Future<void> signOut({String? userId}) async {}

  @override
  Future<AuthTokenResult?> refreshToken(String refreshToken) async {
    await Future.delayed(const Duration(milliseconds: 300));
    refreshCount++;
    return AuthTokenResult(
      accessToken: _token('access'),
      expiresAt: DateTime.now().add(const Duration(seconds: 60)),
    );
  }

  String _token(String kind) =>
      'demo-$kind-${DateTime.now().microsecondsSinceEpoch}';

  String _displayName(String email) {
    final local = email.split('@').first;
    if (local.isEmpty) return email;
    return local[0].toUpperCase() + local.substring(1);
  }
}

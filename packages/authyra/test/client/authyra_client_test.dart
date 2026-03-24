import 'dart:async';

import 'package:authyra/src/models/auth_sign_in_result.dart';
import 'package:authyra/src/models/auth_token_result.dart';
import 'package:test/test.dart';
import 'package:authyra/src/client/authyra_client.dart';
import 'package:authyra/src/interfaces/auth_provider.dart';
import 'package:authyra/src/interfaces/auth_sign_in_params.dart';
import 'package:authyra/src/models/auth_config.dart';
import 'package:authyra/src/models/auth_state.dart';
import 'package:authyra/src/models/auth_user.dart';
import 'package:authyra/src/storage/memory_storage.dart';
import 'package:authyra/src/exceptions/auth_exceptions.dart';
import 'package:authyra/src/events/auth_events.dart';

// ---------------------------------------------------------------------------
// Fake providers
// ---------------------------------------------------------------------------

class _FakeProvider implements AuthProvider {
  AuthUser? returnUser;
  final String? returnAccessToken;
  final String? returnRefreshToken;
  final DateTime? returnExpiresAt;
  final bool throwOnSignIn;
  int signInCallCount = 0;
  int refreshCallCount = 0;

  _FakeProvider({
    this.returnUser,
    this.returnAccessToken,
    this.returnRefreshToken,
    this.returnExpiresAt,
    this.throwOnSignIn = false,
  });

  @override
  String get id => 'fake';

  @override
  String get name => 'Fake';

  @override
  AuthProviderType get type => AuthProviderType.custom;

  @override
  bool get supportsRefresh => returnRefreshToken != null;

  @override
  bool get supportsSignOut => false;

  @override
  Future<AuthSignInResult?> signIn({AuthSignInParams? params}) async {
    signInCallCount++;
    if (throwOnSignIn) throw Exception('provider error');
    if (returnUser == null) return null;
    return AuthSignInResult(
      user: returnUser!,
      accessToken: returnAccessToken,
      refreshToken: returnRefreshToken,
      expiresAt: returnExpiresAt,
    );
  }

  @override
  Future<AuthTokenResult?> refreshToken(String refreshToken) async {
    refreshCallCount++;
    if (returnRefreshToken == null) return null;
    return AuthTokenResult(
      accessToken: 'refreshed_token',
      refreshToken: returnRefreshToken,
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
    );
  }

  @override
  Future<void> signOut({String? userId}) async {}
}

class _SignOutProvider implements AuthProvider {
  bool signOutCalled = false;

  @override
  String get id => 'signout';

  @override
  String get name => 'SignOut';

  @override
  AuthProviderType get type => AuthProviderType.custom;

  @override
  bool get supportsRefresh => false;

  @override
  bool get supportsSignOut => true;

  @override
  Future<AuthSignInResult?> signIn({AuthSignInParams? params}) async {
    return AuthSignInResult(
      user: AuthUser(id: 'usr_so', email: 'so@test.com'),
      accessToken: 'tok',
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
    );
  }

  @override
  Future<void> signOut({String? userId}) async {
    signOutCalled = true;
  }

  @override
  Future<AuthTokenResult?> refreshToken(String token) async => null;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

AuthyraClient _client(
  AuthProvider provider, {
  AuthConfig config = const AuthConfig(),
}) {
  return AuthyraClient(
    providers: [provider],
    storage: InMemoryStorage(),
    config: config,
  );
}

void main() {
  group('AuthyraClient', () {
    group('initialization', () {
      test('signIn before initialize throws NotInitializedException', () async {
        final client = _client(_FakeProvider(
          returnUser: AuthUser(id: 'u1'),
        ));
        expect(
          () => client.signIn('fake'),
          throwsA(isA<NotInitializedException>()),
        );
      });

      test('initialize is idempotent', () async {
        final client = _client(_FakeProvider(returnUser: AuthUser(id: 'u1')));
        await client.initialize();
        await client.initialize(); // second call is no-op
        await client.dispose();
      });

      test('duplicate provider id throws ProviderAlreadyRegisteredException', () {
        final p1 = _FakeProvider(returnUser: AuthUser(id: 'u1'));
        expect(
          () => AuthyraClient(
            providers: [p1, p1],
            storage: InMemoryStorage(),
          ),
          throwsA(isA<ProviderAlreadyRegisteredException>()),
        );
      });
    });

    group('signIn', () {
      late AuthyraClient client;
      late _FakeProvider provider;

      setUp(() async {
        provider = _FakeProvider(
          returnUser: AuthUser(id: 'usr_1', email: 'alice@test.com'),
          returnAccessToken: 'at_123',
          returnExpiresAt: DateTime.now().add(const Duration(hours: 1)),
        );
        client = _client(provider);
        await client.initialize();
      });

      tearDown(() => client.dispose());

      test('returns the authenticated user', () async {
        final user = await client.signIn('fake');
        expect(user.id, 'usr_1');
        expect(user.email, 'alice@test.com');
      });

      test('session is accessible after signIn', () async {
        await client.signIn('fake');
        final session = await client.getSession();
        expect(session?.user.id, 'usr_1');
        expect(session?.accessToken, 'at_123');
      });

      test('isAuthenticated returns true after signIn', () async {
        await client.signIn('fake');
        expect(await client.isAuthenticated(), isTrue);
      });

      test('provider not found throws ProviderNotFoundException', () async {
        expect(
          () => client.signIn('unknown'),
          throwsA(isA<ProviderNotFoundException>()),
        );
      });

      test('provider returning null throws AuthenticationFailedException', () async {
        final p = _FakeProvider(returnUser: null);
        final c = _client(p);
        await c.initialize();
        expect(
          () => c.signIn('fake'),
          throwsA(isA<AuthenticationFailedException>()),
        );
        await c.dispose();
      });

      test('provider exception is wrapped in AuthException', () async {
        final p = _FakeProvider(returnUser: AuthUser(id: 'x'), throwOnSignIn: true);
        final c = _client(p);
        await c.initialize();
        expect(() => c.signIn('fake'), throwsA(isA<AuthException>()));
        await c.dispose();
      });

      test('signing in again updates existing session', () async {
        await client.signIn('fake');
        provider.returnUser = AuthUser(id: 'usr_1', email: 'updated@test.com');
        await client.signIn('fake');
        final session = await client.getSession();
        expect(session?.user.email, 'updated@test.com');
      });

      test('authStateStream emits authenticated state after signIn', () async {
        final states = <AuthState>[];
        final sub = client.authStateStream.listen(states.add);
        await client.signIn('fake');
        await Future.microtask(() {});
        sub.cancel();
        expect(states.any((s) => s.isAuthenticated), isTrue);
      });

      test('emits SignInEvent', () async {
        SignInEvent? captured;
        client.events.on<SignInEvent>((e) => captured = e);
        await client.signIn('fake');
        expect(captured, isNotNull);
        expect(captured!.user.id, 'usr_1');
      });
    });

    group('signOut', () {
      late AuthyraClient client;

      setUp(() async {
        final provider = _FakeProvider(
          returnUser: AuthUser(id: 'usr_1'),
          returnAccessToken: 'tok',
          returnExpiresAt: DateTime.now().add(const Duration(hours: 1)),
        );
        client = _client(provider);
        await client.initialize();
        await client.signIn('fake');
      });

      tearDown(() => client.dispose());

      test('clears the active session', () async {
        await client.signOut();
        expect(await client.isAuthenticated(), isFalse);
        expect(await client.getSession(), isNull);
      });

      test('signOut on no session is a no-op', () async {
        await client.signOut(); // first sign-out
        await client.signOut(); // second is no-op
        expect(await client.isAuthenticated(), isFalse);
      });

      test('emits SignOutEvent', () async {
        SignOutEvent? captured;
        client.events.on<SignOutEvent>((e) => captured = e);
        await client.signOut();
        expect(captured, isNotNull);
        expect(captured!.user.id, 'usr_1');
      });

      test('calls provider signOut when supportsSignOut=true', () async {
        final soProvider = _SignOutProvider();
        final c = AuthyraClient(
          providers: [soProvider],
          storage: InMemoryStorage(),
        );
        await c.initialize();
        await c.signIn('signout');
        await c.signOut();
        expect(soProvider.signOutCalled, isTrue);
        await c.dispose();
      });

      test('authStateStream emits unauthenticated after signOut', () async {
        final states = <AuthState>[];
        final sub = client.authStateStream.listen(states.add);
        await client.signOut();
        await Future.microtask(() {});
        sub.cancel();
        expect(states.any((s) => s.isUnauthenticated), isTrue);
      });
    });

    group('refreshSession', () {
      test('refreshes token via provider', () async {
        final now = DateTime.now();
        final provider = _FakeProvider(
          returnUser: AuthUser(id: 'usr_1'),
          returnAccessToken: 'at_old',
          returnRefreshToken: 'rt_123',
          returnExpiresAt: now.add(const Duration(hours: 1)),
        );
        final client = _client(provider);
        await client.initialize();
        await client.signIn('fake');

        final success = await client.refreshSession();
        expect(success, isTrue);
        expect(provider.refreshCallCount, 1);
        await client.dispose();
      });

      test('returns false when provider does not support refresh', () async {
        final provider = _FakeProvider(
          returnUser: AuthUser(id: 'usr_1'),
          returnAccessToken: 'at',
          returnExpiresAt: DateTime.now().add(const Duration(hours: 1)),
        );
        final client = _client(provider);
        await client.initialize();
        await client.signIn('fake');

        final success = await client.refreshSession();
        expect(success, isFalse);
        await client.dispose();
      });

      test('throws SessionNotFoundException when not signed in', () async {
        final provider = _FakeProvider(returnUser: AuthUser(id: 'usr_1'));
        final client = _client(provider);
        await client.initialize();
        expect(
          () => client.refreshSession(),
          throwsA(isA<SessionNotFoundException>()),
        );
        await client.dispose();
      });

      test('emits TokenRefreshEvent on success', () async {
        final now = DateTime.now();
        final provider = _FakeProvider(
          returnUser: AuthUser(id: 'usr_1'),
          returnAccessToken: 'at',
          returnRefreshToken: 'rt',
          returnExpiresAt: now.add(const Duration(hours: 1)),
        );
        final client = _client(provider);
        await client.initialize();
        await client.signIn('fake');

        TokenRefreshEvent? captured;
        client.events.on<TokenRefreshEvent>((e) => captured = e);
        await client.refreshSession();

        expect(captured, isNotNull);
        expect(captured!.success, isTrue);
        await client.dispose();
      });
    });

    group('auto-refresh via getSession', () {
      test('auto-refreshes when session is expiring soon', () async {
        final now = DateTime.now();
        final provider = _FakeProvider(
          returnUser: AuthUser(id: 'usr_1'),
          returnAccessToken: 'at_old',
          returnRefreshToken: 'rt_123',
          // expires in 1 minute — within default 5-minute refresh threshold
          returnExpiresAt: now.add(const Duration(minutes: 1)),
        );
        final client = AuthyraClient(
          providers: [provider],
          storage: InMemoryStorage(),
          config: const AuthConfig(autoRefresh: true),
        );
        await client.initialize();
        await client.signIn('fake');

        final session = await client.getSession();
        expect(provider.refreshCallCount, 1);
        expect(session?.accessToken, 'refreshed_token');
        await client.dispose();
      });

      test('returns null and emits SessionExpiredEvent when refresh unsupported', () async {
        final now = DateTime.now();
        // Provider with no refresh token — supportsRefresh is false
        final provider = _FakeProvider(
          returnUser: AuthUser(id: 'usr_1'),
          returnAccessToken: 'at_old',
          returnRefreshToken: null,
          returnExpiresAt: now.add(const Duration(minutes: 1)),
        );
        final client = AuthyraClient(
          providers: [provider],
          storage: InMemoryStorage(),
          config: const AuthConfig(autoRefresh: true),
        );
        await client.initialize();
        await client.signIn('fake');

        SessionExpiredEvent? expiredEvent;
        client.events.on<SessionExpiredEvent>((e) => expiredEvent = e);
        final session = await client.getSession();

        expect(session, isNull);
        expect(expiredEvent, isNotNull);
        await client.dispose();
      });

      test('no auto-refresh when autoRefresh=false', () async {
        final now = DateTime.now();
        final provider = _FakeProvider(
          returnUser: AuthUser(id: 'usr_1'),
          returnAccessToken: 'at_old',
          returnRefreshToken: 'rt_123',
          returnExpiresAt: now.add(const Duration(minutes: 1)),
        );
        final client = AuthyraClient(
          providers: [provider],
          storage: InMemoryStorage(),
          config: const AuthConfig(autoRefresh: false),
        );
        await client.initialize();
        await client.signIn('fake');

        final session = await client.getSession();
        expect(provider.refreshCallCount, 0);
        // session is not expired yet (expires in 1 minute), just expiring soon
        expect(session, isNotNull);
        await client.dispose();
      });
    });

    group('events isolation', () {
      test('two clients have independent event buses', () async {
        final p1 = _FakeProvider(
          returnUser: AuthUser(id: 'u1'),
          returnAccessToken: 'tok1',
          returnExpiresAt: DateTime.now().add(const Duration(hours: 1)),
        );
        final p2 = _FakeProvider(
          returnUser: AuthUser(id: 'u2'),
          returnAccessToken: 'tok2',
          returnExpiresAt: DateTime.now().add(const Duration(hours: 1)),
        );

        final client1 = AuthyraClient(
          providers: [p1],
          storage: InMemoryStorage(),
        );
        final client2 = AuthyraClient(
          providers: [p2],
          storage: InMemoryStorage(),
        );
        await client1.initialize();
        await client2.initialize();

        SignInEvent? captured1;
        SignInEvent? captured2;
        client1.events.on<SignInEvent>((e) => captured1 = e);
        client2.events.on<SignInEvent>((e) => captured2 = e);

        await client1.signIn('fake');

        expect(captured1, isNotNull);  // client1 received the event
        expect(captured2, isNull);     // client2 did NOT receive it

        await client1.dispose();
        await client2.dispose();
      });
    });

    group('registerProvider', () {
      test('dynamically registers a new provider', () async {
        final client = AuthyraClient(
          providers: [],
          storage: InMemoryStorage(),
        );
        await client.initialize();

        final provider = _FakeProvider(
          returnUser: AuthUser(id: 'u1'),
          returnAccessToken: 'tok',
          returnExpiresAt: DateTime.now().add(const Duration(hours: 1)),
        );
        client.registerProvider(provider);
        final user = await client.signIn('fake');
        expect(user.id, 'u1');
        await client.dispose();
      });

      test('registering duplicate id throws', () async {
        final p = _FakeProvider(returnUser: AuthUser(id: 'u1'));
        final client = _client(p);
        await client.initialize();
        expect(
          () => client.registerProvider(p),
          throwsA(isA<ProviderAlreadyRegisteredException>()),
        );
        await client.dispose();
      });
    });

    group('multi-account', () {
      test('accounts.getAll returns signed-in users', () async {
        final p1 = _FakeProvider(
          returnUser: AuthUser(id: 'u1', email: 'u1@test.com'),
          returnAccessToken: 'tok1',
          returnExpiresAt: DateTime.now().add(const Duration(hours: 1)),
        );
        final p2 = _FakeProvider(
          returnUser: AuthUser(id: 'u2', email: 'u2@test.com'),
          returnAccessToken: 'tok2',
          returnExpiresAt: DateTime.now().add(const Duration(hours: 1)),
        );

        // Two providers with different ids
        final client = AuthyraClient(
          providers: [],
          storage: InMemoryStorage(),
        );
        await client.initialize();

        client.registerProvider(p1);
        await client.signIn('fake'); // signs in u1... but p1.id == 'fake'

        // To sign in a second user we'd need a second provider id.
        // This test is limited to single-provider multi-account.
        final users = await client.accounts.getAll();
        expect(users.length, 1);
        expect(users.first.id, 'u1');
        await client.dispose();
      });
    });
  });
}

# authyra

[![pub.dev](https://img.shields.io/pub/v/authyra.svg)](https://pub.dev/packages/authyra)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/meragix/authyra/blob/main/LICENSE)

Authentication framework for Dart. No Flutter dependency. Runs on mobile, web, desktop, backend (Shelf, Dart Frog), and CLI.

---

## What it does

- **`AuthyraClient`** — stateless orchestrator. Handles provider registration, session creation, and token operations. No global state, fully injectable, 100% testable.
- **`AuthyraInstance`** — singleton wrapper. Adds reactive `Stream<AuthState>`, synchronous state cache, and a one-call initialization API for app startup.
- **`SessionManager`** — multi-account session registry. Persists, restores, switches, and cleans up sessions.
- **`AuthStorage`** — pluggable interface. Bring your own persistence: `flutter_secure_storage`, Redis, encrypted file — anything.
- **`AuthProvider`** — pluggable strategy interface. Implement it to add any authentication flow.

---

## Installation

```yaml
dependencies:
  authyra: ^0.1.0
```

---

## Quick start

```dart
import 'package:authyra/authyra.dart';

void main() async {
  await Authyra.initialize(
    client: AuthyraClient(
      providers: [
        CredentialsProvider.withTokens(
          id: 'email',
          authorize: (creds) async {
            final res = await myApi.post('/auth/login', body: creds);
            if (res.statusCode != 200) return null;
            return AuthSignInResult(
              user: AuthUser(id: res.data['id'], email: res.data['email']),
              accessToken: res.data['accessToken'],
              refreshToken: res.data['refreshToken'],
              expiresAt: DateTime.parse(res.data['expiresAt']),
            );
          },
        ),
      ],
      storage: MyStorage(), // implement AuthStorage for your platform
    ),
  );

  // Sign in
  final user = await Authyra.instance.signIn('email', params: {
    'email': 'alice@example.com',
    'password': 's3cr3t',
  });

  // Synchronous state — no await
  print(Authyra.instance.isAuthenticated);   // true
  print(Authyra.instance.currentUser?.email);

  // Reactive state
  Authyra.instance.authStateChanges.listen((state) {
    switch (state.type) {
      case AuthStateType.authenticated:   print('Hello ${state.user!.name}');
      case AuthStateType.unauthenticated: print('Signed out');
      case AuthStateType.error:           print('Error: ${state.error}');
    }
  });

  // Sign out
  await Authyra.instance.signOut();
}
```

---

## Providers

### `CredentialsProvider` — email / password

Two constructors depending on what your backend returns:

```dart
// Backend returns a user profile only (cookie / opaque session)
CredentialsProvider(
  id: 'email',
  authorize: (creds) async {
    final res = await myApi.post('/login', body: creds);
    if (res.statusCode != 200) return null;
    return AuthUser(id: res.data['id'], email: res.data['email']);
  },
)

// Backend returns JWT tokens (recommended)
CredentialsProvider.withTokens(
  id: 'email',
  authorize: (creds) async {
    final res = await myApi.post('/login', body: creds);
    if (res.statusCode != 200) return null;
    return AuthSignInResult(
      user: AuthUser(id: res.data['userId'], email: res.data['email']),
      accessToken: res.data['accessToken'],
      refreshToken: res.data['refreshToken'],
      expiresAt: DateTime.parse(res.data['expiresAt']),
    );
  },
)
```

### Custom provider

Implement `AuthProvider` to plug in any strategy — SAML, magic link, phone OTP, a proprietary SSO:

```dart
class MagicLinkProvider implements AuthProvider {
  @override String get id   => 'magic-link';
  @override AuthProviderType get type => AuthProviderType.magicLink;
  @override bool get supportsRefresh => false;

  @override
  Future<AuthSignInResult?> signIn({Map<String, dynamic>? params}) async {
    final token = params?['token'] as String?;
    if (token == null) return null;
    final res = await myApi.post('/auth/magic', body: {'token': token});
    if (res.statusCode != 200) return null;
    return AuthSignInResult(
      user: AuthUser(id: res.data['id'], email: res.data['email']),
      accessToken: res.data['accessToken'],
      expiresAt: DateTime.parse(res.data['expiresAt']),
    );
  }
}
```

---

## Storage

`AuthStorage` is a key-value interface. Implement it for your runtime:

```dart
class MyRedisStorage implements AuthStorage {
  @override Future<void>         initialize()                    async { /* connect */ }
  @override Future<String?>      read(String key)                => redis.get(key);
  @override Future<void>         write(String key, String value) => redis.set(key, value);
  @override Future<bool>         delete(String key)              async {
    final existed = await redis.exists(key) > 0;
    await redis.del([key]);
    return existed;
  }
  @override Future<void>         clear()                         => redis.flushDb();
  @override Future<bool>         containsKey(String key)         async => await redis.exists(key) > 0;
  @override Future<List<String>> getKeysWithPrefix(String p)     => redis.keys('$p*');
}
```

An `InMemoryStorage` (non-persistent) is exported from the package for use in tests and development.

---

## Multi-account

Authyra supports multiple signed-in accounts out of the box:

```dart
// List all signed-in users
final accounts = await Authyra.instance.accounts.getAll();

// Switch active account
await Authyra.instance.accounts.switchTo(userId);

// Sign out a specific account
await Authyra.instance.accounts.signOut(userId);

// Sign out all accounts
await Authyra.instance.accounts.signOutAll();

// Remove stale expired sessions
final removed = await Authyra.instance.accounts.cleanExpired();
```

---

## Advanced: using `AuthyraClient` directly

For dependency injection or backend use cases where you don't want a singleton:

```dart
final client = AuthyraClient(
  providers: [CredentialsProvider(id: 'email', authorize: myAuthorize)],
  storage: MyStorage(),
  config: const AuthConfig(autoRefresh: true),
);

await client.initialize();

final user = await client.signIn('email', params: {'email': '...', 'password': '...'});

client.authStateStream.listen((state) { /* react */ });
```

---

## Testing

```dart
import 'package:test/test.dart';
import 'package:authyra/authyra.dart';

void main() {
  test('sign in succeeds with valid credentials', () async {
    final client = AuthyraClient(
      providers: [
        CredentialsProvider(
          id: 'email',
          authorize: (creds) async =>
              AuthUser(id: '1', email: creds!['email'] as String),
        ),
      ],
      storage: InMemoryStorage(),
    );

    await client.initialize();

    final user = await client.signIn('email', params: {
      'email': 'alice@example.com',
      'password': 'any',
    });

    expect(user.email, 'alice@example.com');
  });
}
```

---

## Flutter

Use [`authyra_flutter`](https://pub.dev/packages/authyra_flutter) for Flutter apps. It re-exports this entire package plus adds OAuth2 providers (Google, GitHub, Apple), `SecureAuthStorage`, `AuthGuard` widget, and GoRouter integration. One import, everything included.

---

## Documentation

[meragix.github.io/authyra](https://meragix.github.io/authyra)

## License

MIT

# Authyra

**Pure authentication logic framework for Dart and Flutter.**

Authyra is a navigation-agnostic, platform-agnostic authentication framework. The core `authyra` package has zero Flutter dependency — it runs identically on mobile, web, desktop, backend, and CLI.

---

## Why Authyra?

| Problem | Authyra's Answer |
|---------|-----------------|
| Auth logic tangled with UI/navigation | `AuthyraClient` is pure Dart, zero Flutter imports |
| Opaque "black box" SDK | Every component is an interface — swap storage, swap providers |
| No multi-account support | `AccountManager` ships in the core |
| Reactive state requires boilerplate | `authStateChanges` stream out of the box |
| Hard to test | Use `AuthyraClient` directly; no singleton required in tests |

---

## Quick Start

```yaml
# pubspec.yaml
dependencies:
  authyra: ^0.1.0
```

```dart
import 'package:authyra/authyra.dart';

void main() async {
  // 1. Build the client — stateless, testable, no global state.
  final client = AuthyraClient(
    providers: [
      CredentialsProvider.withTokens(
        id: 'email',
        authorize: (creds) async {
          final res = await myApi.post('/auth/login', body: creds);
          if (res.statusCode != 200) return null;
          return AuthSignInResult(
            user: AuthUser(id: res.data['id'], email: res.data['email']),
            accessToken:  res.data['accessToken'],
            refreshToken: res.data['refreshToken'],
            expiresAt:    DateTime.parse(res.data['expiresAt']),
          );
        },
      ),
    ],
    storage: InMemoryAuthStorage(), // Use SecureAuthStorage in production
  );

  // 2. Initialize the singleton — restores any persisted session.
  await Authyra.initialize(client: client);

  // 3. Sign in.
  final user = await Authyra.instance.signIn('email', params: {
    'email':    'alice@example.com',
    'password': 's3cr3t',
  });
  print('Hello, ${user.name}!');

  // 4. React to state changes.
  Authyra.instance.authStateChanges.listen((state) {
    if (state.isAuthenticated) {
      print('Signed in: ${state.user!.email}');
    } else {
      print('Signed out');
    }
  });

  // 5. Sign out.
  await Authyra.instance.signOut();
}
```

---

## Architecture

```text
┌──────────────────────────────────────────────────────────┐
│  AuthyraClient                                           │
│  Pure business logic — stateless, testable, injectable   │
│  • Manages providers and storage                         │
│  • Creates and refreshes AuthSessions                    │
│  • Emits AuthState via broadcast stream                  │
└──────────────────────────┬───────────────────────────────┘
                           │ wrapped by
┌──────────────────────────▼───────────────────────────────┐
│  AuthyraInstance  (typedef: Authyra)                     │
│  Singleton — global access + synchronous state cache     │
│  • currentUser / currentState / isAuthenticated          │
│  • authStateChanges  Stream<AuthState>                   │
│  • sessionStream     Stream<AuthSession?>                │
│  • accounts          AccountManager (multi-account)      │
└──────────────────────────────────────────────────────────┘
```

**Authyra tells you WHAT the auth state is. You decide WHERE to navigate.**

---

## Providers (v0.1.0)

| Provider | Use case |
|----------|----------|
| `CredentialsProvider` | Email / password — user profile only |
| `CredentialsProvider.withTokens` | Email / password — JWT backend returns tokens |
| `OAuth2Provider` | Generic Authorization Code + PKCE |
| `GoogleProvider` | Google Sign-In (prebuilt `OAuth2Provider`) |
| `GitHubOAuth2Provider` | GitHub OAuth App (prebuilt `OAuth2Provider`) |
| `ProxyOAuthProvider` | Backend-delegated OAuth — client secret stays on server |

All providers implement `AuthProvider`:

```dart
class MyProvider implements AuthProvider {
  @override String get id => 'my-backend';

  @override
  Future<AuthSignInResult?> signIn({Map<String, dynamic>? params}) async {
    final res = await myApi.post('/login', body: params);
    if (res.statusCode != 200) return null;
    return AuthSignInResult(
      user:         AuthUser(id: res.data['id']),
      accessToken:  res.data['accessToken'],
      refreshToken: res.data['refreshToken'],
      expiresAt:    DateTime.parse(res.data['expiresAt']),
    );
  }
}
```

---

## Storage

`AuthStorage` is a pluggable interface — the core ships no concrete implementation:

| Runtime | Recommended backend |
|---------|---------------------|
| Flutter | `flutter_secure_storage` (Keychain / Keystore) |
| Dart CLI | Encrypted file or OS keyring |
| Backend | Redis, encrypted DB column |
| Tests / dev | `InMemoryAuthStorage` (bundled) |

```dart
class SecureAuthStorage implements AuthStorage {
  final _store = const FlutterSecureStorage();

  @override Future<void>    initialize()                     async {}
  @override Future<String?> read(String key)                 => _store.read(key: key);
  @override Future<void>    write(String key, String value)  => _store.write(key: key, value: value);
  @override Future<bool>    delete(String key)               async {
    final exists = await _store.containsKey(key: key);
    await _store.delete(key: key);
    return exists;
  }
  @override Future<void>    clear()                          => _store.deleteAll();
  @override Future<bool>    containsKey(String key)          => _store.containsKey(key: key);
  @override Future<List<String>> getKeysWithPrefix(String p) async {
    final all = await _store.readAll();
    return all.keys.where((k) => k.startsWith(p)).toList();
  }
}
```

---

## Multi-Account

```dart
// Get all signed-in accounts
final users = await Authyra.instance.accounts.getAll();

// Switch active account
await Authyra.instance.accounts.switchTo(userId);

// Sign out one account
await Authyra.instance.accounts.signOut(userId);

// Sign out all accounts
await Authyra.instance.accounts.signOutAll();
```

---

## Reactive State

```dart
// Broadcast stream — deduplicated via Equatable
Authyra.instance.authStateChanges.listen((AuthState state) {
  switch (state.type) {
    case AuthStateType.authenticated:   /* navigate to /home */
    case AuthStateType.unauthenticated: /* navigate to /login */
    case AuthStateType.error:           /* show error banner */
  }
});

// Raw session stream
Authyra.instance.sessionStream.listen((AuthSession? session) { ... });

// GoRouter integration
GoRouter(
  refreshListenable: StreamToListenable(Authyra.instance.authStateChanges),
  redirect: (context, state) {
    if (!Authyra.instance.isAuthenticated) return '/login';
    return null;
  },
);
```

---

## Synchronous State

```dart
// No await needed — safe to call in build() methods
final user    = Authyra.instance.currentUser;    // AuthUser?
final state   = Authyra.instance.currentState;   // AuthState
final isAuth  = Authyra.instance.isAuthenticated; // bool
```

---

## Testing

Use `AuthyraClient` directly — no singleton, no `initialize()` call needed:

```dart
test('sign in with valid credentials returns user', () async {
  final client = AuthyraClient(
    providers: [
      CredentialsProvider(
        id: 'email',
        authorize: (creds) async => AuthUser(id: '1', email: 'test@example.com'),
      ),
    ],
    storage: InMemoryAuthStorage(),
  );

  await client.initialize();
  final user = await client.signIn('email', params: {
    'email': 'test@example.com',
    'password': 'password',
  });

  expect(user.email, 'test@example.com');
});
```

---

## Repository Structure

```text
packages/authyra/          # Core Dart package (pub.dev)
docs/                      # Nuxt.js + Docus documentation site
examples/                  # Setup guides and walkthroughs
```

---

## Documentation

Full documentation: [meragix.github.io/authyra](https://meragix.github.io/authyra)

- [Getting Started](https://meragix.github.io/authyra/getting-started/introduction)
- [Architecture](https://meragix.github.io/authyra/core-concepts/architecture)
- [API Reference — AuthyraClient](https://meragix.github.io/authyra/api-reference/authyra-client)
- [API Reference — AuthyraInstance](https://meragix.github.io/authyra/api-reference/authyra-instance)

---

## Roadmap

| Version | Focus |
|---------|-------|
| **v0.1.0** | Core framework, providers, multi-account, reactive state |
| v0.2.0 | JWT utils, token auto-refresh, expanded provider set |
| v0.3.0 | `flutter_authyra` — UI widgets, GoRouter helpers |
| v1.0.0 | Production-ready, 90%+ test coverage |

---

## License

MIT — see [LICENSE](LICENSE)

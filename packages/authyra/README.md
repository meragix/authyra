# authyra

**Pure Dart authentication logic framework.**

`authyra` is the core package — zero Flutter dependency, runs on any Dart platform: mobile, web, desktop, backend (Shelf, Dart Frog), and CLI.

## Features

- Stateless `AuthyraClient` — fully injectable, 100% testable, no global state
- Reactive singleton `AuthyraInstance` — broadcast streams + synchronous state cache
- Built-in providers: `CredentialsProvider`, `OAuth2Provider` (PKCE), `GoogleProvider`, `GitHubOAuth2Provider`, `ProxyOAuthProvider`
- Pluggable `AuthStorage` interface — bring your own persistence
- `InMemoryAuthStorage` bundled for tests and development
- Multi-account `AccountManager` — switch, sign out one, sign out all
- `AuthSession` with expiry tracking and `shouldRefresh` detection
- `AuthState` with `Equatable` — stream deduplication out of the box

## Installation

```yaml
dependencies:
  authyra: ^0.1.0
```

## Quick Start

```dart
import 'package:authyra/authyra.dart';

void main() async {
  // 1. Build the client — pure Dart, no side effects
  final client = AuthyraClient(
    providers: [
      CredentialsProvider.withTokens(
        id: 'email',
        authorize: (creds) async {
          final res = await myApi.post('/auth/login', body: creds);
          if (res.statusCode != 200) return null;
          return AuthSignInResult(
            user:         AuthUser(id: res.data['id'], email: res.data['email']),
            accessToken:  res.data['accessToken'],
            refreshToken: res.data['refreshToken'],
            expiresAt:    DateTime.parse(res.data['expiresAt']),
          );
        },
      ),
    ],
    storage: InMemoryAuthStorage(), // use SecureAuthStorage in production
  );

  // 2. Initialize the singleton (restores persisted session)
  await Authyra.initialize(client: client);

  // 3. React to auth state
  Authyra.instance.authStateChanges.listen((state) {
    print('[${state.type.name}] ${state.user?.email}');
  });

  // 4. Sign in
  final user = await Authyra.instance.signIn('email', params: {
    'email':    'alice@example.com',
    'password': 'secret',
  });
  print('Hello, ${user.name}!');

  // 5. Synchronous state — no await
  print(Authyra.instance.isAuthenticated); // true
  print(Authyra.instance.currentUser?.email);

  // 6. Sign out
  await Authyra.instance.signOut();
}
```

## Providers

| Provider                         | Strategy    | Notes                                          |
| -------------------------------- | ----------- | ---------------------------------------------- |
| `CredentialsProvider`            | credentials | User profile only — no token storage           |
| `CredentialsProvider.withTokens` | credentials | JWT backend — stores access + refresh tokens   |
| `OAuth2Provider`                 | oauth2      | Authorization Code + PKCE (any provider)       |
| `GoogleProvider`                 | oauth2      | Prebuilt Google Sign-In                        |
| `GitHubOAuth2Provider`           | oauth2      | Prebuilt GitHub OAuth (no PKCE)                |
| `ProxyOAuthProvider`             | oauth2      | Backend-delegated — client secret stays server |

## Custom Provider

```dart
class MyProvider implements AuthProvider {
  @override String get id   => 'my-api';
  @override AuthProviderType get type => AuthProviderType.credentials;
  @override bool get supportsRefresh  => true;

  @override
  Future<AuthSignInResult?> signIn({Map<String, dynamic>? params}) async {
    final res = await myApi.post('/auth/login', body: params);
    if (res.statusCode != 200) return null;
    return AuthSignInResult(
      user:         AuthUser(id: res.data['id']),
      accessToken:  res.data['accessToken'],
      refreshToken: res.data['refreshToken'],
      expiresAt:    DateTime.parse(res.data['expiresAt']),
    );
  }

  @override
  Future<AuthTokenResult?> refreshToken(String refreshToken) async {
    final res = await myApi.post('/auth/refresh', body: {'token': refreshToken});
    if (res.statusCode != 200) return null;
    return AuthTokenResult(
      accessToken: res.data['accessToken'],
      expiresAt:   DateTime.parse(res.data['expiresAt']),
    );
  }
}
```

## Custom Storage

```dart
class SecureAuthStorage implements AuthStorage {
  final _store = const FlutterSecureStorage();

  @override Future<void>         initialize()                    async {}
  @override Future<String?>      read(String key)                => _store.read(key: key);
  @override Future<void>         write(String key, String value) => _store.write(key: key, value: value);
  @override Future<bool>         delete(String key) async {
    final e = await _store.containsKey(key: key);
    await _store.delete(key: key);
    return e;
  }
  @override Future<void>         clear()                         => _store.deleteAll();
  @override Future<bool>         containsKey(String key)         => _store.containsKey(key: key);
  @override Future<List<String>> getKeysWithPrefix(String p) async {
    final all = await _store.readAll();
    return all.keys.where((k) => k.startsWith(p)).toList();
  }
}
```

## Testing

```dart
import 'package:test/test.dart';
import 'package:authyra/authyra.dart';

void main() {
  test('sign in with valid credentials', () async {
    final client = AuthyraClient(
      providers: [
        CredentialsProvider(
          id: 'email',
          authorize: (creds) async =>
              AuthUser(id: '1', email: creds!['email'] as String),
        ),
      ],
      storage: InMemoryAuthStorage(),
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

## Flutter UI

The `flutter_authyra` package (widgets, `BuildContext` extensions, GoRouter helpers) is on the roadmap for **v0.3.0**. Wire Authyra's `authStateChanges` stream directly into your existing routing and state management in the meantime.

## Documentation

[meragix.github.io/authyra](https://meragix.github.io/authyra)

## License

MIT

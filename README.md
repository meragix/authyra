# Authyra

Authentication framework for Dart and Flutter. Handles the full auth lifecycle: session persistence, token refresh, multi-account; without locking you into a backend or a UI framework.

[![pub.dev](https://img.shields.io/pub/v/authyra.svg)](https://pub.dev/packages/authyra)
[![pub.dev flutter](https://img.shields.io/pub/v/authyra_flutter.svg?label=authyra_flutter)](https://pub.dev/packages/authyra_flutter)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

---

## Packages

| Package | Description |
|---|---|
| [`authyra`](packages/authyra) | Core framework: pure Dart, zero Flutter dependency |
| [`authyra_flutter`](packages/authyra_flutter) | Flutter layer: OAuth2, widgets, GoRouter guard |

**Use `authyra` alone** for Dart backends (Shelf, Dart Frog) or CLI tools.
**Use `authyra_flutter`** for Flutter apps: it re-exports the entire core so you only ever need one import.

---

## Quick start

### Flutter app

```yaml
# pubspec.yaml
dependencies:
  authyra_flutter: ^0.1.0
```

```dart
import 'package:authyra_flutter/authyra_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Authyra.initialize(
    client: AuthyraClient(
      providers: [
        CredentialsProvider.withTokens(
          id: 'email',
          authorize: (creds) async {
            final res = await myApi.post('/auth/login', body: {
              'email': creds?.email,
              'password': creds?.password,
            });
            if (res.statusCode != 200) return null;
            return AuthSignInResult(
              user: AuthUser(id: res.data['id'], email: res.data['email']),
              accessToken: res.data['accessToken'],
              refreshToken: res.data['refreshToken'],
              expiresAt: DateTime.parse(res.data['expiresAt']),
            );
          },
        ),
        GoogleProvider(clientId: 'YOUR_CLIENT_ID'),
      ],
      storage: SecureAuthStorage(), // from authyra_flutter
    ),
  );

  runApp(const MyApp());
}
```

```dart
// Sign in
await Authyra.instance.signIn('email', params: CredentialsSignInParams(
  email: 'alice@example.com',
  password: 's3cr3t',
));

// Reactive UI
StreamBuilder<AuthState>(
  stream: Authyra.instance.authStateChanges,
  builder: (context, snapshot) {
    final state = snapshot.data ?? AuthState.unauthenticated();
    return state.isAuthenticated ? Dashboard() : LoginPage();
  },
);
```

### Dart backend

```yaml
dependencies:
  authyra: ^0.1.0
```

```dart
import 'package:authyra/authyra.dart';

final client = AuthyraClient(
  providers: [
    CredentialsProvider.withTokens(
      id: 'email',
      authorize: (creds) async {
        // validate against your DB
        return AuthSignInResult(user: AuthUser(id: '...', email: creds?.email ?? ''));
      },
    ),
  ],
  storage: MyRedisStorage(),
);

await client.initialize();

final user = await client.signIn('email', params: CredentialsSignInParams(
  email: 'alice@example.com',
  password: 's3cr3t',
));
```

---

## Architecture

```text
packages/
├── authyra/              ← Core: AuthyraClient, providers, session, storage interface
└── authyra_flutter/      ← Flutter: OAuth2 providers, SecureStorage, widgets, routing
```

**Two layers, one principle:** the core is pure Dart. Flutter-specific code (platform channels, URL launcher, secure storage) lives entirely in `authyra_flutter`. The same provider interface works on both layers.

```text
AuthyraClient          ← stateless orchestrator (injectable, testable)
    └── SessionManager ← CRUD + multi-account registry + proactive token refresh
    └── AuthProvider   ← pluggable auth strategy (credentials / OAuth2 / custom)
    └── AuthStorage    ← pluggable persistence (you own the implementation)
    └── AuthyraPlugin  ← lifecycle hooks (onBeforeSignIn, onAfterSignIn, onSessionExpired)

AuthyraInstance        ← singleton wrapper (reactive streams + sync state cache)
```

---

## Providers

| Provider | Package | Strategy |
|---|---|---|
| `CredentialsProvider` | `authyra` | Email/password or any form-based flow |
| `CredentialsProvider.withTokens` | `authyra` | JWT backend: stores access + refresh tokens |
| `OAuth2Provider` | `authyra_flutter` | Authorization Code + PKCE (any IdP) |
| `GoogleProvider` | `authyra_flutter` | Prebuilt Google Sign-In |
| `GitHubOAuth2Provider` | `authyra_flutter` | Prebuilt GitHub OAuth |
| `AppleProvider` | `authyra_flutter` | Sign in with Apple |
| `ProxyOAuthProvider` | `authyra_flutter` | Backend-delegated OAuth (client secret stays server-side) |

---

## Events

```dart
client.events.on<SignInEvent>((e) {
  analytics.track('sign_in', {'provider': e.providerName});
});

client.events.on<TokenRefreshEvent>((e) {
  if (!e.success) showReAuthPrompt();
});

// All events as a raw stream (audit logging, etc.)
client.events.stream.listen((e) => auditLog.write(e.toJson()));
```

---

## Plugins

```dart
final client = AuthyraClient(
  providers: [...],
  storage: SecureAuthStorage(),
  plugins: [
    RateLimitPlugin(maxAttempts: 5, window: Duration(minutes: 15)),
    AuditLogPlugin(logger: myLogger),
  ],
);
```

```dart
class RateLimitPlugin extends AuthyraPlugin {
  @override String get name => 'rate-limit';

  @override
  void install(AuthyraClient client) {
    // wire up client references if needed
  }

  @override
  Future<void> onBeforeSignIn(String providerId, AuthSignInParams? params) async {
    if (_isRateLimited(providerId)) {
      throw AuthenticationFailedException('Too many attempts. Try again later.');
    }
  }
}
```

---

## Development

This monorepo uses [Melos](https://melos.invertase.dev/).

```bash
dart pub global activate melos
melos bootstrap     # install deps across all packages

melos run analyze   # dart analyze
melos run format    # dart format
melos run test      # run tests with coverage
```

---

## Documentation

[meragix.github.io/authyra](https://meragix.github.io/authyra)

---

## License

MIT

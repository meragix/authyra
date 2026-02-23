---
title: FAQ
description: Frequently asked questions about Authyra.
seo:
  title: FAQ | Authyra
  description: Answers to common questions about Authyra's design, scope, and usage.
---

## General

### What is Authyra?

Authyra is a pure authentication logic framework for Dart and Flutter. It handles authentication state, session management, and provider orchestration while remaining completely agnostic to your navigation and UI choices.

The core `authyra` package has no Flutter dependency and runs identically on mobile, web, desktop, backend (Shelf, Dart Frog), and CLI tools.

---

### Why not use Firebase Auth or Supabase Auth?

You can — Authyra doesn't compete with BaaS platforms. The difference is:

| Aspect             | Firebase / Supabase      | Authyra                        |
| ------------------ | ------------------------ | ------------------------------ |
| Backend            | Managed service          | Bring your own                 |
| Auth logic         | In the SDK               | In your app (you own it)       |
| Navigation control | Opinionated              | Fully decoupled                |
| Multi-platform     | Flutter + limited Dart   | Any Dart platform              |

Use Authyra when you have your own backend, want full control, or need to run the same auth logic on both a Flutter app and a Dart backend.

---

### Is Authyra production-ready?

v0.1.0 is an **MVP release**. The API is stable for the core features but the test suite is still being expanded. We recommend:

- Using it in new projects and side projects now.
- Waiting for v1.0.0 (targeting ≥ 90% test coverage) for mission-critical production systems.

---

### Does Authyra work offline?

Session state is cached in memory and persisted to `AuthStorage`. Your app can:

- Read `Authyra.instance.isAuthenticated` and `currentUser` offline — no network call required.
- React to cached state immediately on startup, before any network request.

---

## Technical

### Why two packages? (core vs Flutter)

**`authyra`** (pure Dart, v0.1.0 — current):

- Zero Flutter dependency.
- Works on backend, CLI, scripts.
- `dart test` runs without a Flutter device.
- Smaller pub.dev bundle.

**`flutter_authyra`** (Flutter, planned v0.3.0):

- `AuthyraScope` — InheritedWidget for widget tree propagation.
- `AuthBuilder` — reactive builder widget.
- `AuthGuard` — declarative route protection.
- `BuildContext` extensions.
- GoRouter / AutoRoute helpers.

This separation keeps the authentication core clean and reusable while the Flutter layer remains purely additive.

---

### Can I use Authyra without Flutter?

Yes. Just add `authyra` (not `flutter_authyra`):

```yaml
dependencies:
  authyra: ^0.1.0
```

Works in:

- Dart backend services (Shelf, Dart Frog)
- CLI tools
- Scripts
- Unit tests

---

### Does Authyra support multi-account?

Yes — `AccountManager` ships in the core (`authyra` package):

```dart
final mgr = Authyra.instance.accounts;

// All signed-in accounts, sorted by last activity
final users = await mgr.getAll();

// Activate a different account
await mgr.switchTo(userId);

// Sign out one account, keep others active
await mgr.signOut(userId);

// Sign out every account
await mgr.signOutAll();

// Prune expired sessions
await mgr.cleanExpired();
```

The number of concurrent accounts is capped by `AuthConfig.maxAccounts` (default: 5).

---

### Can I use my own state management?

Authyra is completely state-management-agnostic. The `authStateChanges` stream plugs into anything:

**Riverpod**:

```dart
final authStateProvider = StreamProvider<AuthState>((ref) {
  return Authyra.instance.authStateChanges;
});

// In a widget:
final state = ref.watch(authStateProvider).value;
```

**Bloc / Cubit**:

```dart
class AuthCubit extends Cubit<AuthState> {
  late final StreamSubscription<AuthState> _sub;

  AuthCubit() : super(AuthState.unauthenticated()) {
    _sub = Authyra.instance.authStateChanges.listen(emit);
  }

  @override
  Future<void> close() {
    _sub.cancel();
    return super.close();
  }
}
```

**GoRouter**:

```dart
GoRouter(
  refreshListenable: StreamToListenable(Authyra.instance.authStateChanges),
  redirect: (context, state) {
    if (!Authyra.instance.isAuthenticated) return '/login';
    return null;
  },
);
```

---

### How do I test code that uses Authyra?

Use `AuthyraClient` directly — no singleton, no `Authyra.initialize()` required:

```dart
import 'package:test/test.dart';
import 'package:authyra/authyra.dart';

void main() {
  late AuthyraClient client;

  setUp(() async {
    client = AuthyraClient(
      providers: [
        CredentialsProvider(
          id: 'email',
          authorize: (creds) async {
            if (creds?['password'] == 'secret') {
              return AuthUser(id: '1', email: creds!['email'] as String);
            }
            return null;
          },
        ),
      ],
      storage: InMemoryAuthStorage(),
    );
    await client.initialize();
  });

  test('sign in succeeds with correct password', () async {
    final user = await client.signIn('email', params: {
      'email':    'alice@example.com',
      'password': 'secret',
    });
    expect(user.email, equals('alice@example.com'));
  });

  test('sign in fails with wrong password', () async {
    expect(
      () => client.signIn('email', params: {
        'email':    'alice@example.com',
        'password': 'wrong',
      }),
      throwsA(isA<AuthenticationFailedException>()),
    );
  });
}
```

If your test code uses `Authyra.instance`, call `dispose()` in `tearDown` to reset the singleton between tests:

```dart
tearDown(() async {
  if (Authyra.isInitialized) {
    await Authyra.instance.dispose();
  }
});
```

---

### What storage backend should I use?

| Runtime         | Recommended                                          |
| --------------- | ---------------------------------------------------- |
| Tests / dev     | `InMemoryAuthStorage` (bundled with `authyra`)       |
| Flutter mobile  | `flutter_secure_storage` (Keychain / Keystore)       |
| Flutter web     | `flutter_secure_storage` with web options            |
| Dart CLI        | Encrypted file or OS keyring                         |
| Backend / Shelf | Redis, encrypted DB column, or a secrets manager     |

Never store tokens in `SharedPreferences` or browser `localStorage` — they are not encrypted.

---

### How does token refresh work?

When `AuthyraClient.refreshSession()` is called (manually or triggered by an API 401):

1. The active `AuthSession` is retrieved.
2. If `session.shouldRefresh` is `true` (token expires within `AuthConfig.refreshBeforeExpiry`), the client calls `provider.refreshToken(session.refreshToken)`.
3. The provider returns `AuthTokenResult` with the new `accessToken` (and optionally a new `refreshToken`).
4. The session is updated in `SessionManager` and re-persisted to storage.
5. `authStateChanges` emits the refreshed `AuthState.authenticated`.

If the refresh token is itself expired or invalid, `refreshToken` returns `null`, the session is cleared, and `AuthState.unauthenticated()` is emitted.

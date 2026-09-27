# Authyra

**The authentication orchestrator for Flutter. Not another Identity Provider.**

Authyra owns your app's session lifecycle: persistence, token refresh, multi-account switching, events. Plug in Firebase, Auth0, or your own API today; swap it later without touching a screen.

[![pub.dev](https://img.shields.io/pub/v/authyra.svg)](https://pub.dev/packages/authyra)
[![pub.dev flutter](https://img.shields.io/pub/v/authyra_flutter.svg?label=authyra_flutter)](https://pub.dev/packages/authyra_flutter)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

---

## The problem

- **Firebase Auth, Auth0, Supabase Auth**: excellent SDKs, but your app adopts their model. The moment you have a custom backend, multiple tenants, or want to switch provider later, you're re-architecting.
- **Raw OAuth2/OIDC packages** (`openidconnect_flutter` and friends): solve the protocol correctly, then leave session persistence, token refresh, and multi-account switching entirely up to you. Again. In every app.
- **Most teams hand-roll this layer once, imperfectly, per project.** Authyra is that layer: built once, tested, reusable.

## The mental model

```text
┌──────────────────────┐
│    Flutter App        │
└──────────┬────────────┘
           │
           ▼
┌──────────────────────┐
│       Authyra         │
│                        │
│  Session lifecycle     │
│  Token refresh         │
│  Persistence           │
│  Multi-account         │
│  Events & plugins      │
└──────────┬────────────┘
           │
           ▼
┌──────────────────────┐
│  Your auth provider    │
│                        │
│  Custom API            │
│  OAuth2 / OIDC         │
│  Auth0 / Firebase...   │
└──────────────────────┘
```

**Providers authenticate. Authyra manages the resulting session.** Swap the provider underneath; the session layer above it never changes.

## See it in 30 seconds

```dart
// Your own backend today...
await Authyra.instance.signIn('email', params: CredentialsSignInParams(
  email: 'alice@example.com',
  password: 's3cr3t',
));

// ...add Google next month. Same client, same call shape, no rewrite:
await Authyra.instance.signIn('google');
```

The call site doesn't care who's behind it. That's the whole point.

## Authyra vs. the usual suspects

| | Firebase Auth | Auth0 Flutter | Supabase Auth | Raw OAuth2/OIDC package | **Authyra** |
|---|---|---|---|---|---|
| Backend-agnostic | ❌ Firebase is the backend | ❌ Auth0 is the IdP | ❌ Supabase is the backend | ✅ protocol only | ✅ |
| Multi-account switching built in | ❌ | ❌ | ❌ | ❌ out of scope | ✅ |
| Refresh token lifecycle | Managed internally, fixed | Managed internally, fixed | Managed internally, fixed | ❌ you build it | ✅ configurable, with retry and events |
| Pluggable storage | ❌ fixed to the SDK | ❌ fixed to the SDK | ❌ fixed to the SDK | N/A | ✅ bring your own |
| Dart core, zero Flutter dependency | ❌ | ❌ | ❌ | package-dependent | ✅ |

*This table describes architectural scope, not a quality ranking. Firebase, Auth0, and Supabase are excellent at what they do, it's a different problem than the one Authyra solves.*

---

## Core principles

**Provider-agnostic.** Implement `AuthProvider` once to plug in any strategy. Ships with `CredentialsProvider` (core) and `OAuth2Provider` / `GoogleProvider` / `GitHubOAuth2Provider` / `AppleProvider` / `ProxyOAuthProvider` (`authyra_flutter`). Add your own for anything else: a SAML bridge, magic link, phone OTP.

**Session-first.** `SessionManager` owns the client-side session lifecycle: restore on app start, proactive token refresh with retry, sign-out, and a reactive `AuthState` stream. This is the part a raw OAuth/OIDC package leaves for you to build yourself.

**Multi-account by design.** This is the feature most competing packages don't have at all. Several signed-in identities can coexist on the device and be switched or signed out independently, without rebuilding your auth architecture:

```dart
// Personal + work account signed in at the same time
await Authyra.instance.signIn('google');                    // personal Gmail (now active)
await Authyra.instance.signIn('email', params: workCreds);  // work account (now active)
await Authyra.instance.accounts.switchTo(personalUserId);   // back to personal, no re-auth
final all = await Authyra.instance.accounts.getAll();       // both, most-recent-first
await Authyra.instance.accounts.signOut(workUserId);        // drop just one
```

See [Known limitations](#known-limitations): this is *multiple identities on one device*, not *linking two providers to one identity*, that part isn't built yet.

**Storage-agnostic.** `AuthStorage` is a plain key-value contract. The core ships zero concrete implementation; you bring Keychain/Keystore (`authyra_flutter`'s `SecureAuthStorage`), Redis, an encrypted file, or an in-memory store for tests.

**UI-agnostic.** `authyra` has zero Flutter dependency; nothing in the core package imports `flutter_*` or depends on widgets, navigation, or a state-management choice. `authyra_flutter` is the officially supported UI layer, not a hard requirement.

---

## Packages

| Package | Description |
|---|---|
| [`authyra`](packages/authyra) | Core framework: pure Dart, zero Flutter dependency |
| [`authyra_flutter`](packages/authyra_flutter) | Flutter layer: OAuth2, widgets, GoRouter guard |

**Use `authyra` alone** for Dart CLI tools, or for backend contexts (Shelf, Dart Frog) where the runtime-agnostic core is a fit; this path is less exercised in practice than the Flutter one, so treat it as capable rather than battle-tested.
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

The boundary that matters: **providers authenticate, Authyra manages the resulting application session.** Authyra never becomes your identity provider; it normalizes whatever provider you already chose.

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

Plugins observe; they never block anything. A hook that throws is caught and logged internally, not propagated:

```dart
final client = AuthyraClient(
  providers: [...],
  storage: SecureAuthStorage(),
  plugins: [AuditLogPlugin(logger: myLogger)],
);
```

```dart
class AuditLogPlugin extends AuthyraPlugin {
  final Logger _logger;
  AuditLogPlugin({required Logger logger}) : _logger = logger;

  @override String get name => 'audit-log';

  @override
  void install(AuthyraClient client) {}

  @override
  Future<void> onAfterSignIn(AuthSession session) async {
    _logger.info('Signed in: ${session.user.email}');
  }
}
```

For rules that need to *reject* an operation (rate limits, deny lists), override `AuthCallbacks` instead, that's the one mechanism built to gate before an action runs:

```dart
class RateLimitCallbacks extends AuthCallbacks {
  @override
  Future<CallbackResult> onBeforeSignIn(
    String providerId,
    AuthSignInParams? params,
  ) async {
    if (_isRateLimited(providerId)) {
      return const CallbackResult.deny('Too many attempts. Try again later.');
    }
    return const CallbackResult.allow();
  }
}

final client = AuthyraClient(
  providers: [...],
  storage: SecureAuthStorage(),
  callbacks: RateLimitCallbacks(),
);
```

---

## What Authyra is not

- **An identity provider.** No hosted login page, no user database. You bring the provider; Authyra orchestrates it.
- **A replacement for OAuth2/OIDC.** `OAuth2Provider` implements the protocol so you don't have to, but Authyra's job starts once that flow returns a result.
- **A UI kit.** `authyra_flutter` ships a handful of glue widgets (`AuthGuard`, router integration), not a design system.

---

## Known limitations

**Account linking isn't built yet.** Multi-account (several signed-in identities switchable side by side) works today. Linking two providers to the *same* identity (e.g., Google and GitHub for one person) does not: `AuthSession.linkedAccounts` exists as a data structure, but none of the built-in providers merge two sign-ins into one `AuthUser`, each provider's own subject claim becomes the `AuthUser.id`. Two sign-ins via different providers currently register as two separate accounts, not one linked account.

---

## Status

Authyra is experimental, `0.x`. The API may change before `1.0.0`. The `0.x` line is deliberately about proving the `AuthProvider` + `SessionManager` + `AuthStorage` contract is right before growing the provider list further.

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

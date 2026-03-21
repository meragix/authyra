# Audit Technique : Authyra v0.1.0

> Audit réalisé le 2026-03-21. Objectif : évaluer le potentiel d'Authyra à devenir le « Better Auth » de l'écosystème Dart/Flutter.

---

## I. Developer Experience (DX)

### Zero-Config — Partiellement opérationnel

L'initialisation courante :

```dart
final client = AuthyraClient(
  config: AuthConfig(),
  storage: SecureAuthStorage(),
  providers: [GoogleProvider(clientId: '...')],
);
```

C'est propre, mais `client_builder.dart` est **quasi-vide**. Le builder fluent promis (`AuthyraClient.builder().withProvider(...).build()`) n'existe pas encore. L'utilisateur doit toujours instancier manuellement `AuthConfig()` et `SecureAuthStorage()`.

### Règle des trois packages — Partiellement respectée

| Package | Statut |
|---|---|
| `authyra` (core) | ✅ Existe, pur Dart |
| `authyra_flutter` (bundle) | ✅ Existe |
| `authyra_lints` (lints) | ❌ Absent |

---

## II. Modèles et Sécurité des Types

### Points forts

- `AuthUser`, `AuthSession`, `AuthState` utilisent `Equatable` — streams réactifs sans rebuilds parasites.
- `AuthState` comme union discriminée avec `AuthStateType` enum — pattern matching exhaustif possible.
- Sérialisation JSON avec fallbacks backward-compatible dans tous les modèles.

### Problème critique — Absence d'`AuthAccount`

Il n'existe pas de distinction entre :

- `AuthSignInResult` — DTO de transport (tokens bruts depuis le provider)
- `AuthSession` — domaine (session enrichie, persistée)
- `AuthAccount` — identité liée (un user peut avoir N comptes)

`AuthSession` fait actuellement trois choses : stocker les tokens, représenter l'identité, ET gérer les comptes liés (`linkedProviders`). Violation du SRP.

**Modèle manquant :**

```dart
// Actuellement inexistant dans le codebase
class AuthAccount {
  final String id;
  final String userId;             // FK vers AuthUser
  final String providerId;
  final String providerAccountId;
  final Map<String, dynamic> providerMetadata;
}
```

Better Auth/Auth.js ont ce modèle dès le départ. Son absence bloquera le account-linking en v1.0.

---

## III. Architecture

### Noyau pur Dart — ✅ Respecté

`packages/authyra/pubspec.yaml` ne dépend pas de Flutter. Seules dépendances core : `equatable` et `dart_jsonwebtoken`. Solide.

### Séparation `src/` vs public — ✅ Correcte

Tous les internals sous `lib/src/`. Exports publics via `lib/authyra.dart`. Barrel file propre.

### Problème : `AuthyraLogging` mixin — Couplage implicite

Le mixin [packages/authyra/lib/src/internal/logger.dart](packages/authyra/lib/src/internal/logger.dart) est inclus via `with AuthyraLogging` dans plusieurs classes de session. Le logger statique global (`AuthyraLogger`) coexiste avec le mixin — deux patterns pour la même chose.

### Problème : Token Refresher non câblé

`token_refresher.dart` existe dans `session/` mais son intégration dans `AuthyraClient` est floue. Le `TokenRefreshCallback` a été **supprimé** (git status : `D packages/authyra/lib/src/core/token_refresh_callback.dart`) sans remplacement visible. Le flux d'auto-refresh est cassé.

### Problème : `AuthEventBus` singleton global

```dart
// auth_event_bus.dart
static final AuthEventBus _instance = AuthEventBus._internal();
static AuthEventBus get instance => _instance;
```

Un singleton global dans une librairie est une mauvaise pratique. Tests d'isolation impossibles, plusieurs instances de `AuthyraClient` impossibles.

---

## IV. Extensibilité

### Ajouter un provider — ✅ Simple

```dart
class MyCustomProvider extends AuthProvider {
  @override String get id => 'my_provider';
  @override AuthProviderType get type => AuthProviderType.oauth2;
  @override
  Future<AuthSignInResult> signIn(Map<String, dynamic> params) async { ... }
}
```

Interface `AuthProvider` minimaliste et correcte. La signature `signIn(Map<String, dynamic>)` est flexible mais **non typée**.

### Ajouter un adaptateur de stockage — ✅ Simple

`AuthStorage` est une interface claire. `InMemoryStorage` sert de référence. Redis, Hive, SharedPreferences — tout s'adapte en ~50 lignes.

### Ce qui manque pour une extensibilité de niveau Better Auth

- Middleware pipeline (pas de hook `onRequest`/`onResponse` HTTP)
- Plugin system (`Better Auth` a `createPlugin()`)
- Database adapter abstraction (côté serveur)

---

## V. Analyse des Écarts : Authyra vs Better Auth

| Fonctionnalité | Better Auth | Authyra v0.1.0 | Priorité |
|---|:---:|:---:|---|
| Core framework-agnostic | ✅ | ✅ | — |
| Multi-provider | ✅ | ✅ | — |
| Session management | ✅ | ✅ | — |
| Multi-account (switching) | ✅ | ✅ | — |
| PKCE OAuth2 | ✅ | ✅ | — |
| Event system | ✅ | ✅ | — |
| Pre-action callbacks | ✅ | ⚠️ Partiel | Stacking manquant |
| `AuthAccount` model | ✅ | ❌ | **Critique** |
| Plugin/extension system | ✅ | ❌ | **Critique** |
| Auto-refresh end-to-end | ✅ | ❌ Cassé | **Critique** |
| Server-side middleware hooks | ✅ | ❌ | **Critique** |
| Session metadata (IP, UA, device) | ✅ | ❌ | **Critique** |
| Magic link / OTP providers | ✅ | ❌ | Important |
| Typed provider params | ✅ | ❌ `Map<String,dynamic>` | Important |
| Unified error handling | ✅ | ⚠️ Exceptions only | Important |
| Zero-config defaults | ✅ | ⚠️ Partiel | Builder vide |
| Test coverage | ✅ >80% | ❌ 0% | **Bloquant** |
| `authyra_lints` package | N/A | ❌ | DX |
| Passkey / WebAuthn | ✅ | ❌ | v2.0 |
| Organization / tenant support | ✅ | ❌ | v2.0 |
| Rate limiting built-in | ✅ | ❌ | v2.0 |

---

## VI. Les 3 Principaux Risques Architecturaux

### Risque 1 — `AuthEventBus` singleton global _(Sévérité : Haute)_

**Symptôme :** `AuthEventBus.instance` est statique. Toute instance de `AuthyraClient` partage le même bus.

**Conséquence :** Tests non isolables, deux clients dans la même app impossible, events qui se propagent à des listeners non concernés.

**Fix :** `AuthEventBus` instancié par `AuthyraClient`, injecté dans `SessionManager`. Le singleton disparaît.

---

### Risque 2 — `AuthSignInResult` non typé bloque l'extensibilité _(Sévérité : Haute)_

**Symptôme :** `AuthProvider.signIn(Map<String, dynamic>)` sans contrat fort. Les données provider-spécifiques s'accumulent dans `AuthUser.metadata`.

**Conséquence :** Quand on ajoutera le account-linking, on ne sait pas où stocker `provider_account_id`, `access_token scope`, `refresh_token_expires_at`. Redesign breaking inévitable en v1.0.

**Fix :** Introduire `AuthAccount`. `AuthSignInResult` retourne `(user: AuthUser, account: AuthAccount, tokens: AuthTokenResult?)`.

---

### Risque 3 — Auto-refresh non câblé end-to-end _(Sévérité : Moyenne-Haute)_

**Symptôme :** `token_refresher.dart` existe, `AuthConfig.autoRefresh = true` par défaut, mais `TokenRefreshCallback` a été supprimé sans remplacement documenté.

**Conséquence :** En production, les sessions expirent silencieusement. Régression UX/sécurité critique.

**Fix :** Définir explicitement qui déclenche le refresh (`SessionManager` sur `shouldRefresh()` lors de `getSession()`) et rétablir le pipeline complet jusqu'à l'émission du `TokenRefreshEvent`.

---

## VII. Feuille de Route v1.0.0 — Axée Extensibilité

### Phase 1 — Fondations stables _(Bloquant — faire en premier)_

#### 1.1 — Corriger l'auto-refresh end-to-end

- [ ] `SessionManager.getSession()` vérifie `session.shouldRefresh()`
- [ ] Appel à `provider.refreshToken(refreshToken)`
- [ ] Session mise à jour et persistée
- [ ] Émission de `TokenRefreshEvent`
- [ ] Émission de `SessionExpiredEvent` si refresh impossible

#### 1.2 — Supprimer le singleton `AuthEventBus`

- [ ] Retirer `static final AuthEventBus _instance`
- [ ] `AuthyraClient` instancie son propre `AuthEventBus`
- [ ] `AuthEventBus` injecté dans `SessionManager` via constructeur
- [ ] Tests : vérifier l'isolation entre deux instances client

#### 1.3 — Tests : atteindre 70% de coverage minimum

Priorité d'implémentation :

1. `SessionRegistry` (logique pure, facile à tester)
2. `InMemoryStorage`
3. `CredentialsProvider`
4. `AuthyraClient` (flows signIn/signOut)
5. `SessionManager` (avec mock storage)

---

### Phase 2 — Modèles de domaine complets

#### 2.1 — Introduire `AuthAccount`

```dart
class AuthAccount extends Equatable {
  final String id;
  final String userId;
  final String providerId;
  final String providerAccountId;  // ex: Google sub, GitHub login
  final String? accessToken;
  final String? refreshToken;
  final DateTime? tokenExpiresAt;
  final Map<String, dynamic> providerData;
}
```

- [ ] Créer `AuthAccount` dans `models/`
- [ ] Modifier `AuthSignInResult` pour inclure `AuthAccount`
- [ ] Migrer `AuthSession.linkedProviders` vers `List<AuthAccount>`
- [ ] Mettre à jour `SessionManager` pour persister les accounts

#### 2.2 — Session Metadata

```dart
class SessionMetadata {
  final String? ipAddress;
  final String? userAgent;
  final String? deviceId;
  final String? country;
}
```

- [ ] Ajouter `SessionMetadata` à `AuthSession`
- [ ] Alimenter depuis les callbacks `onBeforeSessionCreate`

#### 2.3 — Typed provider params

```dart
abstract class AuthSignInParams const {}

class CredentialsSignInParams extends AuthSignInParams {
  final String email;
  final String password;
  const CredentialsSignInParams({required this.email, required this.password});
}

class OAuth2SignInParams extends AuthSignInParams {
  final String? redirectUri;
  final List<String>? scopes;
}
```

- [ ] Créer la hiérarchie `AuthSignInParams` dans `interfaces/`
- [ ] Migrer `AuthProvider.signIn(Map)` → `AuthProvider.signIn(AuthSignInParams)`
- [ ] Mettre à jour tous les providers existants

---

### Phase 3 — Plugin System

#### 3.1 — Interface `AuthyraPlugin`

```dart
abstract class AuthyraPlugin {
  String get name;
  void install(AuthyraClient client);

  // Hooks optionnels — défaut no-op
  Future<CallbackResult> onBeforeSignIn(
    String providerId, AuthSignInParams params,
  ) async => CallbackResult.allow();

  Future<void> onAfterSignIn(AuthSession session) async {}
  Future<void> onSessionExpired(AuthSession session) async {}
  Future<void> onTokenRefreshed(AuthSession session) async {}
}
```

#### 3.2 — Registration dans `AuthyraClient`

```dart
AuthyraClient(
  plugins: [
    RateLimitPlugin(maxAttempts: 5, window: Duration(minutes: 15)),
    AuditLogPlugin(logger: myLogger),
  ],
);
```

#### 3.3 — Middleware HTTP pour providers OAuth2

- [ ] Exposer `List<Interceptor>` dans `OAuth2Config`
- [ ] `OAuth2Provider` les enregistre sur son instance Dio
- [ ] Permet l'injection de headers custom, logging, retry

---

### Phase 4 — DX et packaging

#### 4.1 — Compléter `AuthyraClientBuilder`

```dart
final client = await AuthyraClient.builder()
  .withStorage(SecureAuthStorage())
  .withProvider(GoogleProvider(clientId: '...'))
  .withPlugin(AuditLogPlugin())
  .withConfig(AuthConfig(autoRefresh: true))
  .build();
```

#### 4.2 — Créer `authyra_lints`

Règles prioritaires :

- Interdire `AuthStorage` utilisé sans `initialize()` préalable
- Détecter les providers avec `supportsRefresh = true` sans `refreshToken()` override
- Détecter les appels à `signIn()` sans gestion des `AuthException`

#### 4.3 — `MagicLinkProvider` abstrait dans le core

`AuthProviderType.magicLink` existe sans implémentation :

```dart
abstract class MagicLinkProvider extends AuthProvider {
  @override AuthProviderType get type => AuthProviderType.magicLink;
  Future<void> sendLink(String email);
  Future<AuthSignInResult> verifyToken(String token);
}
```

---

## VIII. Proposition de Valeur Concurrentielle

Firebase Auth = lock-in Firebase. Supabase Auth = lock-in Supabase. Ce sont des SDKs clients pour se connecter à un BaaS, pas des frameworks d'auth extensibles.

**L'angle d'Authyra** : un framework d'auth qui tourne identiquement dans une app Flutter mobile ET dans un serveur Shelf/Dart Frog, avec le même code core. C'est l'espace inexploité dans l'écosystème Dart.

Les deux prérequis non négociables pour réaliser cette vision :

1. **Plugin system** (Phase 3) — pour que la communauté construise des adapters (Redis, Prisma, 2FA, etc.)
2. **`AuthAccount` model** (Phase 2.1) — pour le account-linking multi-provider, fonctionnalité attendue dans tout framework d'auth moderne

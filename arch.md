# Architecture Authyra — Cible v1.0.0

> Document de référence. Tout écart entre ce fichier et le code réel est un bug d'architecture.

---

## Packages

```text
packages/authyra/          ← core pur Dart, zéro dépendance Flutter
packages/authyra_flutter/  ← couche Flutter, dépend de authyra
```

Un dev Flutter importe `authyra_flutter` et obtient tout. Un dev backend importe `authyra` et obtient le core + `CredentialsProvider`. Zéro duplication.

---

## Package `authyra` (core)

```text
packages/authyra/
├── pubspec.yaml
├── lib/
│   ├── authyra.dart                          ← barrel export unique (voir ci-dessous)
│   └── src/
│       │
│       ├── models/                           ← value objects immuables (Equatable)
│       │   ├── auth_user.dart
│       │   ├── auth_session.dart
│       │   ├── auth_state.dart               ← union discriminée: authenticated | unauthenticated | error
│       │   ├── auth_config.dart
│       │   └── auth_token_result.dart        ← résultat d'un refresh (accessToken + refreshToken?)
│       │
│       ├── interfaces/                       ← contrats abstraits, dépendance zéro
│       │   ├── auth_provider.dart            ← interface + AuthSignInResult + AuthSignInParams
│       │   ├── auth_storage.dart             ← interface CRUD async
│       │   └── auth_plugin.dart              ← hooks: onBeforeSignIn, onAfterSignIn, onSessionExpired…
│       │
│       ├── client/                           ← orchestration
│       │   ├── authyra_client.dart           ← stateless, injectable, pas de singleton
│       │   ├── authyra_instance.dart         ← singleton + cache sync + streams réactifs
│       │   └── client_builder.dart           ← builder pattern (API fluente)
│       │
│       ├── session/                          ← lifecycle complet des sessions
│       │   ├── session_manager.dart          ← CRUD + streams + mutex (NE PAS exporter)
│       │   ├── session_registry.dart         ← registre immuable multi-compte (NE PAS exporter)
│       │   ├── account_manager.dart          ← API publique multi-compte (user-facing)
│       │   └── token_refresher.dart          ← logique refresh + retry policy
│       │
│       ├── callbacks/                        ← middleware pre-action (peuvent bloquer via deny())
│       │   ├── auth_callbacks.dart           ← interface: onBeforeSignIn, onBeforeSessionCreate…
│       │   └── callback_result.dart          ← CallbackResult.allow() | CallbackResult.deny(reason)
│       │
│       ├── events/                           ← bus post-action (lecture seule, ne bloquent pas)
│       │   ├── auth_event_bus.dart           ← instancié par AuthyraClient (PAS de singleton global)
│       │   └── auth_events.dart             ← SignInEvent, SignOutEvent, TokenRefreshEvent…
│       │
│       ├── providers/                        ← providers sans dépendance Flutter
│       │   └── credentials/
│       │       ├── credentials_provider.dart ← implémentation email/password
│       │       └── credentials_config.dart   ← config séparée de l'implémentation
│       │
│       ├── storage/
│       │   └── memory_storage.dart           ← InMemoryStorage (tests + server-side)
│       │
│       ├── exceptions/
│       │   └── auth_exceptions.dart          ← hiérarchie complète avec codes
│       │
│       └── internal/                         ← JAMAIS exporté dans authyra.dart
│           ├── async_mutex.dart              ← _AsyncMutex (extrait de session_manager)
│           ├── logger.dart                   ← AuthyraLogger (statique) + AuthyraLogging (mixin)
│           ├── validators.dart
│           ├── jwt_utils.dart
│           └── pkce_utils.dart               ← PKCE pur Dart (SHA256 via dart:crypto), réutilisé par flutter
│
└── test/
    ├── client/
    │   ├── authyra_client_test.dart
    │   └── client_builder_test.dart
    ├── session/
    │   ├── session_manager_test.dart
    │   └── session_registry_test.dart
    ├── providers/
    │   └── credentials_provider_test.dart
    └── models/
        ├── auth_session_test.dart
        └── auth_user_test.dart
```

### Barrel export `lib/authyra.dart`

```dart
// Modèles
export 'src/models/auth_user.dart';
export 'src/models/auth_session.dart';
export 'src/models/auth_state.dart';
export 'src/models/auth_config.dart';
export 'src/models/auth_token_result.dart';

// Interfaces (pour implémentations custom)
export 'src/interfaces/auth_provider.dart';
export 'src/interfaces/auth_storage.dart';
export 'src/interfaces/auth_plugin.dart';

// Client
export 'src/client/authyra_client.dart';
export 'src/client/authyra_instance.dart';
export 'src/client/client_builder.dart';

// API publique session
export 'src/session/account_manager.dart';

// Callbacks + Events (API publique)
export 'src/callbacks/auth_callbacks.dart';
export 'src/callbacks/callback_result.dart';
export 'src/events/auth_events.dart';
// NE PAS exporter auth_event_bus.dart (instancié en interne par AuthyraClient)

// Providers pur Dart
export 'src/providers/credentials/credentials_provider.dart';
export 'src/providers/credentials/credentials_config.dart';

// Storage
export 'src/storage/memory_storage.dart';

// Exceptions
export 'src/exceptions/auth_exceptions.dart';

// NE PAS exporter :
//   src/internal/*          ← internals
//   src/session/session_manager.dart
//   src/session/session_registry.dart
//   src/session/token_refresher.dart
//   lib/logging.dart        ← supprimé (second barrel inutile)
```

---

## Package `authyra_flutter`

```text
packages/authyra_flutter/
├── pubspec.yaml
├── lib/
│   ├── authyra_flutter.dart                  ← barrel export unique (re-exporte authyra en entier)
│   └── src/
│       │
│       ├── providers/                        ← providers avec dépendances Flutter/platform
│       │   │
│       │   ├── oauth2/                       ← base OAuth2 générique (url_launcher + PKCE)
│       │   │   ├── oauth2_provider.dart
│       │   │   ├── oauth2_config.dart
│       │   │   └── oauth2_callback_handler.dart   ← deep-link receiver (nom unifié)
│       │   │
│       │   ├── google/
│       │   │   ├── google_provider.dart
│       │   │   └── google_config.dart
│       │   │
│       │   ├── apple/
│       │   │   ├── apple_provider.dart
│       │   │   └── apple_config.dart
│       │   │
│       │   ├── github/
│       │   │   ├── github_provider.dart
│       │   │   └── github_config.dart
│       │   │
│       │   └── proxy/
│       │       ├── proxy_oauth_provider.dart
│       │       └── proxy_oauth_config.dart
│       │
│       ├── storage/
│       │   └── secure_storage.dart           ← flutter_secure_storage (Keychain/Keystore/DPAPI)
│       │
│       ├── binding/                          ← pont Flutter lifecycle ↔ AuthyraClient
│       │   ├── authyra_app_binding.dart      ← WidgetsBindingObserver: pause refresh en background
│       │   └── authyra_router_guard.dart     ← redirect GoRouter / auto_route selon AuthState
│       │
│       ├── extensions/
│       │   └── context_extensions.dart       ← context.auth, context.isAuthenticated, context.activeSession
│       │
│       ├── logging/
│       │   └── authyra_flutter_logging.dart  ← useFlutterDefaults(), useProductionDefaults()
│       │
│       └── ui/
│           ├── widgets/
│           │   ├── authyra_scope.dart        ← InheritedWidget, point d'entrée de l'arbre
│           │   ├── authyra_builder.dart      ← rebuild réactif sur changement de session
│           │   ├── auth_state_builder.dart   ← builder léger basé sur le stream
│           │   ├── require_auth.dart         ← gate: affiche fallback si non authentifié
│           │   └── require_role.dart         ← gate: affiche fallback si rôle manquant
│           ├── guards/
│           │   ├── authyra_guard.dart        ← redirect si non authentifié
│           │   ├── authyra_inverse_guard.dart← redirect si authentifié (ex: page login)
│           │   └── authyra_guard_config.dart ← routes de redirect configurables
│           └── navigation/
│               ├── authyra_router.dart       ← intégration GoRouter
│               └── authyra_navigation_observer.dart
│
└── test/
    ├── providers/
    │   ├── google_provider_test.dart
    │   └── oauth2_provider_test.dart
    └── ui/
        └── require_auth_test.dart
```

### Barrel export `lib/authyra_flutter.dart`

```dart
// Core complet (un seul import suffit pour tout)
export 'package:authyra/authyra.dart';

// Providers OAuth2
export 'src/providers/oauth2/oauth2_provider.dart';
export 'src/providers/oauth2/oauth2_config.dart';
export 'src/providers/oauth2/oauth2_callback_handler.dart';
export 'src/providers/google/google_provider.dart';
export 'src/providers/google/google_config.dart';
export 'src/providers/apple/apple_provider.dart';
export 'src/providers/apple/apple_config.dart';
export 'src/providers/github/github_provider.dart';
export 'src/providers/github/github_config.dart';
export 'src/providers/proxy/proxy_oauth_provider.dart';
export 'src/providers/proxy/proxy_oauth_config.dart';

// Storage
export 'src/storage/secure_storage.dart';

// Binding
export 'src/binding/authyra_app_binding.dart';
export 'src/binding/authyra_router_guard.dart';

// Extensions
export 'src/extensions/context_extensions.dart';

// Logging
export 'src/logging/authyra_flutter_logging.dart';

// UI
export 'src/ui/widgets/authyra_scope.dart';
export 'src/ui/widgets/authyra_builder.dart';
export 'src/ui/widgets/auth_state_builder.dart';
export 'src/ui/widgets/require_auth.dart';
export 'src/ui/widgets/require_role.dart';
export 'src/ui/guards/authyra_guard.dart';
export 'src/ui/guards/authyra_inverse_guard.dart';
export 'src/ui/guards/authyra_guard_config.dart';
export 'src/ui/navigation/authyra_router.dart';
export 'src/ui/navigation/authyra_navigation_observer.dart';

// NE PAS exporter :
//   src/utils/jwt_utils.dart  ← supprimé (doublon de authyra/internal/jwt_utils.dart)
```

---

## Règles d'architecture (non négociables)

### Couche / dépendances

```text
authyra (core)
  └── equatable, dart_jsonwebtoken          ← aucune dépendance Flutter

authyra_flutter
  ├── authyra                               ← dépend du core
  ├── flutter, flutter_secure_storage       ← storage natif
  ├── dio, url_launcher                     ← OAuth2 browser flow
  └── crypto                               ← PKCE code_challenge (si pkce_utils non migré)
```

### Ce qui ne doit JAMAIS arriver

| Violation | Raison |
|---|---|
| Import `flutter` dans `authyra/` | Casse la compatibilité backend/CLI |
| Export de `session_manager.dart` | Interne — l'API publique passe par `account_manager.dart` |
| Export de `internal/*` | Internals non stables, non contractuels |
| Singleton statique dans `AuthEventBus` | Impossible à tester, impossible à multi-instancier |
| Duplication de `jwt_utils.dart` dans flutter | Le core l'expose déjà via `internal/` |
| Deux barrels dans le core (`logging.dart`) | Un seul point d'entrée : `authyra.dart` |
| `pkce_utils` uniquement dans flutter | PKCE est pur Dart — appartient au core `internal/` |

### Séparation callbacks vs events

```text
callbacks/   ← AVANT l'action  → peuvent retourner deny() → bloquent l'opération
events/      ← APRÈS l'action  → lecture seule → n'influencent pas le résultat
```

### Où vivent les providers

```text
authyra/providers/credentials/   ← pur Dart, pas de browser, pas de platform channel
authyra_flutter/providers/       ← nécessite url_launcher, deep-link, platform APIs
```

---

## Points d'entrée selon la plateforme

```dart
// Flutter app — UN seul import, accès à tout
import 'package:authyra_flutter/authyra_flutter.dart';

// Dart backend (Shelf, Dart Frog) — core uniquement
import 'package:authyra/authyra.dart';
```

---

## Delta entre arch.md et code actuel (à corriger)

| Écart | Action |
|---|---|
| `interfaces/auth_plugin.dart` absent | Créer |
| `providers/credentials/credentials_config.dart` absent | Créer |
| `internal/async_mutex.dart` absent (embedé dans session_manager) | Extraire |
| `internal/pkce_utils.dart` absent (PKCE dans flutter seulement) | Migrer du flutter vers le core |
| `binding/` absent dans flutter | Créer `authyra_app_binding.dart` + `authyra_router_guard.dart` |
| Providers flutter dans `oauth2/prebuilt/google/` | Aplatir vers `providers/google/` |
| `oauth2_callback_handle.dart` (mauvais nom) | Renommer en `oauth2_callback_handler.dart` |
| `github.dart` (pas de nom explicite) | Renommer en `github_provider.dart` |
| `authyra_flutter/src/utils/jwt_utils.dart` doublon | Supprimer |
| `lib/logging.dart` second barrel | Supprimer, fusionner dans `authyra.dart` si nécessaire |

packages/authyra/
├── pubspec.yaml
├── lib/
│   ├── authyra.dart                          ← barrel export unique
│   └── src/
│       │
│       ├── models/                           ← value objects immuables
│       │   ├── auth_user.dart
│       │   ├── auth_session.dart
│       │   ├── auth_state.dart
│       │   ├── auth_config.dart
│       │   └── auth_token_result.dart        ← résultat de refresh
│       │
│       ├── interfaces/                       ← contrats abstraits
│       │   ├── auth_provider.dart            ← interface + AuthSignInResult
│       │   ├── auth_storage.dart             ← interface CRUD
│       │   └── auth_plugin.dart              ← hooks: onSignIn, onSignOut…
│       │
│       ├── client/                           ← orchestration
│       │   ├── authyra_client.dart           ← stateless, injectable
│       │   ├── authyra_instance.dart         ← singleton + cache sync
│       │   └── client_builder.dart           ← builder pattern (fluent API)
│       │
│       ├── session/                          ← tout le lifecycle session
│       │   ├── session_manager.dart          ← CRUD + streams + mutex
│       │   ├── session_registry.dart         ← registre immuable (≠ models/)
│       │   ├── account_manager.dart          ← API multi-compte (user-facing)
│       │   └── token_refresher.dart          ← logique refresh + retry policy
│       │
│       ├── providers/                        ← providers SANS dépendance Flutter
│       │   └── credentials/
│       │       ├── credentials_provider.dart ← implémentation email/password
│       │       └── credentials_config.dart
│       │
│       ├── exceptions/
│       │   └── auth_exceptions.dart          ← hiérarchie complète
│       │
│       └── internal/                         ← JAMAIS exporté
│           ├── async_mutex.dart
│           ├── logger.dart
│           ├── validators.dart
│           ├── jwt_utils.dart
│           └── pkce_utils.dart               ← PKCE pur Dart (réutilisé par Flutter)
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


packages/authyra_flutter/
├── pubspec.yaml                              ← depend: authyra, flutter, url_launcher…
├── lib/
│   ├── authyra_flutter.dart                 ← barrel export unique (re-exporte aussi authyra)
│   └── src/
│       │
│       ├── providers/                        ← providers avec dépendances Flutter/platform
│       │   │
│       │   ├── oauth2/                       ← base OAuth2 (url_launcher + callback)
│       │   │   ├── oauth2_provider.dart      ← implémentation générique + PKCE
│       │   │   ├── oauth2_config.dart
│       │   │   └── oauth2_callback_handler.dart
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
│       │   └── secure_storage.dart           ← implémentation flutter_secure_storage
│       │
│       ├── binding/                          ← pont Flutter lifecycle ↔ AuthyraClient
│       │   ├── authyra_app_binding.dart      ← WidgetsBindingObserver (pause refresh en background)
│       │   └── authyra_router_guard.dart     ← redirect GoRouter / auto_route
│       │
│       └── widgets/
│           ├── auth_guard.dart               ← gate basée sur AuthState
│           └── auth_builder.dart             ← builder réactif (stream-based)
│
└── test/
    ├── providers/
    │   ├── google_provider_test.dart
    │   └── oauth2_provider_test.dart
    └── widgets/
        └── auth_guard_test.dart

Couche            Package              Raison
─────────────────────────────────────────────────────
Interface         authyra/interfaces/  Contrat abstrait → dépendance zéro
Implémentation    authyra/providers/   Dart pur → utilisable backend + Flutter
Config            authyra/providers/   Idem
Re-export         authyra_flutter.dart Transparent via barrel (voir ci-dessous)

Un dev Flutter importe authyra_flutter et obtient CredentialsProvider sans y penser. Un dev backend importe authyra et l'obtient aussi. Zéro duplication.

// Modèles
export 'src/models/auth_user.dart';
export 'src/models/auth_session.dart';
export 'src/models/auth_state.dart';
export 'src/models/auth_config.dart';

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

// Provider pur Dart
export 'src/providers/credentials/credentials_provider.dart';

// Exceptions
export 'src/exceptions/auth_exceptions.dart';

// NE PAS exporter : src/internal/*, src/session/session_manager.

// ← Un seul import suffit pour TOUT
export 'package:authyra/authyra.dart';

// Providers OAuth2 (Flutter-specific)
export 'src/providers/oauth2/oauth2_provider.dart';
export 'src/providers/google/google_provider.dart';
export 'src/providers/apple/apple_provider.dart';
export 'src/providers/github/github_provider.dart';
export 'src/providers/proxy/proxy_oauth_provider.dart';
export 'src/providers/proxy/proxy_oauth_config.dart';

// Storage
export 'src/storage/secure_storage.dart';

// Widgets
export 'src/widgets/auth_guard.dart';
export 'src/widgets/auth_builder.dart';

// Binding
export 'src/binding/authyra_app_binding.dart';
export 'src/binding/authyra_router_guard.dart';


// Flutter app — UN seul import, accès à tout
import 'package:authyra_flutter/authyra_flutter.dart';

// Dart backend — UN seul import, accès au core + CredentialsProvider
import 'package:authyra/authyra.dart';

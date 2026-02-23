
/// Authyra — Pure Authentication Logic Framework
///
/// Works on any Dart platform:
/// - Flutter (iOS, Android, Web, Desktop)
/// - Dart CLI / scripts
/// - Backend (Shelf, Dart Frog)
library;

import 'src/core/authyra_instance.dart';

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------
export 'src/models/auth_user.dart';
export 'src/models/auth_session.dart';
export 'src/models/auth_state.dart';
export 'src/models/auth_config.dart';

// ---------------------------------------------------------------------------
// Core
// ---------------------------------------------------------------------------
export 'src/core/authyra_client.dart';
export 'src/core/authyra_instance.dart';
export 'src/core/session/account_manager.dart';

// ---------------------------------------------------------------------------
// Provider base + result types
// ---------------------------------------------------------------------------
export 'src/providers/auth_provider.dart'
    show AuthProvider, AuthProviderType, AuthSignInResult, AuthTokenResult;

// ---------------------------------------------------------------------------
// Built-in providers
// ---------------------------------------------------------------------------
export 'src/providers/credentials/credentials_provider.dart';
export 'src/providers/oauth2/oauth2_provider.dart';
export 'src/providers/oauth2/prebuilt/google.dart';
export 'src/providers/oauth2/prebuilt/github.dart';
export 'src/providers/proxy_oauth/proxy_oauth_config.dart'
    show ProxyOAuthConfig;
export 'src/providers/proxy_oauth/proxy_oauth_provider.dart'
    show ProxyOAuthProvider;

// ---------------------------------------------------------------------------
// Storage interface
// ---------------------------------------------------------------------------
export 'src/storage/auth_storage.dart';

// ---------------------------------------------------------------------------
// OAuth2 callback helper
// ---------------------------------------------------------------------------
export 'src/providers/oauth2/oauth2_callback_handle.dart';

// ---------------------------------------------------------------------------
// Convenience alias
// ---------------------------------------------------------------------------

/// Short alias for [AuthyraInstance].
///
/// ```dart
/// await Authyra.initialize(client: client);
/// Authyra.instance.signIn('google');
/// ```
typedef Authyra = AuthyraInstance;

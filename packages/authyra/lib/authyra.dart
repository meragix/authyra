
/// Authyra — Pure Authentication Logic Framework
///
/// Works on any Dart platform:
/// - Flutter (iOS, Android, Web, Desktop)
/// - Dart CLI / scripts
/// - Backend (Shelf, Dart Frog)
library;

import 'src/client/authyra_instance.dart';

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
export 'src/client/authyra_client.dart';
export 'src/client/authyra_instance.dart';
export 'src/session/account_manager.dart';
export 'src/exceptions/auth_exceptions.dart';

// ---------------------------------------------------------------------------
// Provider base + result types
// ---------------------------------------------------------------------------
export 'src/interfaces/auth_provider.dart'
    show AuthProvider, AuthProviderType, AuthSignInResult, AuthTokenResult;

// ---------------------------------------------------------------------------
// Built-in providers
// ---------------------------------------------------------------------------
export 'src/providers/credentials/credentials_provider.dart';

// ---------------------------------------------------------------------------
// Storage interface
// ---------------------------------------------------------------------------
export 'src/interfaces/auth_storage.dart';

// ---------------------------------------------------------------------------
// OAuth2 callback helper
// ---------------------------------------------------------------------------
//export '../../authyra_flutter/lib/src/providers/oauth2/oauth2_callback_handle.dart';

// ---------------------------------------------------------------------------
// Internal
// ---------------------------------------------------------------------------
export 'src/internal/jwt_utils.dart';
export 'src/internal/logger.dart';

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

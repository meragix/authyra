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
export 'src/models/auth_token_result.dart';
export 'src/models/auth_sign_in_result.dart';
export 'src/models/auth_account.dart';
export 'src/models/session_metadata.dart';

// ---------------------------------------------------------------------------
// Interfaces (for custom implementations)
// ---------------------------------------------------------------------------
export 'src/interfaces/auth_provider.dart';
export 'src/interfaces/auth_storage.dart';
export 'src/interfaces/auth_sign_in_params.dart';

// ---------------------------------------------------------------------------
// Client
// ---------------------------------------------------------------------------
export 'src/client/authyra_client.dart';
export 'src/client/authyra_instance.dart';
export 'src/client/authyra_client_builder.dart';

// ---------------------------------------------------------------------------
// Session — public API only (SessionManager internals are never exported)
// ---------------------------------------------------------------------------
export 'src/session/account_manager.dart';

// ---------------------------------------------------------------------------
// Built-in providers
// ---------------------------------------------------------------------------
export 'src/providers/credentials/credentials_provider.dart';

// ---------------------------------------------------------------------------
// Exceptions
// ---------------------------------------------------------------------------
export 'src/exceptions/auth_exceptions.dart';

// ---------------------------------------------------------------------------
// Storage — interface + built-in implementations
// ---------------------------------------------------------------------------
export 'src/storage/memory_storage.dart';

// ---------------------------------------------------------------------------
// Events
// ---------------------------------------------------------------------------
export 'src/events/auth_event_bus.dart';
export 'src/events/auth_events.dart';

// ---------------------------------------------------------------------------
// Callbacks
// ---------------------------------------------------------------------------
export 'src/callbacks/auth_callbacks.dart';
export 'src/callbacks/callback_result.dart';

// ---------------------------------------------------------------------------
// Plugins
// ---------------------------------------------------------------------------
export 'src/plugins/auth_plugin.dart';

// ---------------------------------------------------------------------------
// Convenience alias
// ---------------------------------------------------------------------------

/// Short alias for [AuthyraInstance].
///
/// ```dart
/// await Authyra.initialize(client: client);
/// Authyra.instance.signIn('google', params: OAuth2SignInParams(code: '...'));
/// ```
typedef Authyra = AuthyraInstance;

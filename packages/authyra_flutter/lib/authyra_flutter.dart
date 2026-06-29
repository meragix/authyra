/// authyra_flutter — Flutter layer for Authyra.
///
/// Re-exports the entire `authyra` core and adds:
/// - OAuth2 providers (Google, GitHub, Apple, generic OAuth2, proxy)
/// - [SecureAuthStorage] backed by `flutter_secure_storage`
/// - [OAuth2CallbackHandler] deep-link router
/// - [AuthyraFlutterLogging] for Flutter-specific log configuration
///
/// Flutter apps need only one import:
///
/// ```dart
/// import 'package:authyra_flutter/authyra_flutter.dart';
/// ```
library;

// ---------------------------------------------------------------------------
// Core (re-export everything from authyra)
// ---------------------------------------------------------------------------
export 'package:authyra/authyra.dart';

// ---------------------------------------------------------------------------
// OAuth2 — base provider + config
// ---------------------------------------------------------------------------
export 'src/providers/oauth2/oauth2_provider.dart';
export 'src/providers/oauth2/oauth2_config.dart';
export 'src/providers/oauth2/oauth2_callback_handle.dart';

// ---------------------------------------------------------------------------
// OAuth2 — prebuilt providers
// ---------------------------------------------------------------------------
export 'src/providers/oauth2/prebuilt/google/google.dart';
export 'src/providers/oauth2/prebuilt/github/github.dart';
export 'src/providers/apple/apple_provider.dart';
export 'src/providers/apple/apple_config.dart';
export 'src/providers/proxy/proxy_oauth_provider.dart';
export 'src/providers/proxy/proxy_oauth_config.dart';

// ---------------------------------------------------------------------------
// Storage
// ---------------------------------------------------------------------------
export 'src/storage/secure_storage.dart';

// ---------------------------------------------------------------------------
// Logging
// ---------------------------------------------------------------------------
export 'src/logging/authyra_flutter_logging.dart';

// ---------------------------------------------------------------------------
// Widgets (coming in a future release)
// ---------------------------------------------------------------------------
// export 'src/widgets/auth_guard.dart';
// export 'src/widgets/auth_builder.dart';

// ---------------------------------------------------------------------------
// Binding (coming in a future release)
// ---------------------------------------------------------------------------
// export 'src/binding/authyra_app_binding.dart';
// export 'src/binding/authyra_router_guard.dart';

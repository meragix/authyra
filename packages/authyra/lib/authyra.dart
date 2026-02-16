
/// Authyra - Pure Authentication Logic Framework
/// 
/// This is the core library that works on any Dart platform:
/// - Flutter (iOS, Android, Web, Desktop)
/// - Dart CLI
/// - Backend (Shelf, Dart Frog)
/// - Scripts
library;

import 'src/core/authyra_instance.dart';

// Models
export 'src/models/auth_user.dart';
export 'src/models/auth_state.dart';

// Core
export 'src/core/authyra_client.dart';
export 'src/core/authyra_instance.dart';

// Providers
export 'src/providers/credentials/credentials_provider.dart';
export 'src/providers/oauth2/prebuilt/google.dart';
export 'src/providers/proxy_oauth/proxy_oauth_provider.dart';

// Storage
export 'src/storage/auth_storage.dart';

// Callback
export 'src/providers/oauth2/oauth2_callback_handle.dart';

// Alias ​​for short access
typedef Authyra = AuthyraInstance;
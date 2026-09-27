/// authyra_apple, native Sign in with Apple provider for Authyra.
///
/// Adds [AppleProvider], built on `sign_in_with_apple`, on top of the core
/// `authyra` package. Import this alongside `authyra` or `authyra_flutter`:
///
/// ```dart
/// import 'package:authyra/authyra.dart';
/// import 'package:authyra_apple/authyra_apple.dart';
/// ```
library;

export 'package:sign_in_with_apple/sign_in_with_apple.dart'
    show AppleIDAuthorizationScopes, WebAuthenticationOptions;

export 'src/apple_provider.dart';

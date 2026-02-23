/// Secondary library exposing Authyra's logging infrastructure.
///
/// Import this if you need to configure [AuthyraLogger], implement a custom
/// log handler, or use the [AuthyraLogging] mixin in your own [AuthProvider]
/// implementation.
///
/// ```dart
/// import 'package:authyra/logging.dart';
///
/// AuthyraLogger.configure(LoggerConfig(
///   enabled: true,
///   minLevel: LogLevel.warning,
///   customLogger: (message, level) => myTracer.log(message),
/// ));
/// ```
///
/// Flutter apps should prefer `AuthyraFlutterLogging` from `authyra_flutter`,
/// which wraps this library with Flutter-specific presets.
library;

export 'src/internal/logger.dart';

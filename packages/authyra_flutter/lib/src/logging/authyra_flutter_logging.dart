import 'package:authyra/logging.dart';
import 'package:flutter/foundation.dart';

// Re-export core types so Flutter apps only need one import.
export 'package:authyra/logging.dart'
    show AuthyraLogger, AuthyraLogging, LogLevel, LoggerConfig;

/// Flutter-specific logging configuration for Authyra.
///
/// [AuthyraFlutterLogging] wraps the core [AuthyraLogger] and adds:
/// - [useFlutterDefaults] — `debugPrint` in debug/profile mode, silent in release
/// - [useProductionDefaults] — errors only, no timestamps
/// - Direct delegates to [AuthyraLogger] for fine-grained control
///
/// ## Recommended setup (in `main()`)
///
/// ```dart
/// Future<void> main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///
///   // Configure once before Authyra.initialize
///   AuthyraFlutterLogging.useFlutterDefaults();
///
///   await Authyra.initialize(...);
///   runApp(const MyApp());
/// }
/// ```
///
/// ## Custom configuration
///
/// ```dart
/// AuthyraFlutterLogging.configure(
///   LoggerConfig(
///     enabled: true,
///     minLevel: LogLevel.warning,
///     showTimestamp: false,
///     showEmoji: false,
///     customLogger: (message, level) => myAnalytics.log(message),
///   ),
/// );
/// ```
///
/// ## Disable entirely
///
/// ```dart
/// AuthyraFlutterLogging.disable();
/// ```
///
/// See also:
/// - [AuthyraLogger], the underlying static logger.
/// - [LoggerConfig], the configuration value object.
/// - [LogLevel], the available log levels.
abstract final class AuthyraFlutterLogging {
  AuthyraFlutterLogging._();

  // ---------------------------------------------------------------------------
  // Presets
  // ---------------------------------------------------------------------------

  /// Configures Authyra logging with Flutter-appropriate defaults:
  ///
  /// - **Debug / profile** mode: all levels, `debugPrint` output, emoji + timestamp.
  /// - **Release** mode: logging disabled entirely (no performance overhead).
  ///
  /// Call this once at the top of `main()` before [Authyra.initialize].
  static void useFlutterDefaults() {
    if (kReleaseMode) {
      AuthyraLogger.disable();
      return;
    }

    AuthyraLogger.configure(LoggerConfig(
      enabled: true,
      minLevel: LogLevel.debug,
      showTimestamp: true,
      showEmoji: true,
      customLogger: (message, level) => debugPrint(message),
    ));
  }

  /// Configures Authyra logging for production use:
  ///
  /// - Only [LogLevel.error] messages are emitted.
  /// - No timestamps or emoji (cleaner for log aggregation tools).
  /// - Uses `dart:developer` (the default output).
  ///
  /// Use this if you want error-level visibility in release builds.
  static void useProductionDefaults() {
    AuthyraLogger.configure(const LoggerConfig(
      enabled: true,
      minLevel: LogLevel.error,
      showTimestamp: false,
      showEmoji: false,
    ));
  }

  // ---------------------------------------------------------------------------
  // Direct delegates
  // ---------------------------------------------------------------------------

  /// Applies a fully custom [LoggerConfig].
  ///
  /// ```dart
  /// AuthyraFlutterLogging.configure(
  ///   LoggerConfig(
  ///     enabled: true,
  ///     minLevel: LogLevel.warning,
  ///     customLogger: (msg, level) => Sentry.addBreadcrumb(msg),
  ///   ),
  /// );
  /// ```
  static void configure(LoggerConfig config) => AuthyraLogger.configure(config);

  /// Enables logging (respects the existing [LoggerConfig.minLevel]).
  static void enable() => AuthyraLogger.enable();

  /// Disables all Authyra log output.
  static void disable() => AuthyraLogger.disable();

  /// Sets the minimum log level. Messages below this level are suppressed.
  ///
  /// ```dart
  /// // Show only warnings and errors
  /// AuthyraFlutterLogging.setMinLevel(LogLevel.warning);
  /// ```
  static void setMinLevel(LogLevel level) => AuthyraLogger.setMinLevel(level);
}

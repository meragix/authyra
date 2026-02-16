import 'dart:developer' as dev;

/// Log levels for Authyra
enum LogLevel {
  debug(0, '🔍', 'DEBUG'),
  info(1, 'ℹ️', 'INFO'),
  warning(2, '⚠️', 'WARNING'),
  error(3, '❌', 'ERROR');

  final int value;
  final String emoji;
  final String label;

  const LogLevel(this.value, this.emoji, this.label);
}

/// Logger configuration
class LoggerConfig {
  final bool enabled;
  final LogLevel minLevel;
  final bool showTimestamp;
  final bool showEmoji;
  final void Function(String message, LogLevel level)? customLogger;

  const LoggerConfig({
    this.enabled = true,
    this.minLevel = LogLevel.debug,
    this.showTimestamp = true,
    this.showEmoji = true,
    this.customLogger,
  });

  LoggerConfig copyWith({
    bool? enabled,
    LogLevel? minLevel,
    bool? showTimestamp,
    bool? showEmoji,
    void Function(String message, LogLevel level)? customLogger,
  }) {
    return LoggerConfig(
      enabled: enabled ?? this.enabled,
      minLevel: minLevel ?? this.minLevel,
      showTimestamp: showTimestamp ?? this.showTimestamp,
      showEmoji: showEmoji ?? this.showEmoji,
      customLogger: customLogger ?? this.customLogger,
    );
  }
}

/// Authyra logging utility
class AuthyraLogger {
  static LoggerConfig _config = const LoggerConfig();

  /// Configure the logger
  static void configure(LoggerConfig config) {
    _config = config;
  }

  static void enable() => _config = _config.copyWith(enabled: true);
  static void disable() => _config = _config.copyWith(enabled: false);
  static void setMinLevel(LogLevel level) => _config = _config.copyWith(minLevel: level);

  static void debug(String message, [dynamic data]) => _log(LogLevel.debug, message, data);
  static void info(String message, [dynamic data]) => _log(LogLevel.info, message, data);
  static void warning(String message, [dynamic data]) => _log(LogLevel.warning, message, data);

  /// Log error message
  static void error(String message, [dynamic error, StackTrace? stackTrace]) {
    _log(LogLevel.error, message, error);
    if (stackTrace != null && _config.enabled) {
      _logStackTrace(stackTrace);
    }
  }

  /// Internal logging method
  static void _log(LogLevel level, String message, [dynamic data]) {
    if (!_config.enabled || level.value < _config.minLevel.value) {
      return;
    }

    final buffer = StringBuffer();

    // Timestamp
    if (_config.showTimestamp) {
      final now = DateTime.now();
      buffer.write('[${_formatTimestamp(now)}] ');
    }

    // Emoji and level
    if (_config.showEmoji) buffer.write('${level.emoji} ');
    buffer.write('[${level.label}] ');

    // Message
    buffer.write('[Authyra] $message');

    // Data
    if (data != null) buffer.write(' - ${_formatData(data)}');

    final formattedMessage = buffer.toString();

    // Use custom logger if provided
    if (_config.customLogger != null) {
      _config.customLogger!(formattedMessage, level);
    } else {
      dev.log(
        formattedMessage,
        name: 'authyra',
        level: level.value * 250,
        time: DateTime.now(),
      );
    }
  }

  /// Format timestamp
  static String _formatTimestamp(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}:'
        '${dateTime.second.toString().padLeft(2, '0')}'
        '.${dateTime.millisecond.toString().padLeft(3, '0')}';
  }

  /// Format data
  static String _formatData(dynamic data) {
    if (data is Map) {
      return data.entries.map((e) => '${e.key}: ${e.value}').join(', ');
    }
    return data.toString();
  }

  /// Log stack trace
  static void _logStackTrace(StackTrace stackTrace) {
    if (!_config.enabled) return;
    dev.log(stackTrace.toString(), name: 'authyra.stacktrace');
  }
}

/// Mixin for easy logging in classes
mixin AuthyraLogging {
  void logDebug(String message, [dynamic data]) {
    AuthyraLogger.debug('[$runtimeType] $message', data);
  }

  void logInfo(String message, [dynamic data]) {
    AuthyraLogger.info('[$runtimeType] $message', data);
  }

  void logWarning(String message, [dynamic data]) {
    AuthyraLogger.warning('[$runtimeType] $message', data);
  }

  void logError(String message, [dynamic error, StackTrace? stackTrace]) {
    AuthyraLogger.error('[$runtimeType] $message', error, stackTrace);
  }
}

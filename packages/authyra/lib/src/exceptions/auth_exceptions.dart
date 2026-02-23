/// Base exception class for all Authyra errors
class AuthException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;
  final StackTrace? stackTrace;

  AuthException(
    this.message, {
    this.code,
    this.originalError,
    this.stackTrace,
  });

  @override
  String toString() {
    final buffer = StringBuffer('AuthException: $message');
    if (code != null) buffer.write(' (code: $code)');
    if (originalError != null) buffer.write('\nCaused by: $originalError');
    return buffer.toString();
  }

  /// Convert to JSON for logging or debugging
  Map<String, dynamic> toJson() => {
        'type': runtimeType.toString(),
        'message': message,
        'code': code,
        'originalError': originalError?.toString(),
      };
}

// ==========================================
// Configuration & Initialization Errors
// ==========================================

/// Thrown when Authyra is used before initialization
class NotInitializedException extends AuthException {
  NotInitializedException()
      : super(
          'Authyra has not been initialized. Call Authyra.initialize() first.',
          code: 'NOT_INITIALIZED',
        );
}

/// Thrown when configuration is invalid
class InvalidConfigurationException extends AuthException {
  InvalidConfigurationException(super.message) : super(code: 'INVALID_CONFIG');
}

// ==========================================
// Provider Errors
// ==========================================

/// Thrown when a requested provider is not registered
class ProviderNotFoundException extends AuthException {
  final String providerName;

  ProviderNotFoundException(this.providerName)
      : super(
          'Provider "$providerName" is not registered. '
          'Use Authyra.instance.initialize(client: AuthyraClient(providers: [...])) to register it.',
          code: 'PROVIDER_NOT_FOUND',
        );
}

/// Thrown when a provider is already registered
class ProviderAlreadyRegisteredException extends AuthException {
  final String providerName;

  ProviderAlreadyRegisteredException(this.providerName)
      : super(
          'Provider "$providerName" is already registered.',
          code: 'PROVIDER_ALREADY_EXISTS',
        );
}

/// Thrown when provider configuration is invalid
class InvalidProviderConfigException extends AuthException {
  final String providerName;

  InvalidProviderConfigException(this.providerName, String details)
      : super(
          'Invalid configuration for provider "$providerName": $details',
          code: 'INVALID_PROVIDER_CONFIG',
        );
}

// ==========================================
// Authentication Errors
// ==========================================

/// Thrown when authentication is cancelled by the user
class AuthenticationCancelledException extends AuthException {
  final String? providerName;

  AuthenticationCancelledException([this.providerName])
      : super(
          'Authentication was cancelled by the user'
          '${providerName != null ? ' for provider "$providerName"' : ''}.',
          code: 'AUTH_CANCELLED',
        );
}

/// Thrown when authentication fails
class AuthenticationFailedException extends AuthException {
  final String? providerName;

  AuthenticationFailedException(
    String message, {
    this.providerName,
    dynamic originalError,
  }) : super(
          'Authentication failed${providerName != null ? ' for "$providerName"' : ''}: $message',
          code: 'AUTH_FAILED',
          originalError: originalError,
        );
}

/// Thrown when credentials are invalid
class InvalidCredentialsException extends AuthException {
  InvalidCredentialsException([String? details])
      : super(
          'Invalid credentials${details != null ? ': $details' : ''}',
          code: 'INVALID_CREDENTIALS',
        );
}

/// Thrown when required authentication parameters are missing
class MissingAuthParametersException extends AuthException {
  final List<String> missingParams;

  MissingAuthParametersException(this.missingParams)
      : super(
          'Missing required authentication parameters: ${missingParams.join(', ')}',
          code: 'MISSING_AUTH_PARAMS',
        );
}

// ==========================================
// Session & Token Errors
// ==========================================

/// Thrown when access token has expired
class TokenExpiredException extends AuthException {
  TokenExpiredException([String? details])
      : super(
          'Access token has expired${details != null ? ': $details' : ''}',
          code: 'TOKEN_EXPIRED',
        );
}

/// Thrown when token refresh fails
class TokenRefreshFailedException extends AuthException {
  TokenRefreshFailedException([String? reason, dynamic originalError])
      : super(
          'Failed to refresh access token${reason != null ? ': $reason' : ''}',
          code: 'TOKEN_REFRESH_FAILED',
          originalError: originalError,
        );
}

/// Thrown when token is invalid or malformed
class InvalidTokenException extends AuthException {
  InvalidTokenException([String? details])
      : super(
          'Invalid or malformed token${details != null ? ': $details' : ''}',
          code: 'INVALID_TOKEN',
        );
}

/// Thrown when session is not found
class SessionNotFoundException extends AuthException {
  SessionNotFoundException()
      : super(
          'No active session found. Please sign in first.',
          code: 'SESSION_NOT_FOUND',
        );
}

/// Thrown when session operations fail
class SessionOperationException extends AuthException {
  SessionOperationException(String operation, [dynamic originalError])
      : super(
          'Session operation failed: $operation',
          code: 'SESSION_OPERATION_FAILED',
          originalError: originalError,
        );
}

// ==========================================
// Storage Errors
// ==========================================

/// Thrown when storage operations fail
class StorageException extends AuthException {
  final String operation;

  StorageException(this.operation, [dynamic originalError])
      : super(
          'Storage operation failed: $operation',
          code: 'STORAGE_ERROR',
          originalError: originalError,
        );
}

/// Thrown when storage is not initialized
class StorageNotInitializedException extends AuthException {
  StorageNotInitializedException()
      : super(
          'Storage has not been initialized. Call initialize() first.',
          code: 'STORAGE_NOT_INITIALIZED',
        );
}

/// Thrown when stored data is corrupted
class CorruptedDataException extends AuthException {
  final String key;

  CorruptedDataException(this.key, [dynamic originalError])
      : super(
          'Stored data is corrupted for key: $key',
          code: 'CORRUPTED_DATA',
          originalError: originalError,
        );
}

// ==========================================
// Network Errors
// ==========================================

/// Thrown when network operations fail
class NetworkException extends AuthException {
  final int? statusCode;
  final String? url;

  NetworkException(
    String message, {
    this.statusCode,
    this.url,
    dynamic originalError,
  }) : super(
          'Network error: $message'
          '${statusCode != null ? ' (HTTP $statusCode)' : ''}'
          '${url != null ? ' at $url' : ''}',
          code: 'NETWORK_ERROR',
          originalError: originalError,
        );
}

/// Thrown when request times out
class TimeoutException extends AuthException {
  final Duration timeout;

  TimeoutException(this.timeout)
      : super(
          'Request timed out after ${timeout.inSeconds} seconds',
          code: 'TIMEOUT',
        );
}

/// Thrown when there's no internet connection
class NoInternetException extends AuthException {
  NoInternetException()
      : super(
          'No internet connection available',
          code: 'NO_INTERNET',
        );
}

// ==========================================
// Validation Errors
// ==========================================

/// Thrown when input validation fails
class ValidationException extends AuthException {
  final String field;

  ValidationException(this.field, String reason)
      : super(
          'Validation failed for "$field": $reason',
          code: 'VALIDATION_ERROR',
        );
}

/// Thrown when email format is invalid
class InvalidEmailException extends ValidationException {
  InvalidEmailException(String email)
      : super('email', '"$email" is not a valid email address');
}

/// Thrown when password doesn't meet requirements
class InvalidPasswordException extends ValidationException {
  InvalidPasswordException(String reason) : super('password', reason);
}

// ==========================================
// Account & Multi-Account Errors
// ==========================================

/// Thrown when account is not found
class AccountNotFoundException extends AuthException {
  final String accountId;

  AccountNotFoundException(this.accountId)
      : super(
          'Account with ID "$accountId" not found',
          code: 'ACCOUNT_NOT_FOUND',
        );
}

/// Thrown when trying to add a duplicate account
class DuplicateAccountException extends AuthException {
  final String accountId;

  DuplicateAccountException(this.accountId)
      : super(
          'Account with ID "$accountId" already exists',
          code: 'DUPLICATE_ACCOUNT',
        );
}

// ==========================================
// Backend Linker Errors
// ==========================================

/// Thrown when backend sync operations fail
class BackendSyncException extends AuthException {
  final String operation;

  BackendSyncException(this.operation, [dynamic originalError])
      : super(
          'Backend sync failed for operation: $operation',
          code: 'BACKEND_SYNC_FAILED',
          originalError: originalError,
        );
}

// ==========================================
// Platform Errors
// ==========================================

/// Thrown when platform-specific operation fails
class PlatformException extends AuthException {
  final String platform;

  PlatformException(this.platform, String message, [dynamic originalError])
      : super(
          'Platform error on $platform: $message',
          code: 'PLATFORM_ERROR',
          originalError: originalError,
        );
}

/// Thrown when feature is not supported on current platform
class UnsupportedPlatformException extends AuthException {
  final String feature;
  final String platform;

  UnsupportedPlatformException(this.feature, this.platform)
      : super(
          'Feature "$feature" is not supported on $platform',
          code: 'UNSUPPORTED_PLATFORM',
        );
}

// ==========================================
// Error Handler Utility
// ==========================================

/// Utility class to handle and categorize errors
class AuthyraErrorHandler {
  /// Convert any error to AuthException
  static AuthException handleError(dynamic error, [StackTrace? stackTrace]) {
    if (error is AuthException) {
      return error;
    }

    // Network errors from Dio
    if (error.toString().contains('SocketException')) {
      return NoInternetException();
    }

    if (error.toString().contains('TimeoutException')) {
      return TimeoutException(const Duration(seconds: 30));
    }

    if (error.toString().contains('DioException') ||
        error.toString().contains('DioError')) {
      return NetworkException(
        'Request failed',
        originalError: error,
      );
    }

    // Platform exceptions
    if (error.toString().contains('PlatformException')) {
      return PlatformException(
        'unknown',
        error.toString(),
        error,
      );
    }

    // Generic error
    return AuthException(
      'An unexpected error occurred',
      code: 'UNKNOWN_ERROR',
      originalError: error,
      stackTrace: stackTrace,
    );
  }

  /// Check if error is recoverable
  static bool isRecoverable(AuthException exception) {
    return exception is NetworkException ||
        exception is TimeoutException ||
        exception is NoInternetException ||
        exception is TokenExpiredException;
  }

  /// Get user-friendly error message
  static String getUserMessage(AuthException exception) {
    if (exception is NoInternetException) {
      return 'No internet connection. Please check your network and try again.';
    }

    if (exception is TimeoutException) {
      return 'Request timed out. Please try again.';
    }

    if (exception is AuthenticationCancelledException) {
      return 'Sign in was cancelled.';
    }

    if (exception is InvalidCredentialsException) {
      return 'Invalid email or password. Please try again.';
    }

    if (exception is TokenExpiredException) {
      return 'Your session has expired. Please sign in again.';
    }

    if (exception is ProviderNotFoundException) {
      return 'This sign-in method is not available. Please try another method.';
    }

    if (exception is InvalidEmailException) {
      return 'Please enter a valid email address.';
    }

    if (exception is InvalidPasswordException) {
      return exception.message;
    }

    // Generic fallback
    return 'Something went wrong. Please try again.';
  }
}

// ==========================================
// Error Recovery Strategies
// ==========================================

/// Defines how to recover from specific errors
class ErrorRecoveryStrategy {
  final AuthException exception;

  ErrorRecoveryStrategy(this.exception);

  /// Get suggested action for the user
  String getSuggestedAction() {
    if (exception is NoInternetException) {
      return 'Check your internet connection and try again';
    }

    if (exception is TokenExpiredException) {
      return 'Sign in again to continue';
    }

    if (exception is InvalidCredentialsException) {
      return 'Check your email and password';
    }

    if (exception is ProviderNotFoundException) {
      return 'Contact support or use a different sign-in method';
    }

    if (exception is AuthenticationCancelledException) {
      return 'Try signing in again when ready';
    }

    if (exception is TimeoutException) {
      return 'Check your connection and retry';
    }

    return 'Try again or contact support if the problem persists';
  }

  /// Check if operation should be retried automatically
  bool shouldRetry() {
    return exception is NetworkException ||
        exception is TimeoutException ||
        exception is NoInternetException;
  }

  /// Get retry delay (exponential backoff)
  Duration getRetryDelay(int attemptNumber) {
    if (!shouldRetry()) return Duration.zero;

    // Exponential backoff: 1s, 2s, 4s, 8s...
    final seconds = (1 << (attemptNumber - 1)).clamp(1, 30);
    return Duration(seconds: seconds);
  }
}

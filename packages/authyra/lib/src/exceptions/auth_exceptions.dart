/// Base exception class for all Authyra errors.
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

  /// Serialises this exception to a JSON-compatible map for logging or debugging.
  Map<String, dynamic> toJson() => {
        'type': runtimeType.toString(),
        'message': message,
        'code': code,
        'originalError': originalError?.toString(),
      };
}

// ---------------------------------------------------------------------------
// Configuration & Initialisation
// ---------------------------------------------------------------------------

/// Thrown when [AuthyraClient] is used before [initialize] is called.
class NotInitializedException extends AuthException {
  NotInitializedException()
      : super(
          'Authyra has not been initialized. Call Authyra.initialize() first.',
          code: 'NOT_INITIALIZED',
        );
}

/// Thrown when configuration is invalid (e.g., missing storage in builder).
class InvalidConfigurationException extends AuthException {
  InvalidConfigurationException(super.message) : super(code: 'INVALID_CONFIG');
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

/// Thrown when a requested provider is not registered with [AuthyraClient].
class ProviderNotFoundException extends AuthException {
  final String providerName;

  ProviderNotFoundException(this.providerName)
      : super(
          'Provider "$providerName" is not registered. '
          'Add it via AuthyraClient(providers: [...]).',
          code: 'PROVIDER_NOT_FOUND',
        );
}

/// Thrown when two providers share the same [AuthProvider.id].
class ProviderAlreadyRegisteredException extends AuthException {
  final String providerName;

  ProviderAlreadyRegisteredException(this.providerName)
      : super(
          'Provider "$providerName" is already registered.',
          code: 'PROVIDER_ALREADY_EXISTS',
        );
}

/// Thrown when a provider's configuration is invalid.
class InvalidProviderConfigException extends AuthException {
  final String providerName;

  InvalidProviderConfigException(this.providerName, String details)
      : super(
          'Invalid configuration for provider "$providerName": $details',
          code: 'INVALID_PROVIDER_CONFIG',
        );
}

// ---------------------------------------------------------------------------
// Authentication
// ---------------------------------------------------------------------------

/// Thrown when the user cancels an authentication flow.
class AuthenticationCancelledException extends AuthException {
  final String? providerName;

  AuthenticationCancelledException([this.providerName])
      : super(
          'Authentication was cancelled by the user'
          '${providerName != null ? ' for provider "$providerName"' : ''}.',
          code: 'AUTH_CANCELLED',
        );
}

/// Thrown when an authentication attempt fails.
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

/// Thrown when credentials (email/password) are invalid.
class InvalidCredentialsException extends AuthException {
  InvalidCredentialsException([String? details])
      : super(
          'Invalid credentials${details != null ? ': $details' : ''}',
          code: 'INVALID_CREDENTIALS',
        );
}

/// Thrown when required authentication parameters are missing.
class MissingAuthParametersException extends AuthException {
  final List<String> missingParams;

  MissingAuthParametersException(this.missingParams)
      : super(
          'Missing required authentication parameters: ${missingParams.join(', ')}',
          code: 'MISSING_AUTH_PARAMS',
        );
}

// ---------------------------------------------------------------------------
// Session & Token
// ---------------------------------------------------------------------------

/// Thrown when an access token has expired.
class TokenExpiredException extends AuthException {
  TokenExpiredException([String? details])
      : super(
          'Access token has expired${details != null ? ': $details' : ''}',
          code: 'TOKEN_EXPIRED',
        );
}

/// Thrown when a token refresh attempt fails.
class TokenRefreshFailedException extends AuthException {
  TokenRefreshFailedException([String? reason, dynamic originalError])
      : super(
          'Failed to refresh access token${reason != null ? ': $reason' : ''}',
          code: 'TOKEN_REFRESH_FAILED',
          originalError: originalError,
        );
}

/// Thrown when a token is invalid or malformed.
class InvalidTokenException extends AuthException {
  InvalidTokenException([String? details])
      : super(
          'Invalid or malformed token${details != null ? ': $details' : ''}',
          code: 'INVALID_TOKEN',
        );
}

/// Thrown when no active session is found.
class SessionNotFoundException extends AuthException {
  SessionNotFoundException()
      : super(
          'No active session found. Please sign in first.',
          code: 'SESSION_NOT_FOUND',
        );
}

/// Thrown when a session mutation (save, update, clear) fails.
class SessionOperationException extends AuthException {
  SessionOperationException(String operation, [dynamic originalError])
      : super(
          'Session operation failed: $operation',
          code: 'SESSION_OPERATION_FAILED',
          originalError: originalError,
        );
}

// ---------------------------------------------------------------------------
// Storage
// ---------------------------------------------------------------------------

/// Thrown when a storage read/write operation fails.
class StorageException extends AuthException {
  final String operation;

  StorageException(this.operation, [dynamic originalError])
      : super(
          'Storage operation failed: $operation',
          code: 'STORAGE_ERROR',
          originalError: originalError,
        );
}

// ---------------------------------------------------------------------------
// Network
// ---------------------------------------------------------------------------

/// Thrown when a network request fails.
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

/// Thrown when a request times out.
///
/// Named [AuthTimeoutException] to avoid shadowing `dart:async`'s
/// `TimeoutException`.
class AuthTimeoutException extends AuthException {
  final Duration timeout;

  AuthTimeoutException(this.timeout)
      : super(
          'Request timed out after ${timeout.inSeconds} seconds',
          code: 'TIMEOUT',
        );
}

/// Thrown when no internet connection is available.
class NoInternetException extends AuthException {
  NoInternetException()
      : super(
          'No internet connection available',
          code: 'NO_INTERNET',
        );
}

// ---------------------------------------------------------------------------
// Validation
// ---------------------------------------------------------------------------

/// Thrown when input validation fails.
class ValidationException extends AuthException {
  final String field;

  ValidationException(this.field, String reason)
      : super(
          'Validation failed for "$field": $reason',
          code: 'VALIDATION_ERROR',
        );
}

/// Thrown when an email address has an invalid format.
class InvalidEmailException extends ValidationException {
  InvalidEmailException(String email)
      : super('email', '"$email" is not a valid email address');
}

/// Thrown when a password does not meet the required policy.
class InvalidPasswordException extends ValidationException {
  InvalidPasswordException(String reason) : super('password', reason);
}

// ---------------------------------------------------------------------------
// Multi-Account
// ---------------------------------------------------------------------------

/// Thrown when an account is not found in the registry.
class AccountNotFoundException extends AuthException {
  final String accountId;

  AccountNotFoundException(this.accountId)
      : super(
          'Account with ID "$accountId" not found',
          code: 'ACCOUNT_NOT_FOUND',
        );
}

/// Thrown when trying to add an account that already exists.
class DuplicateAccountException extends AuthException {
  final String accountId;

  DuplicateAccountException(this.accountId)
      : super(
          'Account with ID "$accountId" already exists',
          code: 'DUPLICATE_ACCOUNT',
        );
}

// ---------------------------------------------------------------------------
// Platform
// ---------------------------------------------------------------------------

/// Thrown when a platform-specific operation fails.
///
/// Named [AuthPlatformException] to avoid shadowing Flutter's
/// `PlatformException` from `package:flutter/services.dart`.
class AuthPlatformException extends AuthException {
  final String platform;

  AuthPlatformException(this.platform, String message, [dynamic originalError])
      : super(
          'Platform error on $platform: $message',
          code: 'PLATFORM_ERROR',
          originalError: originalError,
        );
}

/// Thrown when a feature is not supported on the current platform.
class UnsupportedPlatformException extends AuthException {
  final String feature;
  final String platform;

  UnsupportedPlatformException(this.feature, this.platform)
      : super(
          'Feature "$feature" is not supported on $platform',
          code: 'UNSUPPORTED_PLATFORM',
        );
}

// ---------------------------------------------------------------------------
// Error handler utility
// ---------------------------------------------------------------------------

/// Converts arbitrary errors into typed [AuthException] subclasses.
class AuthyraErrorHandler {
  /// Wraps [error] in the most specific [AuthException] subclass available.
  ///
  /// If [error] is already an [AuthException] it is returned as-is.
  /// Platform-specific errors (SocketException, PlatformException) are
  /// detected by type name when a direct `is` check is not possible across
  /// package boundaries.
  static AuthException handleError(dynamic error, [StackTrace? stackTrace]) {
    if (error is AuthException) return error;

    final desc = error.toString();

    if (desc.contains('SocketException')) {
      return NoInternetException();
    }

    if (desc.contains('TimeoutException')) {
      return AuthTimeoutException(const Duration(seconds: 30));
    }

    if (desc.contains('PlatformException')) {
      return AuthPlatformException('unknown', desc, error);
    }

    return AuthException(
      'An unexpected error occurred',
      code: 'UNKNOWN_ERROR',
      originalError: error,
      stackTrace: stackTrace,
    );
  }

  /// Returns `true` when [exception] represents a transient condition that
  /// the caller may retry without user interaction.
  static bool isRecoverable(AuthException exception) {
    return exception is NetworkException ||
        exception is AuthTimeoutException ||
        exception is NoInternetException ||
        exception is TokenExpiredException;
  }

  /// Returns a user-facing message suitable for display in UI.
  static String getUserMessage(AuthException exception) {
    if (exception is NoInternetException) {
      return 'No internet connection. Please check your network and try again.';
    }
    if (exception is AuthTimeoutException) {
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
    return 'Something went wrong. Please try again.';
  }
}

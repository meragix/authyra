import 'package:authyra/src/exceptions/auth_exceptions.dart';

/// Validation utilities for Authyra
class AuthValidators {
  // Email regex pattern (RFC 5322 compliant)
  static final RegExp _emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  // Phone regex (international format)
  static final RegExp _phoneRegex = RegExp(
    r'^\+?[1-9]\d{1,14}$',
  );

  // URL regex
  static final RegExp _urlRegex = RegExp(
    r'^https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)$',
  );

  /// Validate email format
  static bool isValidEmail(String email) {
    if (email.isEmpty) return false;
    return _emailRegex.hasMatch(email.trim());
  }

  /// Validate email and throw if invalid
  static void validateEmail(String email) {
    if (!isValidEmail(email)) {
      throw InvalidEmailException(email);
    }
  }

  /// Validate password strength
  static bool isValidPassword(
    String password, {
    int minLength = 8,
    bool requireUppercase = false,
    bool requireLowercase = false,
    bool requireDigit = false,
    bool requireSpecialChar = false,
  }) {
    if (password.length < minLength) return false;

    if (requireUppercase && !password.contains(RegExp(r'[A-Z]'))) {
      return false;
    }

    if (requireLowercase && !password.contains(RegExp(r'[a-z]'))) {
      return false;
    }

    if (requireDigit && !password.contains(RegExp(r'[0-9]'))) {
      return false;
    }

    if (requireSpecialChar && !password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      return false;
    }

    return true;
  }

  /// Validate password and throw if invalid
  static void validatePassword(
    String password, {
    int minLength = 8,
    bool requireUppercase = false,
    bool requireLowercase = false,
    bool requireDigit = false,
    bool requireSpecialChar = false,
  }) {
    if (password.isEmpty) {
      throw InvalidPasswordException('Password cannot be empty');
    }

    if (password.length < minLength) {
      throw InvalidPasswordException(
        'Password must be at least $minLength characters long',
      );
    }

    if (requireUppercase && !password.contains(RegExp(r'[A-Z]'))) {
      throw InvalidPasswordException(
        'Password must contain at least one uppercase letter',
      );
    }

    if (requireLowercase && !password.contains(RegExp(r'[a-z]'))) {
      throw InvalidPasswordException(
        'Password must contain at least one lowercase letter',
      );
    }

    if (requireDigit && !password.contains(RegExp(r'[0-9]'))) {
      throw InvalidPasswordException(
        'Password must contain at least one digit',
      );
    }

    if (requireSpecialChar && !password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      throw InvalidPasswordException(
        'Password must contain at least one special character',
      );
    }
  }

  /// Validate phone number
  static bool isValidPhoneNumber(String phone) {
    if (phone.isEmpty) return false;
    return _phoneRegex.hasMatch(phone.trim());
  }

  /// Validate URL
  static bool isValidUrl(String url) {
    if (url.isEmpty) return false;
    return _urlRegex.hasMatch(url.trim());
  }

  /// Validate URL and throw if invalid
  static void validateUrl(String url, String fieldName) {
    if (!isValidUrl(url)) {
      throw ValidationException(fieldName, 'Invalid URL format');
    }
  }

  /// Validate sign-in parameters based on provider
  static void validateSignInParams(
    String providerName,
    Map<String, dynamic>? params,
  ) {
    switch (providerName.toLowerCase()) {
      case 'credentials':
        _validateCredentialsParams(params);
        break;
      case 'magic_link':
        _validateMagicLinkParams(params);
        break;
      case 'phone':
        _validatePhoneParams(params);
        break;
      // OAuth providers don't require params validation
      case 'google':
      case 'github':
      case 'apple':
      case 'facebook':
      case 'twitter':
        break;
      default:
        // Custom providers might have params
        break;
    }
  }

  /// Validate credentials provider parameters
  static void _validateCredentialsParams(Map<String, dynamic>? params) {
    if (params == null) {
      throw MissingAuthParametersException(['email', 'password']);
    }

    final email = params['email'] as String?;
    final password = params['password'] as String?;

    final missingParams = <String>[];
    if (email == null || email.isEmpty) {
      missingParams.add('email');
    }
    if (password == null || password.isEmpty) {
      missingParams.add('password');
    }

    if (missingParams.isNotEmpty) {
      throw MissingAuthParametersException(missingParams);
    }

    // Validate email format
    validateEmail(email!);

    // Validate password (basic check)
    if (password!.isEmpty) {
      throw InvalidPasswordException('Password cannot be empty');
    }
  }

  /// Validate magic link parameters
  static void _validateMagicLinkParams(Map<String, dynamic>? params) {
    if (params == null) {
      throw MissingAuthParametersException(['email']);
    }

    final email = params['email'] as String?;
    if (email == null || email.isEmpty) {
      throw MissingAuthParametersException(['email']);
    }

    validateEmail(email);
  }

  /// Validate phone authentication parameters
  static void _validatePhoneParams(Map<String, dynamic>? params) {
    if (params == null) {
      throw MissingAuthParametersException(['phoneNumber']);
    }

    final phone = params['phoneNumber'] as String?;
    if (phone == null || phone.isEmpty) {
      throw MissingAuthParametersException(['phoneNumber']);
    }

    if (!isValidPhoneNumber(phone)) {
      throw ValidationException('phoneNumber', 'Invalid phone number format');
    }
  }

  /// Validate provider configuration
  static void validateProviderConfig(String providerName, Map<String, dynamic> config) {
    switch (providerName.toLowerCase()) {
      case 'google':
        _validateGoogleConfig(config);
        break;
      case 'github':
        _validateGitHubConfig(config);
        break;
      case 'credentials':
        _validateCredentialsConfig(config);
        break;
      default:
        // Generic validation
        break;
    }
  }

  static void _validateGoogleConfig(Map<String, dynamic> config) {
    if (!config.containsKey('clientId') || config['clientId'] == null) {
      throw InvalidProviderConfigException('google', 'clientId is required');
    }

    final clientId = config['clientId'] as String;
    if (clientId.isEmpty) {
      throw InvalidProviderConfigException('google', 'clientId cannot be empty');
    }
  }

  static void _validateGitHubConfig(Map<String, dynamic> config) {
    final missingFields = <String>[];

    if (!config.containsKey('clientId') || config['clientId'] == null) {
      missingFields.add('clientId');
    }
    if (!config.containsKey('clientSecret') || config['clientSecret'] == null) {
      missingFields.add('clientSecret');
    }
    if (!config.containsKey('redirectUri') || config['redirectUri'] == null) {
      missingFields.add('redirectUri');
    }

    if (missingFields.isNotEmpty) {
      throw InvalidProviderConfigException(
        'github',
        'Missing required fields: ${missingFields.join(', ')}',
      );
    }

    // Validate redirect URI format
    final redirectUri = config['redirectUri'] as String;
    if (!redirectUri.startsWith('http://') && !redirectUri.startsWith('https://') && !redirectUri.contains('://')) {
      throw InvalidProviderConfigException(
        'github',
        'redirectUri must be a valid URL or custom scheme',
      );
    }
  }

  static void _validateCredentialsConfig(Map<String, dynamic> config) {
    if (!config.containsKey('loginEndpoint') || config['loginEndpoint'] == null) {
      throw InvalidProviderConfigException(
        'credentials',
        'loginEndpoint is required',
      );
    }

    validateUrl(config['loginEndpoint'] as String, 'loginEndpoint');
  }

  /// Validate auth configuration
  static void validateAuthConfig(Map<String, dynamic> config) {
    if (!config.containsKey('storage') || config['storage'] == null) {
      throw InvalidConfigurationException('Storage is required in AuthConfig');
    }

    // Validate deep link scheme if provided
    if (config.containsKey('deepLinkScheme') && config['deepLinkScheme'] != null) {
      final scheme = config['deepLinkScheme'] as String;
      if (scheme.isEmpty) {
        throw InvalidConfigurationException('deepLinkScheme cannot be empty');
      }

      // Scheme should not contain ://
      if (scheme.contains('://')) {
        throw InvalidConfigurationException(
          'deepLinkScheme should not contain "://" (e.g., use "authyra" not "authyra://")',
        );
      }
    }
  }

  /// Validate user data
  static void validateUserData(Map<String, dynamic> userData) {
    if (!userData.containsKey('id') || userData['id'] == null) {
      throw ValidationException('user', 'User ID is required');
    }

    final id = userData['id'].toString();
    if (id.isEmpty) {
      throw ValidationException('user', 'User ID cannot be empty');
    }

    // Validate email if present
    if (userData.containsKey('email') && userData['email'] != null) {
      final email = userData['email'] as String;
      if (email.isNotEmpty && !isValidEmail(email)) {
        throw ValidationException('user.email', 'Invalid email format');
      }
    }
  }

  /// Validate session data
  static void validateSessionData(Map<String, dynamic> sessionData) {
    final missingFields = <String>[];

    if (!sessionData.containsKey('user')) missingFields.add('user');
    if (!sessionData.containsKey('accessToken')) {
      missingFields.add('accessToken');
    }
    if (!sessionData.containsKey('expiresAt')) missingFields.add('expiresAt');

    if (missingFields.isNotEmpty) {
      throw ValidationException(
        'session',
        'Missing required fields: ${missingFields.join(', ')}',
      );
    }

    // Validate user data
    validateUserData(sessionData['user'] as Map<String, dynamic>);

    // Validate access token
    final accessToken = sessionData['accessToken'] as String;
    if (accessToken.isEmpty) {
      throw ValidationException('session.accessToken', 'Access token cannot be empty');
    }

    // Validate expiration date
    try {
      DateTime.parse(sessionData['expiresAt'] as String);
    } catch (e) {
      throw ValidationException(
        'session.expiresAt',
        'Invalid date format. Expected ISO 8601 format.',
      );
    }
  }
}

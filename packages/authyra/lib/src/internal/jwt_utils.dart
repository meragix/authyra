import 'dart:convert';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

/// Utilities for working with JSON Web Tokens (JWTs) across Authyra providers.
///
/// [JwtUtils] covers three use cases:
///
/// 1. **Reading**: decode any JWT and extract standard or custom claims
///    without verifying the signature (useful when you already trust the
///    source, e.g., a token received over HTTPS from a verified OAuth2
///    endpoint).
///
/// 2. **Verifying**: cryptographically verify a token before trusting its
///    claims (e.g., an OIDC `id_token` from Apple or Google).
///
/// 3. **Generating**: create signed JWTs, in particular the ES256 client
///    secret required by [AppleProvider].
///
/// All methods are **static**: [JwtUtils] is a pure-function namespace, not
/// a class to instantiate.
///
/// ## Basic usage
///
/// ```dart
/// // Decode an id_token without verifying the signature
/// final claims = JwtUtils.decodePayload(idToken);
/// print(claims['sub']); // stable user identifier
/// print(claims['email']);
///
/// // Check expiry before making an API call
/// if (JwtUtils.isExpired(accessToken)) {
///   await Authyra.instance.refreshSession();
/// }
///
/// // Generate Apple's client_secret
/// final secret = JwtUtils.generateAppleClientSecret(
///   teamId: 'XXXXXXXXXX',
///   clientId: 'com.example.app',
///   keyId: 'YYYYYYYYYY',
///   privateKeyPem: File('AuthKey_YYYYYYYYYY.p8').readAsStringSync(),
/// );
/// ```
///
/// See also:
/// - [AppleProvider], which uses [generateAppleClientSecret].
/// - `dart_jsonwebtoken` package for lower-level JWT operations.
abstract final class JwtUtils {
  // ---------------------------------------------------------------------------
  // Decoding (no signature verification)
  // ---------------------------------------------------------------------------

  /// Decodes [token] and returns the payload claims **without** verifying the
  /// signature.
  ///
  /// Use this when the token was received directly from a trusted HTTPS
  /// endpoint (e.g., an OAuth2 token exchange response) and you need to read
  /// its claims without performing local cryptographic verification.
  ///
  /// ```dart
  /// final claims = JwtUtils.decodePayload(idToken);
  /// final userId = claims['sub'] as String;
  /// final email = claims['email'] as String?;
  /// ```
  ///
  /// Throws [JWTException] if the token is malformed (not a valid JWT).
  static Map<String, dynamic> decodePayload(String token) {
    final jwt = JWT.decode(token);
    final payload = jwt.payload;
    if (payload is Map<String, dynamic>) return payload;
    if (payload is Map) return payload.cast<String, dynamic>();
    throw JWTException('JWT payload is not a JSON object');
  }

  /// Decodes [token] and returns both header and payload without verifying
  /// the signature.
  ///
  /// ```dart
  /// final decoded = JwtUtils.decode(token);
  /// print(decoded['header']); // { 'alg': 'ES256', 'kid': '...' }
  /// print(decoded['payload']); // { 'sub': '...', 'exp': ... }
  /// ```
  ///
  /// Throws [JWTException] if the token is malformed.
  static Map<String, dynamic> decode(String token) {
    final jwt = JWT.decode(token);
    final payload = jwt.payload;
    final Map<String, dynamic> payloadMap;
    if (payload is Map<String, dynamic>) {
      payloadMap = payload;
    } else if (payload is Map) {
      payloadMap = payload.cast<String, dynamic>();
    } else {
      throw JWTException('JWT payload is not a JSON object');
    }

    // dart_jsonwebtoken does not expose the raw header as a public field,
    // so we decode it directly from the base64url-encoded first segment.
    final parts = token.split('.');
    if (parts.length < 2) {
      throw JWTException('Malformed JWT: not enough segments');
    }
    final headerJson = utf8.decode(
      base64Url.decode(base64Url.normalize(parts[0])),
    );
    final header = jsonDecode(headerJson) as Map<String, dynamic>;

    return {'header': header, 'payload': payloadMap};
  }

  // ---------------------------------------------------------------------------
  // Verification
  // ---------------------------------------------------------------------------

  /// Verifies [token] against [key] and returns the payload claims.
  ///
  /// Throws [JWTExpiredException] if the token is expired.
  /// Throws [JWTException] if verification fails for any other reason.
  ///
  /// ```dart
  /// // Verify with a shared HMAC secret
  /// final claims = JwtUtils.verify(token, SecretKey('my-secret'));
  ///
  /// // Verify with an RSA / EC public key
  /// final claims = JwtUtils.verify(idToken, ECPublicKey(publicKeyPem));
  /// ```
  static Map<String, dynamic> verify(String token, JWTKey key) {
    final jwt = JWT.verify(token, key);
    final payload = jwt.payload;
    if (payload is Map<String, dynamic>) return payload;
    if (payload is Map) return payload.cast<String, dynamic>();
    throw JWTException('JWT payload is not a JSON object');
  }

  // ---------------------------------------------------------------------------
  // Claim accessors
  // ---------------------------------------------------------------------------

  /// Returns the `exp` claim as a [DateTime], or `null` if absent.
  ///
  /// The `exp` claim is a Unix timestamp (seconds since epoch).
  ///
  /// ```dart
  /// final expiry = JwtUtils.expiresAt(token);
  /// if (expiry != null && expiry.isBefore(DateTime.now())) {
  ///   // token is expired
  /// }
  /// ```
  static DateTime? expiresAt(String token) {
    try {
      final exp = decodePayload(token)['exp'];
      if (exp == null) return null;
      return DateTime.fromMillisecondsSinceEpoch((exp as int) * 1000);
    } catch (_) {
      return null;
    }
  }

  /// Returns `true` if the token has an `exp` claim that is in the past.
  ///
  /// Returns `false` if the token has no `exp` claim (treated as never-expiring).
  ///
  /// ```dart
  /// if (JwtUtils.isExpired(accessToken)) {
  ///   await client.refreshSession();
  /// }
  /// ```
  static bool isExpired(String token) {
    final expiry = expiresAt(token);
    if (expiry == null) return false;
    return DateTime.now().isAfter(expiry);
  }

  /// Returns `true` if the token will expire within [threshold] from now.
  ///
  /// ```dart
  /// // Refresh proactively if the token expires within the next 5 minutes
  /// if (JwtUtils.expiresWithin(accessToken, Duration(minutes: 5))) {
  ///   await client.refreshSession();
  /// }
  /// ```
  static bool expiresWithin(String token, Duration threshold) {
    final expiry = expiresAt(token);
    if (expiry == null) return false;
    return DateTime.now().add(threshold).isAfter(expiry);
  }

  /// Returns the `sub` (subject) claim, or `null` if absent.
  ///
  /// In OIDC providers, `sub` is the stable, unique identifier for the user.
  ///
  /// ```dart
  /// final userId = JwtUtils.subject(idToken) ?? 'unknown';
  /// ```
  static String? subject(String token) {
    try {
      return decodePayload(token)['sub'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Returns the `iss` (issuer) claim, or `null` if absent.
  ///
  /// ```dart
  /// assert(JwtUtils.issuer(appleIdToken) == 'https://appleid.apple.com');
  /// ```
  static String? issuer(String token) {
    try {
      return decodePayload(token)['iss'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Returns the `aud` (audience) claim as a `String`, a `List<String>`,
  /// or `null` if absent.
  static dynamic audience(String token) {
    try {
      return decodePayload(token)['aud'];
    } catch (_) {
      return null;
    }
  }

  /// Returns the `iat` (issued-at) claim as a [DateTime], or `null` if absent.
  static DateTime? issuedAt(String token) {
    try {
      final iat = decodePayload(token)['iat'];
      if (iat == null) return null;
      return DateTime.fromMillisecondsSinceEpoch((iat as int) * 1000);
    } catch (_) {
      return null;
    }
  }

  /// Returns the decoded JWT header as a `Map`, or `null` on error.
  ///
  /// ```dart
  /// final kid = JwtUtils.header(idToken)?['kid'] as String?;
  /// ```
  static Map<String, dynamic>? header(String token) {
    try {
      return decode(token)['header'] as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }

  /// Returns the value of an arbitrary claim [name], or `null` if absent.
  ///
  /// ```dart
  /// final emailVerified = JwtUtils.claim(idToken, 'email_verified') as bool?;
  /// ```
  static dynamic claim(String token, String name) {
    try {
      return decodePayload(token)[name];
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Apple client_secret generation
  // ---------------------------------------------------------------------------

  /// Generates the short-lived ES256 JWT that Apple requires as the
  /// `client_secret` in token exchange and refresh requests.
  ///
  /// Apple does not use a static client secret. Instead, every call to the
  /// token endpoint must include a freshly signed JWT:
  ///
  /// | Claim | Value |
  /// | ----- | ----- |
  /// | `iss` | Your 10-character Apple Team ID |
  /// | `sub` | Your Services ID (`client_id`) |
  /// | `aud` | `https://appleid.apple.com` |
  /// | `iat` | Current Unix timestamp (seconds) |
  /// | `exp` | `iat` + [validity] (maximum 6 months) |
  ///
  /// The JWT is signed with the **ES256** algorithm using the `.p8` private
  /// key downloaded from App Store Connect / Apple Developer Portal.
  ///
  /// ## Setup
  ///
  /// 1. In the [Apple Developer Portal](https://developer.apple.com/account/resources/authkeys/list),
  ///    create a new key and enable **Sign in with Apple**.
  /// 2. Download the `.p8` file. Copy its contents (everything from
  ///    `-----BEGIN PRIVATE KEY-----` to `-----END PRIVATE KEY-----`).
  /// 3. Note your **Team ID** (top-right corner of the developer portal) and
  ///    the **Key ID** shown next to your key.
  ///
  /// ```dart
  /// final clientSecret = JwtUtils.generateAppleClientSecret(
  ///   teamId: 'AB12CD34EF',
  ///   clientId: 'com.example.app',          // Services ID
  ///   keyId: 'XYZXYZXYZX',
  ///   privateKeyPem: '''
  ///     -----BEGIN PRIVATE KEY-----
  ///     MIGHAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBG0wawIBAQQgevZzL1gdAFr88hih
  ///     ...
  ///     -----END PRIVATE KEY-----''',
  ///   validity: Duration(days: 180), // Apple maximum is 6 months
  /// );
  /// ```
  ///
  /// The generated secret can be cached and reused until it is close to
  /// expiring; there is no need to regenerate it per request.
  ///
  /// See also:
  /// - [Apple documentation](https://developer.apple.com/documentation/sign_in_with_apple/generate_and_validate_tokens)
  /// - [AppleProvider], which calls this automatically during sign-in and refresh.
  static String generateAppleClientSecret({
    required String teamId,
    required String clientId,
    required String keyId,
    required String privateKeyPem,
    Duration validity = const Duration(days: 180),
  }) {
    assert(
      validity <= const Duration(days: 180),
      'Apple client secrets cannot be valid for more than 6 months (180 days). '
      'Received: ${validity.inDays} days.',
    );

    // Build the JWT with Apple-required claims.
    // `iat` is injected automatically by sign() (noIssueAt defaults to false).
    final jwt = JWT(
      <String, dynamic>{}, // Additional payload fields: not needed for Apple
      header: <String, dynamic>{'kid': keyId},
      issuer: teamId,
      subject: clientId,
      audience: Audience.one('https://appleid.apple.com'),
    );

    // Sign with ES256 using the private key from the .p8 file.
    return jwt.sign(
      ECPrivateKey(privateKeyPem),
      algorithm: JWTAlgorithm.ES256,
      expiresIn: validity,
    );
  }
}

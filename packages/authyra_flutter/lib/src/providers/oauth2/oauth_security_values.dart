import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Cryptographic values for a single OAuth 2.0 Authorization Code sign-in
/// attempt: the PKCE (RFC 7636) verifier/challenge pair, the CSRF `state`
/// token (RFC 6749 §10.12), and an optional OIDC replay-protection `nonce`.
///
/// Extracted as a standalone, dependency-free value object so the same
/// generation logic is not duplicated across every provider that drives a
/// browser-based OAuth flow.
class OAuthSecurityValues {
  /// The PKCE code verifier, `null` when [OAuthSecurityValues.generate] was
  /// called with `usePkce: false`.
  final String? codeVerifier;

  /// The SHA-256 PKCE code challenge derived from [codeVerifier].
  final String? codeChallenge;

  /// Fresh, cryptographically random CSRF state token for this attempt.
  final String state;

  /// Lowercase hex nonce, `null` unless `includeNonce: true` was requested.
  final String? nonce;

  const OAuthSecurityValues({
    this.codeVerifier,
    this.codeChallenge,
    required this.state,
    this.nonce,
  });

  /// Generates a fresh [OAuthSecurityValues] for one sign-in attempt.
  ///
  /// [usePkce] controls whether [codeVerifier]/[codeChallenge] are derived.
  /// [includeNonce] generates a [nonce] for providers whose `id_token`
  /// carries replay protection (e.g. Sign in with Apple).
  factory OAuthSecurityValues.generate({
    bool usePkce = true,
    bool includeNonce = false,
  }) {
    final random = Random.secure();

    String? verifier;
    String? challenge;
    if (usePkce) {
      verifier = _randomUrlSafe(random, 32);
      final digest = sha256.convert(utf8.encode(verifier));
      challenge = _urlSafeNoPad(digest.bytes);
    }

    String? nonce;
    if (includeNonce) {
      final nonceBytes = List<int>.generate(16, (_) => random.nextInt(256));
      nonce = nonceBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    }

    return OAuthSecurityValues(
      codeVerifier: verifier,
      codeChallenge: challenge,
      state: _randomUrlSafe(random, 16),
      nonce: nonce,
    );
  }

  static String _randomUrlSafe(Random random, int byteLength) {
    final bytes = List<int>.generate(byteLength, (_) => random.nextInt(256));
    return _urlSafeNoPad(bytes);
  }

  // `base64UrlEncode` already emits '-'/'_' instead of '+'/'/'; only the
  // '=' padding needs stripping to satisfy RFC 7636's unreserved charset.
  static String _urlSafeNoPad(List<int> bytes) =>
      base64UrlEncode(bytes).replaceAll('=', '');
}

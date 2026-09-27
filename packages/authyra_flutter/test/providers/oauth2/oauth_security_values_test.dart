import 'dart:convert';

import 'package:authyra_flutter/src/providers/oauth2/oauth_security_values.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OAuthSecurityValues.generate', () {
    test('derives a PKCE challenge matching the verifier by default', () {
      final values = OAuthSecurityValues.generate();

      expect(values.codeVerifier, isNotNull);
      expect(values.codeChallenge, isNotNull);

      final expectedDigest = sha256.convert(utf8.encode(values.codeVerifier!));
      final expectedChallenge =
          base64UrlEncode(expectedDigest.bytes).replaceAll('=', '');
      expect(values.codeChallenge, expectedChallenge);
    });

    test('omits PKCE values when usePkce is false', () {
      final values = OAuthSecurityValues.generate(usePkce: false);

      expect(values.codeVerifier, isNull);
      expect(values.codeChallenge, isNull);
      expect(values.state, isNotEmpty);
    });

    test('omits nonce unless includeNonce is true', () {
      expect(OAuthSecurityValues.generate().nonce, isNull);
      expect(
        OAuthSecurityValues.generate(includeNonce: true).nonce,
        isNotNull,
      );
    });

    test('nonce is lowercase hex', () {
      final nonce = OAuthSecurityValues.generate(includeNonce: true).nonce!;
      expect(RegExp(r'^[0-9a-f]+$').hasMatch(nonce), isTrue);
    });

    test('state, verifier and challenge are URL-safe with no padding', () {
      final values = OAuthSecurityValues.generate();
      final urlSafe = RegExp(r'^[A-Za-z0-9_-]+$');

      expect(urlSafe.hasMatch(values.state), isTrue);
      expect(urlSafe.hasMatch(values.codeVerifier!), isTrue);
      expect(urlSafe.hasMatch(values.codeChallenge!), isTrue);
    });

    test('generates a fresh state on every call', () {
      final a = OAuthSecurityValues.generate();
      final b = OAuthSecurityValues.generate();

      expect(a.state, isNot(equals(b.state)));
      expect(a.codeVerifier, isNot(equals(b.codeVerifier)));
    });
  });
}

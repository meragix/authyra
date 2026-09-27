import 'dart:convert';

import 'package:authyra/authyra.dart';
import 'package:authyra_apple/authyra_apple.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign_in_with_apple_platform_interface/sign_in_with_apple_platform_interface.dart';

/// Fake platform implementation, configured per test to either return a
/// credential or throw, without touching any real native channel.
class _FakeSignInWithApplePlatform extends SignInWithApplePlatform {
  AuthorizationCredentialAppleID? credentialToReturn;
  Object? errorToThrow;
  List<AppleIDAuthorizationScopes>? capturedScopes;

  @override
  Future<AuthorizationCredentialAppleID> getAppleIDCredential({
    required List<AppleIDAuthorizationScopes> scopes,
    WebAuthenticationOptions? webAuthenticationOptions,
    String? nonce,
    String? state,
  }) async {
    capturedScopes = scopes;
    final error = errorToThrow;
    if (error != null) throw error;
    return credentialToReturn!;
  }
}

/// Builds an unsigned JWT with the given [payload]; only used to exercise
/// the identity-only decode path, never to assert real Apple signatures.
String _fakeIdentityToken(Map<String, dynamic> payload) {
  String segment(Map<String, dynamic> json) =>
      base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  return '${segment({'alg': 'RS256'})}.${segment(payload)}.signature';
}

void main() {
  late _FakeSignInWithApplePlatform fakePlatform;

  setUp(() {
    fakePlatform = _FakeSignInWithApplePlatform();
    SignInWithApplePlatform.instance = fakePlatform;
  });

  group('AppleProvider identity', () {
    test('id, name, and capability flags', () {
      final provider = AppleProvider();
      expect(provider.id, 'apple');
      expect(provider.name, 'Apple');
      expect(provider.supportsRefresh, isFalse);
      expect(provider.supportsSignOut, isFalse);
    });

    test('requests email and fullName scopes by default', () async {
      fakePlatform.credentialToReturn = const AuthorizationCredentialAppleID(
        userIdentifier: 'user123',
        givenName: null,
        familyName: null,
        email: null,
        authorizationCode: 'auth-code',
        identityToken: null,
        state: null,
      );

      await AppleProvider().signIn();

      expect(
        fakePlatform.capturedScopes,
        containsAll([
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ]),
      );
    });
  });

  group('AppleProvider.signIn without exchangeCredential', () {
    test('returns identity-only result, no session tokens', () async {
      fakePlatform.credentialToReturn = const AuthorizationCredentialAppleID(
        userIdentifier: 'user123',
        givenName: 'Ada',
        familyName: 'Lovelace',
        email: 'ada@example.com',
        authorizationCode: 'auth-code-xyz',
        identityToken: 'id-token-xyz',
        state: null,
      );

      final result = await AppleProvider().signIn();

      expect(result, isNotNull);
      expect(result!.user.id, 'user123');
      expect(result.user.email, 'ada@example.com');
      expect(result.user.name, 'Ada Lovelace');
      expect(result.accessToken, isNull);
      expect(result.refreshToken, isNull);
      expect(result.account!.providerId, 'apple');
      expect(result.account!.providerData['identityToken'], 'id-token-xyz');
      expect(
        result.account!.providerData['authorizationCode'],
        'auth-code-xyz',
      );
    });

    test('falls back to decoding identityToken when userIdentifier is null',
        () async {
      final token = _fakeIdentityToken({
        'sub': 'decoded-sub',
        'email': 'from-token@example.com',
        'email_verified': 'true',
      });

      fakePlatform.credentialToReturn = AuthorizationCredentialAppleID(
        userIdentifier: null, // Android never returns this.
        givenName: null,
        familyName: null,
        email: null,
        authorizationCode: 'auth-code',
        identityToken: token,
        state: null,
      );

      final result = await AppleProvider().signIn();

      expect(result!.user.id, 'decoded-sub');
      expect(result.user.email, 'from-token@example.com');
      expect(result.user.metadata['email_verified'], 'true');
    });

    test('throws AuthenticationFailedException when identity is unrecoverable',
        () async {
      fakePlatform.credentialToReturn = const AuthorizationCredentialAppleID(
        userIdentifier: null,
        givenName: null,
        familyName: null,
        email: null,
        authorizationCode: 'auth-code',
        identityToken: null, // nothing to decode either
        state: null,
      );

      expect(
        () => AppleProvider().signIn(),
        throwsA(isA<AuthenticationFailedException>()),
      );
    });
  });

  group('AppleProvider.withExchange', () {
    test('forwards the raw credential to exchangeCredential', () async {
      fakePlatform.credentialToReturn = const AuthorizationCredentialAppleID(
        userIdentifier: 'user123',
        givenName: 'Ada',
        familyName: 'Lovelace',
        email: 'ada@example.com',
        authorizationCode: 'auth-code-xyz',
        identityToken: 'id-token-xyz',
        state: null,
      );

      AppleCredential? received;
      final provider = AppleProvider.withExchange(
        exchangeCredential: (credential) async {
          received = credential;
          return AuthSignInResult(
            user: AuthUser(id: 'backend-user-id'),
            accessToken: 'backend-access-token',
            refreshToken: 'backend-refresh-token',
          );
        },
      );

      final result = await provider.signIn();

      expect(received, isNotNull);
      expect(received!.userIdentifier, 'user123');
      expect(received!.authorizationCode, 'auth-code-xyz');
      expect(received!.identityToken, 'id-token-xyz');
      expect(result!.user.id, 'backend-user-id');
      expect(result.accessToken, 'backend-access-token');
      expect(result.refreshToken, 'backend-refresh-token');
    });

    test('returns null when exchangeCredential rejects the sign-in', () async {
      fakePlatform.credentialToReturn = const AuthorizationCredentialAppleID(
        userIdentifier: 'user123',
        givenName: null,
        familyName: null,
        email: null,
        authorizationCode: 'auth-code',
        identityToken: null,
        state: null,
      );

      final provider = AppleProvider.withExchange(
        exchangeCredential: (credential) async => null,
      );

      expect(await provider.signIn(), isNull);
    });
  });

  group('AppleProvider error mapping', () {
    test('maps canceled authorization to AuthenticationCancelledException',
        () async {
      fakePlatform.errorToThrow = const SignInWithAppleAuthorizationException(
        code: AuthorizationErrorCode.canceled,
        message: 'User canceled authorization',
      );

      expect(
        () => AppleProvider().signIn(),
        throwsA(isA<AuthenticationCancelledException>()),
      );
    });

    test('maps other authorization errors to AuthenticationFailedException',
        () async {
      fakePlatform.errorToThrow = const SignInWithAppleAuthorizationException(
        code: AuthorizationErrorCode.failed,
        message: 'Something went wrong',
      );

      expect(
        () => AppleProvider().signIn(),
        throwsA(isA<AuthenticationFailedException>()),
      );
    });

    test(
        'maps SignInWithAppleNotSupportedException to AuthenticationFailedException',
        () async {
      fakePlatform.errorToThrow = const SignInWithAppleNotSupportedException(
        message: 'Not supported on this OS version',
      );

      expect(
        () => AppleProvider().signIn(),
        throwsA(isA<AuthenticationFailedException>()),
      );
    });

    test('propagates AuthException from exchangeCredential unchanged',
        () async {
      fakePlatform.credentialToReturn = const AuthorizationCredentialAppleID(
        userIdentifier: 'user123',
        givenName: null,
        familyName: null,
        email: null,
        authorizationCode: 'auth-code',
        identityToken: null,
        state: null,
      );

      final provider = AppleProvider.withExchange(
        exchangeCredential: (credential) async =>
            throw AuthenticationCancelledException('apple'),
      );

      expect(
        () => provider.signIn(),
        throwsA(isA<AuthenticationCancelledException>()),
      );
    });
  });
}

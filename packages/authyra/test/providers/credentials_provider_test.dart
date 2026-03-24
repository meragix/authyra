import 'package:authyra/src/models/auth_sign_in_result.dart';
import 'package:test/test.dart';
import 'package:authyra/src/providers/credentials/credentials_provider.dart';
import 'package:authyra/src/interfaces/auth_provider.dart';
import 'package:authyra/src/interfaces/auth_sign_in_params.dart';
import 'package:authyra/src/models/auth_user.dart';

void main() {
  group('CredentialsProvider', () {
    group('basic constructor (AuthorizeCallback)', () {
      test('returns AuthSignInResult.userOnly on success', () async {
        final provider = CredentialsProvider(
          id: 'email',
          authorize: (creds) async =>
              AuthUser(id: 'usr_1', email: creds?.email),
        );

        final result = await provider.signIn(
          params: CredentialsSignInParams(
            email: 'alice@test.com',
            password: 'secret',
          ),
        );

        expect(result, isNotNull);
        expect(result!.user.email, 'alice@test.com');
        expect(result.accessToken, isNull);
      });

      test('returns null when authorize callback returns null', () async {
        final provider = CredentialsProvider(
          id: 'email',
          authorize: (_) async => null,
        );

        final result = await provider.signIn(
          params: CredentialsSignInParams(
            email: 'bad@test.com',
            password: 'wrong',
          ),
        );

        expect(result, isNull);
      });

      test('forwards CredentialsSignInParams to callback', () async {
        CredentialsSignInParams? received;

        final provider = CredentialsProvider(
          id: 'email',
          authorize: (creds) async {
            received = creds;
            return AuthUser(id: 'usr_1', email: creds?.email);
          },
        );

        await provider.signIn(
          params: CredentialsSignInParams(
            email: 'alice@test.com',
            password: 'pw',
          ),
        );

        expect(received?.email, 'alice@test.com');
        expect(received?.password, 'pw');
      });

      test('null params passed as null to callback', () async {
        CredentialsSignInParams? received = CredentialsSignInParams(
          email: 'x', password: 'x',
        );

        final provider = CredentialsProvider(
          id: 'email',
          authorize: (creds) async {
            received = creds;
            return AuthUser(id: 'usr_1');
          },
        );

        await provider.signIn(params: null);
        expect(received, isNull);
      });

      test('non-CredentialsSignInParams is passed as null to callback', () async {
        CredentialsSignInParams? received =
            CredentialsSignInParams(email: 'x', password: 'x');

        final provider = CredentialsProvider(
          id: 'email',
          authorize: (creds) async {
            received = creds;
            return AuthUser(id: 'usr_1');
          },
        );

        await provider.signIn(params: OAuth2SignInParams(code: 'code123'));
        expect(received, isNull);
      });

      test('rethrows exceptions from callback', () async {
        final provider = CredentialsProvider(
          id: 'email',
          authorize: (_) async => throw Exception('network error'),
        );

        expect(
          () => provider.signIn(
            params: CredentialsSignInParams(email: 'a@b.com', password: 'x'),
          ),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('withTokens constructor (AuthorizeWithTokensCallback)', () {
      test('returns full AuthSignInResult with tokens', () async {
        final expiresAt = DateTime.now().add(const Duration(hours: 1));
        final provider = CredentialsProvider.withTokens(
          id: 'email',
          authorize: (creds) async => AuthSignInResult(
            user: AuthUser(id: 'usr_1', email: creds?.email),
            accessToken: 'at_123',
            refreshToken: 'rt_456',
            expiresAt: expiresAt,
          ),
        );

        final result = await provider.signIn(
          params: CredentialsSignInParams(
            email: 'alice@test.com',
            password: 'secret',
          ),
        );

        expect(result, isNotNull);
        expect(result!.accessToken, 'at_123');
        expect(result.refreshToken, 'rt_456');
        expect(result.expiresAt, expiresAt);
      });

      test('returns null when withTokens callback returns null', () async {
        final provider = CredentialsProvider.withTokens(
          id: 'email',
          authorize: (_) async => null,
        );

        final result = await provider.signIn(
          params: CredentialsSignInParams(email: 'x@x.com', password: 'bad'),
        );
        expect(result, isNull);
      });
    });

    group('provider metadata', () {
      test('type is credentials', () {
        final p = CredentialsProvider(id: 'email', authorize: (_) async => null);
        expect(p.type, AuthProviderType.credentials);
      });

      test('supportsRefresh is false', () {
        final p = CredentialsProvider(id: 'email', authorize: (_) async => null);
        expect(p.supportsRefresh, isFalse);
      });

      test('supportsSignOut is false', () {
        final p = CredentialsProvider(id: 'email', authorize: (_) async => null);
        expect(p.supportsSignOut, isFalse);
      });

      test('id is set from constructor', () {
        final p = CredentialsProvider(id: 'my-provider', authorize: (_) async => null);
        expect(p.id, 'my-provider');
      });
    });
  });
}

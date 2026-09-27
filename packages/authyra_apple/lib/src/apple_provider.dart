import 'dart:convert';

import 'package:authyra/authyra.dart';
import 'package:authyra/logging.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// Raw Sign in with Apple credential, before any exchange with your backend.
///
/// None of these fields are application session tokens; see
/// [AuthSignInResult]'s "Credential vs. session-token semantics" section.
/// [identityToken] and [authorizationCode] are Apple-issued material meant
/// for a further exchange, typically server-side, never for
/// [AuthSignInResult.accessToken] / [AuthSignInResult.refreshToken].
class AppleCredential {
  /// Stable identifier for the Apple ID. Always present on iOS/macOS;
  /// absent on Android (a limitation of Apple's own SDK there).
  final String? userIdentifier;

  /// JWT carrying the user's identity claims (`sub`, `email`, ...), signed
  /// by Apple. Decode it to recover the profile, or hand it to your backend
  /// for verification.
  final String? identityToken;

  /// Short-lived code for your backend to validate with Apple's servers,
  /// within 5 minutes of receiving it.
  final String authorizationCode;

  /// Only present on the very first authorization between this app and the
  /// user's Apple ID. Persist it immediately; Apple never sends it again.
  final String? email;

  /// Same first-authorization-only limitation as [email].
  final String? givenName;

  /// Same first-authorization-only limitation as [email].
  final String? familyName;

  const AppleCredential({
    required this.authorizationCode,
    this.userIdentifier,
    this.identityToken,
    this.email,
    this.givenName,
    this.familyName,
  });
}

/// Exchanges a raw [AppleCredential] for an application session.
///
/// Typically forwards [AppleCredential.authorizationCode] or
/// [AppleCredential.identityToken] to your backend and returns the
/// resulting [AuthSignInResult], with real application session tokens.
///
/// Return `null` to reject the sign-in (e.g., the backend does not
/// recognize this Apple ID).
typedef AppleCredentialExchange = Future<AuthSignInResult?> Function(
  AppleCredential credential,
);

/// Sign in with Apple, backed by the native `sign_in_with_apple` SDK.
///
/// Unlike a browser-based OAuth2 flow, this provider delegates the entire
/// authorization UI to the platform: the native sheet on iOS/macOS, a Chrome
/// Custom Tab on Android, a popup on web. It does not reimplement any part
/// of Apple's flow; it only normalizes the resulting credential into the
/// [AuthProvider] contract.
///
/// ## Why native, not browser-based OAuth2
///
/// App Store Review Guideline 4.8 requires the native Sign in with Apple UI
/// whenever another social login (Google, Facebook, ...) is offered on iOS.
/// A browser-based OAuth2 flow does not satisfy that requirement. This
/// package replaces the browser-based `AppleProvider` that shipped in
/// `authyra_flutter` 0.1.0.
///
/// ## Setup
///
/// 1. Enable the "Sign in with Apple" capability for your app identifier.
/// 2. iOS and macOS need no further configuration beyond the capability.
/// 3. Android and web additionally require [webAuthenticationOptions]: create
///    a Services ID at
///    [developer.apple.com](https://developer.apple.com/account/resources/identifiers/list/serviceId)
///    and use it as `clientId`, with a `redirectUri` you control.
///
/// ```dart
/// final appleProvider = AppleProvider(
///   webAuthenticationOptions: WebAuthenticationOptions(
///     clientId: 'com.example.app.service',
///     redirectUri: Uri.parse('https://example.com/callbacks/sign_in_with_apple'),
///   ),
/// );
///
/// final client = AuthyraClient(
///   providers: [appleProvider],
///   storage: SecureAuthStorage(),
/// );
///
/// await client.signIn('apple');
/// ```
///
/// ## Without a backend exchange
///
/// By default, [signIn] returns Apple's identity directly: no application
/// session token is set, and the raw credential
/// ([AppleCredential.identityToken], [AppleCredential.authorizationCode]) is
/// stored in [AuthAccount.providerData]. This is enough if you hand that
/// credential to Firebase's or Supabase's own Apple sign-in, which accept it
/// directly.
///
/// ## With a backend exchange
///
/// Use [AppleProvider.withExchange] to forward the credential to your own
/// backend and return real application session tokens:
///
/// ```dart
/// AppleProvider.withExchange(
///   webAuthenticationOptions: myWebAuthOptions,
///   exchangeCredential: (credential) async {
///     final res = await myApi.post('/auth/apple', body: {
///       'authorizationCode': credential.authorizationCode,
///       'identityToken': credential.identityToken,
///     });
///     if (res.statusCode != 200) return null;
///     return AuthSignInResult(
///       user: AuthUser(id: res.data['userId'], email: res.data['email']),
///       accessToken: res.data['accessToken'],
///       refreshToken: res.data['refreshToken'],
///       expiresAt: DateTime.parse(res.data['expiresAt']),
///     );
///   },
/// );
/// ```
///
/// ## Token refresh
///
/// [supportsRefresh] is always `false`. Renewing an Apple-issued token
/// requires a server-held ES256 client secret; this provider never asks you
/// to embed that key in the app. If you need silent refresh, implement it
/// against your own backend's refresh endpoint, the same way any
/// [AppleCredentialExchange]-issued session would be refreshed.
///
/// ## Known limitation
///
/// On Android, if the user closes the Chrome Custom Tab without completing
/// the flow, the underlying `sign_in_with_apple` call never resolves. This
/// is a limitation of that package, not something Authyra can work around;
/// give users a way to cancel from your own UI (e.g., a timeout in your
/// sign-in screen) if this matters for your app.
///
/// See also:
/// - [AppleCredential], the raw credential passed to [AppleCredentialExchange].
/// - [AuthSignInResult], for the credential vs. session-token contract.
class AppleProvider with AuthyraLogging implements AuthProvider {
  /// Scopes requested from Apple. Defaults to email and full name; both are
  /// only honored on the first authorization (see [AppleCredential.email]).
  final List<AppleIDAuthorizationScopes> scopes;

  /// Required on Android and web; ignored on iOS/macOS.
  final WebAuthenticationOptions? webAuthenticationOptions;

  final AppleCredentialExchange? _exchangeCredential;

  static const _defaultScopes = [
    AppleIDAuthorizationScopes.email,
    AppleIDAuthorizationScopes.fullName,
  ];

  /// Creates an [AppleProvider] that surfaces Apple's identity directly,
  /// without exchanging it for an application session.
  AppleProvider({
    this.scopes = _defaultScopes,
    this.webAuthenticationOptions,
  }) : _exchangeCredential = null;

  /// Creates an [AppleProvider] that forwards the Apple credential to
  /// [exchangeCredential] and returns its result.
  AppleProvider.withExchange({
    required AppleCredentialExchange exchangeCredential,
    this.scopes = _defaultScopes,
    this.webAuthenticationOptions,
  }) : _exchangeCredential = exchangeCredential;

  @override
  String get id => 'apple';

  @override
  String get name => 'Apple';

  /// Always `false`; see the class-level "Token refresh" section.
  @override
  bool get supportsRefresh => false;

  /// Always `false`; Apple exposes no client-side revocation call.
  @override
  bool get supportsSignOut => false;

  @override
  Future<AuthSignInResult?> signIn({AuthSignInParams? params}) async {
    try {
      logInfo('Starting Sign in with Apple');

      final result = await SignInWithApple.getAppleIDCredential(
        scopes: scopes,
        webAuthenticationOptions: webAuthenticationOptions,
      );

      logInfo('Apple authorization received');

      final credential = AppleCredential(
        userIdentifier: result.userIdentifier,
        identityToken: result.identityToken,
        authorizationCode: result.authorizationCode,
        email: result.email,
        givenName: result.givenName,
        familyName: result.familyName,
      );

      final exchange = _exchangeCredential;
      if (exchange != null) {
        return await exchange(credential);
      }

      return _identityOnlyResult(credential);
    } on AuthException {
      rethrow;
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        throw AuthenticationCancelledException(id);
      }
      logError('Sign in with Apple authorization failed', e);
      throw AuthenticationFailedException(
        e.message,
        providerName: id,
        originalError: e,
      );
    } on SignInWithAppleException catch (e) {
      logError('Sign in with Apple failed', e);
      throw AuthenticationFailedException(
        'Failed to sign in with Apple',
        providerName: id,
        originalError: e,
      );
    } catch (e, stackTrace) {
      logError('Unexpected error during Sign in with Apple', e, stackTrace);
      throw AuthenticationFailedException(
        'Failed to sign in with Apple',
        providerName: id,
        originalError: e,
      );
    }
  }

  @override
  Future<void> signOut({String? userId}) async {
    logDebug('signOut called for Apple, no-op (no client-side revocation)');
  }

  @override
  Future<AuthTokenResult?> refreshToken(String refreshToken) async => null;

  /// Builds an identity-only [AuthSignInResult] when no
  /// [AppleCredentialExchange] is configured. Falls back to decoding
  /// [AppleCredential.identityToken] for the subject claim when
  /// [AppleCredential.userIdentifier] is unavailable (Android).
  AuthSignInResult _identityOnlyResult(AppleCredential credential) {
    final claims = credential.identityToken != null
        ? _decodeJwtPayload(credential.identityToken!)
        : null;

    final userId = credential.userIdentifier ?? claims?['sub'] as String?;
    if (userId == null) {
      throw AuthenticationFailedException(
        'Apple returned neither a userIdentifier nor a decodable identityToken',
        providerName: id,
      );
    }

    final nameParts = [credential.givenName, credential.familyName]
        .whereType<String>()
        .where((part) => part.isNotEmpty);
    final name = nameParts.isEmpty ? null : nameParts.join(' ');

    final user = AuthUser(
      id: userId,
      email: credential.email ?? claims?['email'] as String?,
      name: name,
      metadata: {
        if (claims?['email_verified'] != null)
          'email_verified': claims!['email_verified'],
      },
    );

    return AuthSignInResult(
      user: user,
      account: AuthAccount(
        id: '${id}_${user.id}',
        userId: user.id,
        providerId: id,
        providerAccountId: user.id,
        providerData: {
          if (credential.identityToken != null)
            'identityToken': credential.identityToken,
          'authorizationCode': credential.authorizationCode,
        },
      ),
    );
  }
}

/// Decodes a JWT payload without verifying its signature.
///
/// Apple's native SDK has already handled the authorization on-device; this
/// is only used to recover profile claims for the identity-only path above.
/// A backend performing an [AppleCredentialExchange] should verify the token
/// properly against Apple's public keys before trusting its claims.
Map<String, dynamic>? _decodeJwtPayload(String token) {
  final parts = token.split('.');
  if (parts.length != 3) return null;
  try {
    final payload =
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
    return jsonDecode(payload) as Map<String, dynamic>;
  } catch (_) {
    return null;
  }
}

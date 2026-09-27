# authyra_apple

Native Sign in with Apple provider for [Authyra](https://pub.dev/packages/authyra), built on [`sign_in_with_apple`](https://pub.dev/packages/sign_in_with_apple).

Replaces the browser-based `AppleProvider` that shipped in `authyra_flutter` 0.1.0. App Store Review Guideline 4.8 requires the native Sign in with Apple UI whenever another social login is offered on iOS; a browser-based OAuth2 flow does not satisfy that requirement.

## Install

```yaml
dependencies:
  authyra:
    path: ../authyra # or the published version
  authyra_apple:
    path: ../authyra_apple # or the published version
```

## Setup

1. Enable the **Sign in with Apple** capability for your app identifier in the Apple Developer portal.
2. iOS and macOS need no further configuration beyond the capability.
3. Android and web additionally need a Services ID and `webAuthenticationOptions`:
   - Create a Services ID at [developer.apple.com](https://developer.apple.com/account/resources/identifiers/list/serviceId) and configure its return URL.
   - On Android, add the matching intent filter to `AndroidManifest.xml` as documented in [`sign_in_with_apple`'s README](https://pub.dev/packages/sign_in_with_apple#configuring-android). No Dart-level deep-link wiring is needed; the plugin handles the redirect natively.

## Usage

### Identity only (no backend exchange)

```dart
import 'package:authyra/authyra.dart';
import 'package:authyra_apple/authyra_apple.dart';

final appleProvider = AppleProvider(
  webAuthenticationOptions: WebAuthenticationOptions(
    clientId: 'com.example.app.service',
    redirectUri: Uri.parse('https://example.com/callbacks/sign_in_with_apple'),
  ),
);

final client = AuthyraClient(
  providers: [appleProvider],
  storage: SecureAuthStorage(), // from authyra_flutter
);

await client.initialize();
final user = await client.signIn('apple');
```

No application session token is set in this mode. Apple's raw credential (`identityToken`, `authorizationCode`) is stored in `AuthAccount.providerData`, not in `accessToken`/`refreshToken`. This is enough if you hand it directly to Firebase's or Supabase's own Apple sign-in.

### With a backend exchange

```dart
AppleProvider.withExchange(
  webAuthenticationOptions: myWebAuthOptions,
  exchangeCredential: (credential) async {
    final res = await myApi.post('/auth/apple', body: {
      'authorizationCode': credential.authorizationCode,
      'identityToken': credential.identityToken,
    });
    if (res.statusCode != 200) return null;
    return AuthSignInResult(
      user: AuthUser(id: res.data['userId'], email: res.data['email']),
      accessToken: res.data['accessToken'],
      refreshToken: res.data['refreshToken'],
      expiresAt: DateTime.parse(res.data['expiresAt']),
    );
  },
);
```

## Token refresh

`supportsRefresh` is always `false`. Renewing an Apple-issued token requires a server-held ES256 client secret; this provider never asks you to embed that key in the app. Implement refresh against your own backend if you need it: the backend that received `authorizationCode` via `exchangeCredential` is the one that holds the client secret and can call Apple's token endpoint.

## Known limitation

On Android, if the user closes the Chrome Custom Tab without completing the flow, the underlying `sign_in_with_apple` call never resolves. This is a limitation of that package, not something Authyra can work around.

## License

MIT

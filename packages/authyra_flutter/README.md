# authyra_flutter

[![pub.dev](https://img.shields.io/pub/v/authyra_flutter.svg)](https://pub.dev/packages/authyra_flutter)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/meragix/authyra/blob/main/LICENSE)

Flutter layer for [authyra](https://pub.dev/packages/authyra). Adds OAuth2 providers (Google, GitHub, Apple), `SecureAuthStorage`, and a `AuthGuard` widget on top of the core framework. Re-exports the entire `authyra` package: one import, everything included.

---

## Installation

```yaml
dependencies:
  authyra_flutter: ^0.1.0
```

---

## Quick start

```dart
import 'package:authyra_flutter/authyra_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Authyra.initialize(
    client: AuthyraClient(
      providers: [
        CredentialsProvider.withTokens(
          id: 'email',
          authorize: (creds) async {
            final res = await myApi.post('/auth/login', body: creds);
            if (res.statusCode != 200) return null;
            return AuthSignInResult(
              user: AuthUser(id: res.data['id'], email: res.data['email']),
              accessToken: res.data['accessToken'],
              refreshToken: res.data['refreshToken'],
              expiresAt: DateTime.parse(res.data['expiresAt']),
            );
          },
        ),
        GoogleProvider(clientId: 'YOUR_GOOGLE_CLIENT_ID'),
        GitHubProvider(
          clientId: 'YOUR_GITHUB_CLIENT_ID',
          redirectUri: 'myapp://auth/callback',
        ),
      ],
      storage: SecureAuthStorage(),
    ),
  );

  runApp(const MyApp());
}
```

---

## Providers

### Google

```dart
final googleProvider = GoogleProvider(
  clientId: 'YOUR_CLIENT_ID',
  // redirectUri defaults to com.googleusercontent.apps.<clientId>:/oauth2redirect
  // scopes default to ['openid', 'email', 'profile']
);

await Authyra.instance.signIn('google');
```

### GitHub

```dart
final githubProvider = GitHubProvider(
  clientId: 'YOUR_CLIENT_ID',
  redirectUri: 'myapp://auth/callback',
  // scopes default to ['read:user', 'user:email']
);

await Authyra.instance.signIn('github');
```

Both `GoogleProvider` and `GitHubProvider` extend `OAuth2Provider`, so a single `OAuth2CallbackHandler.handleCallback` wiring at startup (see [Deep-link setup](#deep-link-setup)) covers every OAuth2-based provider you register, even if they share a redirect scheme.

### Apple

```dart
final appleProvider = AppleProvider(
  clientId: 'com.example.myapp',
  redirectUri: 'https://example.com/auth/apple/callback',
);

await Authyra.instance.signIn('apple');
```

`AppleProvider` manages its own pending flow directly; it is not routed through `OAuth2CallbackHandler`. Wire its deep link separately (see [Deep-link setup](#deep-link-setup)).

### Any OAuth2 provider

`OAuth2Provider` handles any standards-compliant IdP with PKCE:

```dart
final discordProvider = OAuth2Provider(
  config: OAuth2Config(
    providerName:          'discord',
    clientId:              'YOUR_CLIENT_ID',
    authorizationEndpoint: 'https://discord.com/oauth2/authorize',
    tokenEndpoint:         'https://discord.com/api/oauth2/token',
    userInfoEndpoint:      'https://discord.com/api/users/@me',
    redirectUri:           'myapp://auth/callback',
    scopes:                ['identify', 'email'],
    usePkce:               true,
    userExtractor: (json) => AuthUser(
      id:    json['id']       as String,
      email: json['email']    as String?,
      name:  json['username'] as String?,
    ),
  ),
);
```

### Proxy OAuth (backend-delegated)

Keeps the client secret and code exchange on your server. The app only opens the browser and receives a custom token via deep link:

```dart
final googleProxy = ProxyOAuthProvider(
  config: ProxyOAuthConfig(
    providerName:       'google',
    initiationEndpoint: 'https://api.example.com/auth/google/initiate',
    callbackEndpoint:   'https://api.example.com/auth/google/callback',
    appCallbackScheme:  'myapp://auth/callback',
    backendRedirectUri: 'https://api.example.com/auth/google/oauth-callback',
    userExtractor: (json) => AuthUser(
      id:    json['id']    as String,
      email: json['email'] as String?,
    ),
  ),
);

// Wire deep-link in your link handler:
AppLinks().uriLinkStream.listen((uri) {
  if (uri.toString().startsWith('myapp://auth/callback')) {
    googleProxy.handleDeepLink(uri);
  }
});
```

---

## Storage

`SecureAuthStorage` wraps [`flutter_secure_storage`](https://pub.dev/packages/flutter_secure_storage) (Keychain on iOS, Keystore on Android). Use it as-is, no configuration required.

```dart
storage: SecureAuthStorage()
```

---

## Reactive UI

### `StreamBuilder`

```dart
StreamBuilder<AuthState>(
  stream: Authyra.instance.authStateChanges,
  builder: (context, snapshot) {
    final state = snapshot.data ?? AuthState.unauthenticated();
    return switch (state.type) {
      AuthStateType.authenticated   => Dashboard(user: state.user!),
      AuthStateType.unauthenticated => LoginPage(),
      AuthStateType.error           => ErrorPage(message: state.error!),
    };
  },
);
```

### Synchronous state (no await)

```dart
if (Authyra.instance.isAuthenticated) {
  final name = Authyra.instance.currentUser?.name;
}
```

---

## Multi-account

```dart
// List signed-in accounts
final users = await Authyra.instance.accounts.getAll();

// Switch active account
await Authyra.instance.accounts.switchTo(userId);

// Sign out a specific account
await Authyra.instance.accounts.signOut(userId);

// Sign out all accounts
await Authyra.instance.accounts.signOutAll();
```

---

## Deep-link setup

`OAuth2Provider`-based providers (`GoogleProvider`, `GitHubProvider`, any custom `OAuth2Provider`) rely on deep links to receive the authorization callback. Wire this once at startup, no per-provider registration needed:

```dart
AppLinks().uriLinkStream.listen(OAuth2CallbackHandler.handleCallback);
```

Routing is keyed by the CSRF `state` each sign-in attempt generates, not by URI scheme, so two providers can safely share the same redirect scheme (e.g. `myapp://auth/callback` for both GitHub and a custom Discord provider).

`AppleProvider` and `ProxyOAuthProvider` manage their own pending flow directly and are not routed through `OAuth2CallbackHandler`; wire their deep link explicitly instead:

```dart
AppLinks().uriLinkStream.listen((uri) {
  appleProvider.handleRedirectCallback(uri);
  if (uri.toString().startsWith('myapp://auth/callback')) {
    googleProxy.handleDeepLink(uri);
  }
});
```

---

## Documentation

[meragix.github.io/authyra](https://meragix.github.io/authyra)

## License

MIT

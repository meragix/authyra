# Authyra Demo

An interactive Flutter app instrumented with [Authyra](https://github.com/meragix/authyra). No OAuth client ID, no backend, run it and try it.

```bash
flutter pub get
flutter run
```

Tap **Continue with demo account** and you're in.

## What it demonstrates

| Tab | What it shows |
|---|---|
| **Dashboard** | The live `AuthSession` object (`session.toJson()`), real expiry countdown, and a "Force refresh" button that triggers Authyra's actual `refreshSession()` flow. Tokens are short-lived (60s) on purpose, leave the tab open and watch the background `TokenRefresher` renew it on its own. |
| **Accounts** | Multi-account: add more demo accounts, switch between them, sign one out without touching the others. All backed by `AccountManager`, no mock state. |
| **Events** | Live feed from `AuthEventBus`, every `SignInEvent`, `TokenRefreshEvent`, `AccountSwitchEvent`, etc. as it happens. |
| **Playground** | The distinction that trips people up: `AuthCallbacks` can block a sign-in (try a wrong password 3 times), `AuthyraPlugin` can only observe one. Both react to the same attempt in this screen. |

## Architecture

```text
lib/
├── core/
│   ├── demo/       # DemoAuthProvider (fake backend), rate-limit callback,
│   │                 audit plugin, event log bridging AuthEventBus to the UI
│   ├── theme/      # shadcn_ui ShadThemeData
│   └── widgets/    # JsonTreeView, SectionCard
├── features/
│   ├── auth/       # AuthCubit + login page
│   ├── dashboard/  # SessionCubit + session inspector
│   ├── accounts/   # AccountsCubit + multi-account UI
│   ├── events/     # live event console
│   └── playground/ # callbacks vs plugins
├── shell/          # bottom-nav shell shown once signed in
├── app.dart
└── main.dart
```

Each Cubit is a thin wrapper over the real `Authyra.instance`/`AccountManager` API, no parallel state machine, no mocked Authyra behaviour. The only mock in the whole app is `DemoAuthProvider`'s fake backend, everything Authyra itself does (session lifecycle, multi-account, refresh, events, callbacks, plugins) is the real thing.

UI components are from [shadcn_ui](https://pub.dev/packages/shadcn_ui).

## Adding a real provider

This demo ships with `DemoAuthProvider` only, so it runs with zero configuration. To add Google (or any OAuth2 provider) alongside it:

1. Add `app_links` to `pubspec.yaml`.
2. Build a `GoogleProvider`/`OAuth2Provider` and add it to `AuthyraBootstrap.build()`'s `providers` list, see [`/providers/google`](https://meragix.github.io/authyra/providers/google).
3. Wire `OAuth2CallbackHandler` and `AppLinks().uriLinkStream` in `main()`, before `Authyra.initialize()`, see [`/guides/deep-links`](https://meragix.github.io/authyra/guides/deep-links).

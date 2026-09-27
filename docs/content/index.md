---
seo:
  title: Authyra | The Authentication Orchestrator for Flutter
  description: Authyra is not another identity provider. It's the session, token-refresh, and multi-account layer between your Flutter app and whatever auth infrastructure you choose.
---

::u-page-hero
#title
The auth orchestrator for Flutter. [Not another Identity Provider.]{.text-primary}

#description
Authyra owns your app's session lifecycle: persistence, token refresh, multi-account switching, events. Plug in Firebase, Auth0, or your own API today; swap it later without touching a screen.

#links
  :::u-button
  ---
  color: neutral
  size: xl
  to: /getting-started/installation
  trailing-icon: i-lucide-arrow-right
  ---
  Get started
  :::

  :::u-button
  ---
  color: neutral
  icon: simple-icons-github
  size: xl
  to: https://github.com/meragix/authyra
  variant: outline
  ---
  Star on GitHub
  :::
::

::u-page-section
#title
Providers authenticate. Authyra manages the resulting session.

#description
Most Flutter auth packages bundle the protocol, the identity provider, and your app's session plumbing together. That's convenient until you need a custom backend, a second provider, or more than one signed-in account at once. Authyra sits one layer above: it doesn't replace your provider, it's what happens in your app after that provider says yes.

#features
  :::u-page-feature
  ---
  icon: i-lucide-box
  ---
  #title
  [Pure Dart]{.text-primary} core

  #description
  Zero Flutter dependency in `authyra`, verified: nothing in the core package imports `flutter_*`. Unit-test your auth logic with plain `dart test`, no widget runner required.
  :::

  :::u-page-feature
  ---
  icon: i-lucide-plug
  ---

  #title
  [Provider-agnostic]{.text-primary} by contract

  #description
  `AuthProvider` and `AuthStorage` are interfaces, not base classes tied to one vendor. Swap Google for a custom API, `flutter_secure_storage` for Redis, or mock everything in tests.
  :::

  :::u-page-feature
  ---
  icon: i-lucide-users-round
  ---
  #title
  [Multi-account]{.text-primary} as a first-class concept

  #description
  Several signed-in identities coexist on the device and switch independently through `AccountManager`, not bolted on as an afterthought. Personal and work accounts, side by side.
  :::

  :::u-page-feature
  ---
  icon: i-lucide-refresh-cw
  ---
  #title
  [Token refresh]{.text-primary} you don't hand-roll

  #description
  Providers that set `supportsRefresh: true` get automatic background renewal with retry. When refresh is truly exhausted, the session clears and `authStateChanges` emits, no silent half-states.
  :::

  :::u-page-feature
  ---
  icon: i-lucide-shield-check
  ---

  #title
  OAuth2 with [PKCE]{.text-primary}, when you need it

  #description
  `OAuth2Provider` (in `authyra_flutter`) implements the full Authorization Code + PKCE flow. Prebuilt providers for Google, GitHub, Apple, and a proxy mode that keeps client secrets server-side.
  :::

  :::u-page-feature
  ---
  icon: i-lucide-code-2
  ---
  #title
  [Reactive]{.text-primary} by default

  #description
  `authStateChanges` is a broadcast `Stream<AuthState>` with `Equatable` deduplication. Wire it to `StreamBuilder`, Riverpod, Bloc, or GoRouter with zero boilerplate.
  :::
::

---
seo:
  title: Authyra | The Modular Auth Framework for Dart & Flutter
  description: Build secure, flexible, and type-safe authentication flows. Pure Dart core, native OAuth support, and zero-boilerplate integration.
---

::u-page-hero
#title
Authentication [Simplified.]{.text-primary} Modular by Design.

#description
Authyra is a lightweight yet powerful authentication framework for Dart and Flutter. Focus on your features, we handle the tokens, sessions, and provider logic with a clean, interface-driven approach.

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
Why developers choose Authyra

#features
  :::u-page-feature
  ---
  icon: i-lucide-box
  ---
  #title
  [Pure Dart]{.text-primary} Core
  
  #description
  Zero dependencies on Flutter in the core engine. Perfect for unit testing, server-side Dart, or sharing auth logic between your mobile app and CLI tools.
  :::

  :::u-page-feature
  ---
  icon: i-lucide-shield-check
  ---
  #title
  [Type-Safe]{.text-primary} Sessions
  
  #description
  Stop managing raw Strings. Authyra provides structured objects for Users and Sessions, with built-in expiration tracking and automatic silent refresh.
  :::

  :::u-page-feature
  ---
  icon: i-lucide-users-round
  ---
  #title
  Native [Multi-Account]{.text-primary}
  
  #description
  <!-- Whether it's Google, Apple, or your own custom backend, Authyra’s provider architecture ensures a consistent API across all authentication methods. -->
  Switch between user profiles seamlessly. Authyra manages a session registry, allowing users to stay logged in with multiple accounts (Work, Personal, etc.) simultaneously.
  :::

  :::u-page-feature
  ---
  icon: i-lucide-refresh-cw
  ---
  #title
  Automatic [Token Refresh]{.text-primary}
  
  #description
  Never worry about expired access tokens again. Authyra handles the background refresh logic and ensures your users stay authenticated seamlessly.
  :::

  :::u-page-feature
  ---
  icon: i-lucide-fingerprint
  ---
  #title
  Security [Best Practices]{.text-primary}
  
  #description
  Designed with OWASP and OAuth2 standards in mind. Secure credential handling, PKCE-ready flows, and isolated storage namespaces by default.
  :::

  :::u-page-feature
  ---
  icon: i-lucide-code-2
  ---
  #title
  [Minimal]{.text-primary} Boilerplate
  
  #description
  Initialize, sign in, and listen to state changes. Authyra is designed to be integrated in minutes, with clean Streams and reactive state management.
  :::
::

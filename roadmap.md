# Authyra — Roadmap

> Last updated: 2026-03-24. Items already shipped are not listed.

---

## v0.1.0 — MVP Release _(current)_

**Goal:** first publishable version on pub.dev.

### Blocking

- [ ] Test coverage ≥ 80% (`melos run test:coverage`)
  - `SessionManager` (mock storage)
  - `AuthyraClient` sign-in / sign-out flows
  - `CredentialsProvider`
  - `InMemoryStorage`
  - Plugin hooks isolation

### Architecture fixes

- [x] `AuthEventBus` scoped per `AuthyraClient` — no singleton ✅
- [x] Auto-refresh end-to-end: `getSession()` → `shouldRefresh()` → `provider.refreshToken()` → persist → emit `TokenRefreshEvent` / `SessionExpiredEvent` ✅

### Release gates

- [ ] `melos run analyze` — no issues ✅ _(done)_
- [ ] `melos run publish:check` — dry-run passes
- [ ] CHANGELOG up to date

---

## v0.2.0 — DX & Extensibility

**Goal:** make Authyra trivially extensible and zero-friction to configure.

### HTTP middleware for OAuth2 providers

- [ ] Expose `List<Interceptor>` in `OAuth2Config`
- [ ] `OAuth2Provider` registers them on its Dio instance
- [ ] Enables custom headers, retry, logging from outside the provider

### Passwordless providers (abstracts only, no impl)

- [ ] `MagicLinkProvider` abstract (`sendLink(email)` + `verifyToken(token)`)
- [ ] `PhoneProvider` abstract (`sendOtp(phone)` + `verifyOtp(otp)`)

---

## v0.3.0 — Flutter UI

**Goal:** production-ready pre-built widgets.

### Components (`authyra_flutter`)

- [ ] `AuthyraLoginForm` — email/password, ready-to-use
- [ ] `AuthyraOAuthButtons` — Google, GitHub, Apple
- [ ] `AuthyraAccountSwitcher` — multi-account tile list
- [ ] `AuthyraProfileCard` — user card with avatar

### Theming & polish

- [ ] `AuthyraTheme` (colors, shapes, typography)
- [ ] Dark mode support
- [ ] Loading + error animations
- [ ] `buildWhen` in `AuthBuilder` to avoid unnecessary rebuilds

### Accessibility

- [ ] Semantics on all widgets
- [ ] Keyboard navigation
- [ ] Screen reader support

### Tests

- [ ] Widget tests for all components
- [ ] Golden tests
- [ ] Coverage ≥ 80%

---

## v0.4.0 — Advanced Auth Flows

**Goal:** cover enterprise-grade requirements.

### Auth flows

- [ ] Email verification flow
- [ ] Password reset flow
- [ ] Two-factor authentication (TOTP-based)

### Session management

- [ ] Configurable session timeout
- [ ] "Remember me" support
- [ ] Device tracking (opt-in, via `SessionMetadata`)
- [ ] Concurrent session handling

### Providers

- [ ] `GitHubAuthProvider`
- [ ] Background token refresh (proactive, before expiry)

### Tests

- [ ] Coverage ≥ 90%

---

## v0.5.0 — Beta

**Goal:** stabilise before production release.

- [ ] All known bugs fixed
- [ ] Performance audit (token caching, lazy account loading)
- [ ] Security audit
- [ ] Documentation site complete (authyra.dev)
- [ ] Migration guides (from Firebase Auth, Supabase Auth)
- [ ] Integration tests end-to-end
- [ ] Discord + contributing guidelines

---

## v1.0.0 — Production

**Goal:** stable public release.

- [ ] All tests pass, coverage ≥ 90%
- [ ] `dart pub publish` on pub.dev for `authyra` and `authyra_flutter`
- [ ] GitHub release with full changelog
- [ ] Announcement (r/FlutterDev, X, LinkedIn)

---

## v1.1.0+ — Ecosystem

### DX tooling

- [ ] `authyra_lints` — custom lint rules (uninitialised storage, providers without `refreshToken` override, unhandled `AuthException`)

### Platform features

- [ ] Biometric authentication (Face ID, Touch ID, fingerprint)
- [ ] Web Auth API (WebAuthn / Passkeys)
- [ ] Platform-native secure storage hints (iOS Keychain, Android Keystore)

### Integrations

- [ ] `authyra_firebase` — Firebase Auth adapter
- [ ] `authyra_supabase` — Supabase Auth adapter
- [ ] `authyra_appwrite` — Appwrite adapter
- [ ] Redis session store adapter

### Enterprise

- [ ] SSO / SAML provider
- [ ] Organization / tenant support
- [ ] Rate limiting & brute-force protection
- [ ] Audit logs
- [ ] GDPR compliance helpers

---

## Proposition de valeur

Firebase Auth = lock-in Firebase. Supabase Auth = lock-in Supabase.

**Authyra** is the auth framework that runs identically in a Flutter mobile app and a Shelf/Dart Frog server — same core, no vendor dependency. The two non-negotiable pillars to deliver this:

1. **Plugin system** — community builds adapters (Redis, 2FA, analytics) without touching core ✅ _(done)_
2. **`AuthAccount` model** — multi-provider account-linking, expected in any modern auth framework ✅ _(done)_

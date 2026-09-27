# Provider Strategy & MVP Plan

Internal planning document. Captures the architecture audit and the provider strategy decisions made before the public 0.1 release, plus the concrete checklist to get there.

## 1. Audit of the current codebase

What already matches the target architecture, no changes needed:

- **Provider/session separation.** `AuthProvider` is stateless; `AuthyraClient` builds `AuthAccount`/`AuthSession` from the provider's result, never the other way around (`authyra_client.dart`, `signIn()`).
- **Plugins vs callbacks.** `AuthyraPlugin` hooks are observers, they cannot block anything. `AuthCallbacks` is the only gate (allow/deny via `CallbackResult`). Keep this split; do not let plugins grow blocking semantics.
- **Generic OAuth2 + prebuilt configs.** `OAuth2Provider` carries the protocol; `GoogleProvider`/`GitHubProvider` only supply an `OAuth2Config` and a `userExtractor`. This is the right shape for adding more HTTP OAuth providers without new provider classes.

Debt found that needs fixing before/around the public release:

- **Duplicated browser-OAuth state machine.** `OAuth2Provider`, `AppleProvider`, and `ProxyOAuthProvider` each reimplement PKCE, `state` generation, the `Completer` + `launchUrl` + timeout dance, and cleanup. Same security-sensitive logic, three copies.
- **Fragile callback routing.** `OAuth2CallbackHandler` routes by URI `scheme` only. Two OAuth2 providers sharing a scheme silently collide (documented as a known limitation instead of being fixed).
- **`AuthProviderType` is decorative.** Declared and assigned everywhere, never branched on anywhere in `authyra_client.dart` or elsewhere.
- **`AppleProvider` is browser-based (PKCE + external browser).** This does not satisfy Apple's App Store Review Guideline 4.8, which requires the native Sign in with Apple UI when another social login is offered on iOS.
- **No CI gate.** `.github/workflows/deploy-docs.yml` only builds and deploys the docs site. Nothing runs `dart analyze`, `dart format --set-exit-if-changed`, or `dart test` on push/PR, even though the melos scripts for all three already exist.
- **`AuthCallbacks` and `AuthyraPlugin` have no test coverage.** Every other core module does (`authyra_client_test.dart`, `session_manager_test.dart`, `account_manager_test.dart`, `credentials_provider_test.dart`, `session_registry_test.dart`, `memory_storage_test.dart`).
- **`ProxyOAuthProvider` has no test coverage** (`OAuth2Provider` and `GoogleProvider` do).
- **`GitHubProvider` requires a client secret embedded in the mobile app.** The doc comment already flags this as a security note; it needs to be a first-class warning, not a paragraph buried in dartdoc.

## 2. Decision: one strategy per provider, no dual-mode providers

| Provider | Strategy | Why |
|---|---|---|
| Google | HTTP OAuth2 / PKCE | `OAuth2Provider` already covers it; the marginal cost of adding Google to a protocol shared with GitHub/Discord/Slack/GitLab/Auth0/custom is near zero. A native SDK would add a whole new package, per-platform config (SHA-1, `google-services.json`), and its own breaking-change cycle, for a UX gain that does not offset that cost at this stage. |
| Facebook | HTTP OAuth2 | Same reasoning. Facebook exposes a standard OAuth2 authorization/token endpoint; `flutter_facebook_auth` brings heavy per-platform setup for a marginal gain (native app handoff only). Not part of the MVP; add later using the existing `OAuth2Provider` pattern. |
| Apple | Native SDK (`sign_in_with_apple`) | Not a preference, a compliance requirement: App Store Guideline 4.8 mandates the native Sign in with Apple UI when another social login is present on iOS. The package also covers Android and web through an internal web-based flow, so one implementation covers every platform. |
| GitHub, Discord, Slack, GitLab, Auth0, custom | HTTP OAuth2 / OIDC | This is exactly what `OAuth2Provider` exists for. No SDK brings enough value here. |

No provider ships both an HTTP and an SDK implementation at once. One provider, one strategy.

## 3. Architectural fixes

### 3.1 Lock the credential vs session-token semantics

Rule: `AuthSignInResult.accessToken` / `refreshToken` are **application session tokens only**. Raw identity-provider credentials (Google `idToken`, provider-issued opaque tokens meant for a further exchange, etc.) go into `AuthAccount.providerData`, which already exists for exactly this purpose. No new type is introduced for this; the existing `Map<String, dynamic>` is enough for 0.x. Document the rule explicitly in the doc comments of `AuthSignInResult` and `AuthAccount` so it cannot drift silently.

### 3.2 Factor the shared browser-OAuth flow

Extract PKCE/state generation, the `Completer<Map<String,String>>` + `launchUrl` + timeout wait, error/cancellation checks, and cleanup into a single shared mixin (e.g. `OAuthBrowserFlow`). `OAuth2Provider` and `ProxyOAuthProvider` consume it. `AppleProvider` is retired in favor of the native package (3.4), so it does not need migrating onto this mixin.

### 3.3 Route callbacks by `state`, not by `scheme`

Replace the `scheme -> provider` map in `OAuth2CallbackHandler` with a `state -> Completer` registry. Each flow already generates a unique `state` for CSRF protection; reusing it as the routing key removes the same-scheme collision risk by construction instead of documenting it as a caveat. This naturally lives inside the shared mixin from 3.2.

### 3.4 Replace `AppleProvider` with a native package

Retire the current browser-based `AppleProvider` from `authyra_flutter`. Ship a new `authyra_apple` package wrapping `sign_in_with_apple`, implementing the same `AuthProvider` contract. This is a breaking change for anyone who adopted the 0.1.0 `AppleProvider`; document it clearly in both changelogs.

### 3.5 Resolve `AuthProviderType`

Either wire a real behavior that branches on it, or remove it. Default: remove it for 0.x. Nothing currently reads it besides doc comments.

## 4. Target package layout

```
authyra              core contracts, pure Dart (already publish-ready)
authyra_flutter      SecureAuthStorage, OAuth2Provider, ProxyOAuthProvider,
                     CredentialsProvider re-export, Flutter logging/UI helpers
authyra_apple        new: AppleProvider wrapping sign_in_with_apple
```

Not part of the MVP, revisit only once a real case demands it:

- `authyra_google` / `authyra_facebook` native packages
- Firebase/Supabase adapters
- A `CredentialProvider`/`SessionProvider` hierarchy split

## 5. MVP checklist: what is actually needed to publish

### Core (`authyra`)

- [x] Document the credential vs session-token rule (3.1)
- [x] Remove `AuthProviderType` or justify it with real branching logic (3.5). Removed entirely: nothing branched on it.
- [ ] Add test coverage for `AuthCallbacks` (deny paths for each hook) and `AuthyraPlugin` (install + hook invocation, plugin exceptions swallowed and logged)
- [ ] `dart pub publish --dry-run` clean (`melos run publish:check`)
- [ ] `CHANGELOG.md` reflects the final pre-release state, `[Unreleased]` cut into a real version

### Providers (`authyra_flutter`)

- [x] Factor the shared browser-OAuth mixin (3.2). Done as `PendingRedirectFlow` + `OAuthSecurityValues`, consumed by `OAuth2Provider` and `ProxyOAuthProvider`. Unit-tested (`pending_redirect_flow_test.dart`, `oauth_security_values_test.dart`).
- [x] Fix callback routing by `state` (3.3). `OAuth2CallbackHandler` now routes by `state`, not scheme; `registerProvider`/`unregisterProvider` removed. Unit-tested (`oauth2_callback_handle_test.dart`), including the same-scheme collision case.
- [x] Remove `AppleProvider`; migrate its doc/example references to `authyra_apple`. Also removed the now-unused `dart_jsonwebtoken` dependency and the ES256-client-secret `JwtUtils` that only served the old provider.
- [ ] Add test coverage for `ProxyOAuthProvider` (state handling, timeout, deep-link error/cancel paths)
- [ ] Add test coverage for the new `state`-based callback routing (collision case included)
- [ ] Elevate the `GitHubProvider` client-secret warning to a prominent README/dartdoc callout: recommend `ProxyOAuthProvider` for production mobile apps instead of embedding the secret
- [ ] Decide whether `authyra_flutter` flips from `publish_to: none` to a real publish for the MVP, or stays internal one more cycle

### New package `authyra_apple`

- [x] Scaffold under `packages/authyra_apple` following the existing package conventions (`analysis_options.yaml`, melos workspace entry)
- [x] `AppleProvider` built on `sign_in_with_apple`, implementing `AuthProvider`. Ships two constructors: identity-only (raw credential in `AuthAccount.providerData`) and `.withExchange` (forwards the credential to a backend, returns real session tokens), mirroring the `CredentialsProvider`/`CredentialsProvider.withTokens` pattern.
- [x] Tests (mock the native call surface where possible). 11 tests against a fake `SignInWithApplePlatform`, covering identity-only, `.withExchange`, JWT-fallback decoding, and error mapping (cancellation, authorization failure, not-supported).
- [x] README covering entitlements/capabilities setup for iOS, Android, and web

### Security

- [ ] Confirm PKCE stays enabled by default and `state` CSRF verification is enforced in every OAuth2 flow (already true, re-verify after the mixin extraction)
- [ ] Document `SecureAuthStorage` as the required backend for production; mark `InMemoryStorage` as dev/test-only in its dartdoc and README
- [ ] Run the project's `/security-review` skill on the diff before tagging the release

### CI

- [x] Add a GitHub Actions workflow running `melos run analyze`, `melos run format:check`, and `melos run test` on push and pull request. Added `.github/workflows/ci.yml`. Along the way, fixed two things that would have made the very first run red: pre-existing format debt unrelated to this work, and a broken `test` script that ran `dart test` uniformly across Flutter packages (they need `flutter test`); see the `chore:` commit right before this one.

### Documentation

- [x] Update `docs/content/3.providers` to reflect the final one-strategy-per-provider decision and the `authyra_apple` package. Went further than just that folder: swept the whole `docs/content` site for stale `OAuth2CallbackHandler.registerProvider`/`AuthProviderType`/browser-based `AppleProvider` references (20 pages) and rewrote `3.providers/5.apple.md` for the new package. Also fixed a pre-existing, unrelated factual error in `3.providers/6.proxy-oauth.md`: it documented `ProxyOAuthProvider` as routed through `OAuth2CallbackHandler`, which was never true, it has always used its own `handleDeepLink`.
- [x] Root and per-package README quick-start covering: one `CredentialsProvider` example, one HTTP `OAuth2Provider` example (Google or GitHub), one `authyra_apple` example. Satisfied across the root README (Quick start) plus each package's own README.
- [x] Changelog entries for the `AppleProvider` removal and the `authyra_apple` introduction, framed as a breaking change

### Release mechanics

- [ ] Decide pub.dev scope for the MVP: `authyra` and `authyra_flutter` public; `authyra_apple` public or kept local until it has real-world usage
- [ ] Version bump via `melos version` (commit links already enabled in `melos.yaml`)
- [ ] Tag the release once the checklist above is green

## 6. Explicit non-goals for the MVP

- No Facebook provider yet
- No Firebase/Supabase adapters
- No `CredentialProvider`/`SessionProvider` hierarchy split
- No native SDK for Google

## 7. Suggested execution order

1. Lock the credential/session-token semantics (3.1), fast, prevents further drift while everything else is being touched
2. Factor the browser-OAuth mixin and switch callback routing to `state` (3.2, 3.3)
3. Remove `AuthProviderType` (3.5)
4. Scaffold `authyra_apple`, retire the old `AppleProvider` (3.4)
5. Fill the test gaps: `AuthCallbacks`, `AuthyraPlugin`, `ProxyOAuthProvider`, `state`-based routing
6. Add the CI workflow so every following change is gated
7. Documentation pass
8. Publish dry-run, changelog, version bump, tag

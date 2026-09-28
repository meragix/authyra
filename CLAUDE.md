# CLAUDE.md

Guidance for AI coding agents working in this repository. This documents decisions already made and traps already found, so they don't get rediscovered or reverted by accident. For human contributor setup, see [CONTRIBUTING.md](CONTRIBUTING.md).

## Architecture

Melos monorepo, three packages, strict dependency direction:

```
packages/
├── authyra/          Core: pure Dart, zero Flutter dependency
├── authyra_flutter/  Flutter layer: OAuth2 providers, SecureStorage, widgets
└── authyra_apple/    Native Sign in with Apple, depends on authyra directly
                       (not on authyra_flutter, they are siblings)
```

A provider that needs a native SDK or a platform-specific plugin gets its own package, following the `authyra_apple` precedent. It never goes into `authyra_flutter`, that would force every consumer of `authyra_flutter` to pull in a native dependency they might not use.

## Invariants: do not casually change these

- **Providers are stateless.** They hold configuration, never session state. Session state lives in `SessionManager`. `AuthProvider` never constructs or persists an `AuthSession` itself, `AuthyraClient` does that from the provider's `AuthSignInResult`.
- **Credential vs. session-token contract.** `AuthSignInResult.accessToken` / `refreshToken` and `AuthAccount.accessToken` / `refreshToken` are **application session tokens**, never a raw identity-provider credential that still needs exchanging (a Google `idToken`, an Apple `identityToken`, an opaque backend token meant for further exchange). A provider that only acquires such a credential without exchanging it itself puts it in `AuthAccount.providerData` instead. See `authyra_apple`'s `AppleProvider` (identity-only constructor plus `.withExchange`) as the reference implementation of this split.
- **`OAuth2CallbackHandler` routes by `state`, not by URI scheme.** `state` is a fresh, cryptographically random value per sign-in attempt; routing on it means two `OAuth2Provider`s can safely share a redirect scheme. There is no `registerProvider(scheme, provider)` anymore, don't reintroduce it, it caused a real collision bug (two providers sharing a scheme silently overwrote each other's registration).
- **`ProxyOAuthProvider` is not routed through `OAuth2CallbackHandler`.** It manages its own pending flow via `handleDeepLink`, called directly by the app. This was documented incorrectly for a long time (docs claimed it used `OAuth2CallbackHandler`); don't reintroduce that assumption.
- **`AppleProvider` (in `authyra_apple`) needs no deep-link wiring at all.** The native SDK resolves the sign-in directly. If you see deep-link plumbing being added for it, something regressed.
- **No `AuthProviderType`.** It was removed deliberately, nothing ever branched on it. Don't add a `type` discriminant back onto `AuthProvider` unless a concrete piece of logic actually needs to dispatch on it.
- **`supportsRefresh` on `AppleProvider` is always `false`.** Renewing an Apple token needs a server-held ES256 client secret; this provider will never ask an app to embed that key. Silent refresh, if needed, belongs to whatever backend performed `.withExchange`.

## Commands

```bash
dart run melos run analyze       # dart analyze across all 3 packages
dart run melos run format:check  # dart format --set-exit-if-changed
dart run melos run test          # dart test (authyra), flutter test (the other two)
```

These three gate CI (`.github/workflows/ci.yml`) on every push and pull request. Run them before considering any change done.

`melos.yaml` scripts shell out to `melos exec ...` themselves; a bare `melos` binary must be on PATH for that inner call to resolve, even when the outer invocation is `dart run melos run <script>` (which only pins the version for the outer call). This is already handled in CI (`dart pub global activate melos` + `$GITHUB_PATH`); if you're setting up a fresh environment and see `melos: not found` from inside a script, that's why.

`melos run test` splits Flutter packages from the pure-Dart one (`--flutter` / `--no-flutter`). `dart test` cannot run `authyra_flutter` or `authyra_apple`, their tests need the Flutter engine/bindings.

## Versioning

`authyra` has published versions `0.1.0` and `0.2.0` on pub.dev, but this repo only has a git tag for `0.1.0`. There is no commit or tag here corresponding to what `0.2.0` actually contains. Before assuming a semver bump is safe, check `git tag -l` against what's actually live on pub.dev (`https://pub.dev/api/packages/authyra`), a version already published there is immutable and `dart pub publish` will refuse to republish it regardless of local content.

`authyra_flutter` and `authyra_apple` are still `publish_to: none`, no pub.dev constraint on them yet.

## Style

Code, comments, commit messages, and all files in this repo are English (this project's own convention, see [CONTRIBUTING.md](CONTRIBUTING.md)). Conventional Commits for commit messages.

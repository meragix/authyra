# Changelog

All notable changes to the `authyra_flutter` package are documented here.

---

## [Unreleased]

### Changed

- **Breaking:** `OAuth2CallbackHandler` now routes incoming deep links by the OAuth CSRF `state` parameter instead of by URI scheme. `registerProvider(scheme, provider)` / `unregisterProvider(scheme)` are removed; `OAuth2Provider` registers and unregisters itself automatically around each `signIn()` call. Apps no longer call any registration method, only `AppLinks().uriLinkStream.listen(OAuth2CallbackHandler.handleCallback)` at startup. This also fixes a real bug: two `OAuth2Provider`s sharing the same redirect scheme used to silently collide (the second registration replaced the first); routing by `state` removes that collision by construction.
- `OAuth2Provider` and `ProxyOAuthProvider` now share a single `PendingRedirectFlow` mixin (launch + await + timeout + cleanup) and, for `OAuth2Provider`, a `OAuthSecurityValues` helper (PKCE/state/nonce generation) instead of each duplicating this state machine. No behavior change for existing sign-in flows.
- `ProxyOAuthProvider._fetchUserInfo` no longer puts the raw deep-link token in `AuthSignInResult.accessToken`. It now returns an `AuthAccount` with the token in `providerData`, following the credential vs. session-token rule documented on `AuthSignInResult`. Only override this behavior by supplying your own `userExtractor` and reading `providerData['token']` if your backend token happens to also be a valid application session token.

## [0.1.0] - 2026-02-23

### Added

- Re-exports the entire `authyra` package: one import covers everything.
- `GoogleProvider`: Google Sign-In via OAuth2 with PKCE and reverse-client-ID deep links.
- `GitHubProvider`: GitHub OAuth2 (client-secret flow, no PKCE).
- `AppleProvider`: Sign in with Apple using ES256 JWT client secrets.
- `OAuth2Provider` / `OAuth2Config`: generic OAuth2 with PKCE for any standards-compliant IdP.
- `ProxyOAuthProvider` / `ProxyOAuthConfig`: backend-delegated OAuth: browser flow on the server, custom token returned via deep link.
- `OAuth2CallbackHandler`: static deep-link router that dispatches incoming URIs to registered providers by URI scheme.
- `SecureAuthStorage`: `AuthStorage` backed by `flutter_secure_storage` (Keychain on iOS/macOS, EncryptedSharedPreferences on Android, Web Crypto on web).
- `AuthyraFlutterLogging`: Flutter-specific log configuration with `useFlutterDefaults()` (`debugPrint` in debug/profile, silent in release) and `useProductionDefaults()` (errors only)

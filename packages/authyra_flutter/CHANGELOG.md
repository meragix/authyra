# Changelog

All notable changes to the `authyra_flutter` package are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [0.1.0] - 2026-02-23

### Added

- Re-exports the entire `authyra` package — one import covers everything.
- `GoogleProvider` — Google Sign-In via OAuth2 with PKCE and reverse-client-ID deep links.
- `GitHubOAuth2Provider` — GitHub OAuth2 (client-secret flow, no PKCE).
- `AppleProvider` — Sign in with Apple using ES256 JWT client secrets.
- `OAuth2Provider` / `OAuth2Config` — generic OAuth2 with PKCE for any standards-compliant IdP.
- `ProxyOAuthProvider` / `ProxyOAuthConfig` — backend-delegated OAuth: browser flow on the server, custom token returned via deep link.
- `OAuth2CallbackHandler` — static deep-link router that dispatches incoming URIs to registered providers by URI scheme.
- `SecureAuthStorage` — `AuthStorage` backed by `flutter_secure_storage` (Keychain on iOS/macOS, EncryptedSharedPreferences on Android, Web Crypto on web).
- `AuthyraFlutterLogging` — Flutter-specific log configuration with `useFlutterDefaults()` (`debugPrint` in debug/profile, silent in release) and `useProductionDefaults()` (errors only).

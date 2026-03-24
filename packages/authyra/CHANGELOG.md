# Changelog

All notable changes to the `authyra` package are documented here.

## [Unreleased]

### Added

- `AuthAccount` model: provider-linked account entry with tokens and `providerData`. Full serialisation and `Equatable`.
- `SessionMetadata` model: optional device/network context (`ipAddress`, `userAgent`, `deviceId`, `country`) attached to a session.
- Typed `AuthSignInParams` hierarchy: `CredentialsSignInParams`, `OAuth2SignInParams`, `MagicLinkSignInParams`, `PhoneSignInParams`. Replaces `Map<String, dynamic>` for provider params.
- `AuthyraClient.events`: per-instance `AuthEventBus` with typed `on<T>()`/`off<T>()` listeners and a raw broadcast `stream`.
- Auto-refresh in `getSession()`: transparently refreshes the token when expiring soon (`autoRefresh: true`). Emits `SessionExpiredEvent` and returns `null` on failure.
- Test suites for `SessionRegistry`, `InMemoryStorage`, `CredentialsProvider`, `SessionManager`, and `AuthyraClient` (107+ tests).

### Changed

- `AuthProvider.signIn` and all callbacks now accept `AuthSignInParams?` instead of `Map<String, dynamic>?`.
- `AuthSession.linkedProviders: List<String>` replaced by `linkedAccounts: List<AuthAccount>`. Added `linkedProviderIds` getter and updated `hasLinkedProvider()`. `fromJson` migrates legacy format gracefully.
- `AuthSession` gains `metadata: SessionMetadata?`; `copyWith`/`toJson`/`fromJson` updated.
- `AuthEventBus` is no longer a singleton — each `AuthyraClient` owns its own instance.
- `AuthyraClient.signIn` auto-generates an `AuthAccount` when the provider doesn't supply one.

### Fixed

- `AuthEventBus.on<T>()`: switched to `List<Function>` with dynamic dispatch to fix Dart contravariance cast error.
- `getSession()` reads `activeSession` directly (bypassing expiry guard) before handing off to auto-refresh logic.

## [0.1.0] - 2026-02-23

### Added

- `AccountManager`: high-level multi-account facade with `getAll()`, `switchTo()`, `signOut()`, `signOutAll()`, and `cleanExpired()`.
- `SessionManager.cleanExpiredSessions()`: atomically prunes expired sessions and persists the full registry in one operation.
- `AuthConfig.copyWith`, `toJson`, `fromJson`: fully serialisable config with `refreshThreshold` and `tokenLifetimeDuration` `Duration` getters.
- `AuthState` extends `Equatable`: deduplicates identical consecutive states in streams, preventing unnecessary UI rebuilds.
- `InMemoryStorage`: non-persistent `AuthStorage` implementation for tests and development.

### Changed

- `MultiAccountManager` renamed to `AccountManager` (deprecated re-export kept until v0.2.0).

### Fixed

- `AccountManager.cleanExpired()`: now delegates to `SessionManager.cleanExpiredSessions()` instead of overwriting a single session.
- `AccountManager.signOut()`: notifies the reactive layer after removing the active account.
- `AuthSession.fromJson()`: `accessToken` and `expiresAt` are cast as nullable, fixing crashes in cookie-based flows.
- `SessionRegistry` account election after expiry removal now orders by `lastUsedAt` (deterministic).
- `AuthUser.copyWith()`: removed phantom parameters (`phoneNumber`, `provider`, `createdAt`) that were silently ignored.

---

## [0.0.1] - 2025-01-01

### Added

- Initial package scaffold.
- `AuthyraClient`: stateless authentication orchestrator.
- `AuthyraInstance`: singleton wrapper with reactive streams.
- `AuthProvider` abstract interface with `CredentialsProvider` implementation.
- `AuthStorage` abstract interface for pluggable session persistence.
- `SessionManager` with multi-account registry.
- `AuthUser`, `AuthSession`, `AuthState`, `AuthConfig`, `SessionRegistry` models

# Changelog

All notable changes to the `authyra` package are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [0.1.0] - 2026-02-23

### Added

- `AccountManager` — high-level multi-account facade with `getAll()`, `switchTo()`, `signOut()`, `signOutAll()`, and `cleanExpired()`.
- `SessionManager.cleanExpiredSessions()` — atomically prunes expired sessions and persists the full registry in one operation.
- `AuthConfig.copyWith`, `toJson`, `fromJson` — fully serialisable config with `refreshThreshold` and `tokenLifetimeDuration` `Duration` getters.
- `AuthState` extends `Equatable` — deduplicates identical consecutive states in streams, preventing unnecessary UI rebuilds.
- `InMemoryStorage` — non-persistent `AuthStorage` implementation for tests and development.

### Changed

- `MultiAccountManager` renamed to `AccountManager` (deprecated re-export kept until v0.2.0).

### Fixed

- `AccountManager.cleanExpired()` — now delegates to `SessionManager.cleanExpiredSessions()` instead of overwriting a single session.
- `AccountManager.signOut()` — notifies the reactive layer after removing the active account.
- `AuthSession.fromJson()` — `accessToken` and `expiresAt` are cast as nullable, fixing crashes in cookie-based flows.
- `SessionRegistry` account election after expiry removal now orders by `lastUsedAt` (deterministic).
- `AuthUser.copyWith()` — removed phantom parameters (`phoneNumber`, `provider`, `createdAt`) that were silently ignored.

---

## [0.0.1] - 2025-01-01

### Added

- Initial package scaffold.
- `AuthyraClient` — stateless authentication orchestrator.
- `AuthyraInstance` — singleton wrapper with reactive streams.
- `AuthProvider` abstract interface with `CredentialsProvider` implementation.
- `AuthStorage` abstract interface for pluggable session persistence.
- `SessionManager` with multi-account registry.
- `AuthUser`, `AuthSession`, `AuthState`, `AuthConfig`, `SessionRegistry` models.

---
title: Changelog
description: Notable changes to the authyra package.
navigation:
  icon: i-lucide-history
seo:
  title: Changelog | Authyra
  description: Release notes for the authyra package, additions, changes, and fixes across versions.
---

Mirrors [`packages/authyra/CHANGELOG.md`](https://github.com/meragix/authyra/blob/main/packages/authyra/CHANGELOG.md) in the repository, the source of truth.

## Unreleased

### Added

- `TokenRefresher`: background token-refresh scheduler with configurable check interval, expiry threshold, and linear retry policy. Owned by `SessionManager`; wired up by `AuthyraClient` at construction time.
- `SessionManager.refreshActiveSession()`: on-demand refresh delegating to `TokenRefresher` with the same retry policy.
- `SessionManager.setRefreshCallbacks(onSuccess, onFailure)`: hook for `AuthyraClient` to emit `TokenRefreshEvent` / `SessionExpiredEvent` on refresh outcome.
- `AuthyraClientBuilder`: fluent builder for configuring and instantiating `AuthyraClient` with custom providers, storage, config, and event bus.
- `AuthyraPlugin`: extension interface for adding cross-cutting behaviour (audit logging, rate limiting) via `install(client)` plus optional `onBeforeSignIn` / `onAfterSignIn` / `onSessionExpired` hooks. Registered via `AuthyraClient(plugins: [...])` or `AuthyraClientBuilder.addPlugin()`.
- `AuthAccount` model: provider-linked account entry with tokens and `providerData`.
- `SessionMetadata` model: optional device/network context (`ipAddress`, `userAgent`, `deviceId`, `country`) attached to a session.
- Typed `AuthSignInParams` hierarchy: `CredentialsSignInParams`, `OAuth2SignInParams`. Replaces `Map<String, dynamic>` for provider params.
- `AuthyraClient.events`: per-instance `AuthEventBus` with typed `on<T>()`/`off<T>()` listeners and a raw broadcast `stream`.
- Auto-refresh in `getSession()`: transparently refreshes the token when expiring soon (`autoRefresh: true`). Emits `SessionExpiredEvent` and returns `null` on failure.

### Changed

- `AuthSession` is now a **pointer** to the active `AuthAccount`: token fields (`accessToken`, `refreshToken`, `expiresAt`, `providerId`) are computed getters delegating to `activeAccount`. The new required field `activeAccountId` identifies the active entry in `linkedAccounts`. Storage format migrates gracefully from the legacy flat structure.
- `AuthProvider.signIn` and all callbacks now accept `AuthSignInParams?` instead of `Map<String, dynamic>?`.
- `AuthSession.linkedProviders: List<String>` replaced by `linkedAccounts: List<AuthAccount>`. Added `linkedProviderIds` getter and updated `hasLinkedProvider()`.
- `AuthSession` gains `metadata: SessionMetadata?`.
- `AuthEventBus` is no longer a singleton, each `AuthyraClient` owns its own instance.
- `AuthyraClient.signIn` auto-generates an `AuthAccount` when the provider doesn't supply one.

### Fixed

- `AuthEventBus.on<T>()`: switched to `List<Function>` with dynamic dispatch to fix a Dart contravariance cast error.
- `getSession()` reads `activeSession` directly (bypassing the expiry guard) before handing off to auto-refresh logic.
- `SessionManager` no longer persists the whole `SessionRegistry` as a single JSON blob. Each account is now stored under its own `session:{userId}` key, so refreshing or removing one account no longer rewrites every other account's tokens. Existing installs migrate the legacy blob automatically on first load.
- `AuthCallbacks.onBeforeAccountSwitch`, `onBeforeTokenRefresh`, and `onBeforeAccountRemove` were defined but never invoked. They're now called from `AccountManager.switchTo()` / `signOut()` and from the token-refresh path, so overriding them actually gates the corresponding operation.
- `AccountSwitchEvent` and `AccountRemovedEvent` were documented in the event catalogue but never emitted. `AccountManager` now emits both.
- `TokenRefresher` retried a denied or unsupported refresh up to `maxRetries` times before expiring the session, even though retrying could never succeed. A `RefreshProvider` can now throw `RefreshDeniedException` to signal a non-retryable refresh; `TokenRefresher` expires the session immediately instead of wasting the retry budget.
- A storage write failure partway through a multi-account save no longer leaves the in-memory registry claiming a mutation succeeded when storage doesn't back it up; it rolls back to the pre-mutation state instead.

## 0.1.0 (2026-02-23)

### Added

- `AccountManager`: high-level multi-account facade with `getAll()`, `switchTo()`, `signOut()`, `signOutAll()`, and `cleanExpired()`.
- `SessionManager.cleanExpiredSessions()`.
- `AuthConfig.copyWith`, `toJson`, `fromJson`.
- `AuthState` extends `Equatable`: deduplicates identical consecutive states in streams.
- `InMemoryStorage`: non-persistent `AuthStorage` implementation for tests and development.

### Changed

- `MultiAccountManager` renamed to `AccountManager`.

### Fixed

- `AccountManager.cleanExpired()` now delegates to `SessionManager.cleanExpiredSessions()` instead of overwriting a single session.
- `AccountManager.signOut()` notifies the reactive layer after removing the active account.
- `AuthSession.fromJson()`: `accessToken` and `expiresAt` cast as nullable, fixing crashes in cookie-based flows.
- `SessionRegistry` account election after expiry removal now orders by `lastUsedAt` (deterministic).
- `AuthUser.copyWith()`: removed phantom parameters that were silently ignored.

## 0.0.1 (2025-01-01)

### Added

- Initial package scaffold: `AuthyraClient`, `AuthyraInstance`, `AuthProvider` with `CredentialsProvider`, `AuthStorage`, `SessionManager`, and the core models (`AuthUser`, `AuthSession`, `AuthState`, `AuthConfig`, `SessionRegistry`).

# Changelog

All notable changes to the `authyra` package are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

### Added

- `AccountManager` (`account_manager.dart`) — high-level multi-account facade replacing `MultiAccountManager`. Renamed for consistency with Better Auth / Auth.js naming conventions.
- `SessionManager.cleanExpiredSessions()` — dedicated method that correctly removes all expired sessions and persists the full cleaned `SessionRegistry` in a single atomic operation.
- `AuthConfig.copyWith`, `toJson`, `fromJson` — `AuthConfig` is now fully serialisable and copyable, enabling environment-specific config overrides and persistent configuration.
- `AuthConfig.refreshThreshold` and `tokenLifetimeDuration` — `Duration`-typed convenience getters derived from the integer second fields.
- `AuthState` now extends `Equatable` — identical consecutive states are deduplicated in streams, preventing unnecessary rebuilds in reactive UIs (Riverpod, BLoC, etc.).

### Changed

- `MultiAccountManager` renamed to `AccountManager` (file: `account_manager.dart`). The old file is retained as a deprecated re-export shim until v0.2.0.
- `_StorageLock` renamed to `_AsyncMutex` in `session_manager.dart` — name now reflects the general-purpose async mutex semantics rather than being tied to storage.
- `SessionManager.initialize()` log messages clarified and made more informative.
- `AuthStorage` dartdoc rewritten — includes implementation guide with `FlutterSecureStorage` example, per-runtime backend recommendations table, and security guidance.

### Fixed

- **`AccountManager.cleanExpired()` (critical)** — previously called `saveSession(activeSession!)` which only wrote a single session and would throw a `Null check operator used on a null value` if all sessions were expired. Now correctly delegates to `SessionManager.cleanExpiredSessions()` which atomically prunes and persists the full registry.
- **`AccountManager.signOut()` (critical)** — after removing the active account, the method now calls `onStateChange` with the new `AuthState` (`authenticated` for the newly elected account, `unauthenticated` if none remain). Previously the reactive layer was never notified, leaving the UI stale.
- **`SessionManager.getActiveSession()`** — removed misleading log line "Attempting auto-refresh for expired session" which implied work was being done. The method now throws `TokenExpiredException` immediately with a clear, actionable message.
- **`SessionRegistry.removeExpiredSessions()`** — election of the new active account after removing expired sessions now sorts by `lastUsedAt` (most recently used wins) instead of using `Map.keys.first`, which is non-deterministic.
- **`SessionRegistry.copyWith()`** — fixed inability to explicitly set `activeUserId` to `null`. Uses an `_unset` sentinel to distinguish "not provided" from an explicit `null` clear.
- **`AuthSession.fromJson()`** — `accessToken` was cast as `String` (non-nullable), throwing a `TypeError` when the field is absent (e.g., cookie-based flows). Now correctly cast as `String?`. Same fix applied to `expiresAt` null-guard.
- **`AuthUser.toString()`** — was missing the closing `)`, producing malformed output: `AuthUser(id: x, email: y` → `AuthUser(id: x, email: y, name: z)`.
- **`AuthUser.copyWith()`** — removed phantom parameters (`phoneNumber`, `provider`, `createdAt`) that were accepted by the signature but silently ignored, leading to confusing call sites.
- **`AuthUser.initials`** — now uses `RegExp(r'\s+')` to handle multiple consecutive spaces in display names.
- **`SessionRegistry.allUsers`** — fixed two bugs introduced by a cascade misuse: `a.id` was called on `AuthSession` (no such getter), and `..map(...).toList()` was used in a cascade (creates and discards the mapped list, returning the unsorted `List<AuthSession>` instead of `List<AuthUser>`).

### Documentation

- Comprehensive `///` dartdoc added across all model and session classes: `AuthUser`, `AuthSession`, `AuthState`, `AuthConfig`, `SessionRegistry`, `SessionManager`, `AccountManager`, `AuthStorage`.
- All dartdoc follows pub.dev conventions: class-level summary, `##` sections, `/// ```dart` code examples, `/// See also:` cross-references, and `/// Throws` annotations.

---

## [0.0.1] - 2025-01-01

### Added

- Initial package scaffold.
- `AuthyraClient` — stateless authentication orchestrator.
- `AuthyraInstance` — singleton wrapper with reactive streams.
- `AuthProvider` abstract interface with `CredentialsProvider`, `OAuth2Provider`, `GoogleAuthProvider`, `GitHubAuthProvider`, and `ProxyOAuthProvider`.
- `AuthStorage` abstract interface for pluggable session persistence.
- `SessionManager` with multi-account registry support.
- `AuthUser`, `AuthSession`, `AuthState`, `AuthConfig`, `SessionRegistry` models.

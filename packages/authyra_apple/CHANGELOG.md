# Changelog

All notable changes to the `authyra_apple` package are documented here.

## [0.1.0] - Unreleased

### Added

- `AppleProvider`: native Sign in with Apple, built on `sign_in_with_apple`. Replaces the browser-based `AppleProvider` that shipped in `authyra_flutter` 0.1.0.
- `AppleProvider.withExchange`: forwards the raw Apple credential to a backend and returns real application session tokens.
- `AppleCredential`: the raw, unexchanged credential (`identityToken`, `authorizationCode`, `userIdentifier`, and first-authorization-only profile fields).

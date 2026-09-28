# Contributing to Authyra

Thanks for considering a contribution. This document covers the practical parts: repo layout, local setup, the checks a PR needs to pass, and commit conventions.

## Project status

Authyra is `0.x`, pre-1.0. The `AuthProvider` / `SessionManager` / `AuthStorage` contract is still allowed to change between minor versions while it proves itself. Expect breaking changes in changelogs, not silent ones.

## Repository layout

This is a [Melos](https://melos.invertase.dev/) monorepo with three packages:

```
packages/
├── authyra/          Core: pure Dart, zero Flutter dependency
├── authyra_flutter/  Flutter layer: OAuth2 providers, SecureStorage, widgets
└── authyra_apple/    Native Sign in with Apple, built on sign_in_with_apple
```

`authyra` has no knowledge of Flutter. Anything that touches platform channels, `url_launcher`, or a native plugin lives in `authyra_flutter` or `authyra_apple`, never in the core.

## Setup

```bash
dart pub global activate melos
melos bootstrap
```

`melos bootstrap` resolves dependencies across all three packages in one pass.

## Before opening a pull request

Run the same checks CI runs:

```bash
dart run melos run analyze       # dart analyze, must report no issues
dart run melos run format:check  # dart format --set-exit-if-changed
dart run melos run test          # dart test (authyra), flutter test (the other two)
```

A pull request that doesn't pass all three won't be merged; CI gates on exactly these. If you're adding behavior, add tests for it in the same PR, not as a follow-up.

## Commit messages

[Conventional Commits](https://www.conventionalcommits.org/), in English:

```
feat(authyra_apple): add withExchange constructor
fix(authyra_flutter): route OAuth2 callbacks by state, not scheme
refactor(authyra): remove decorative AuthProviderType
docs: sync docs/content with the provider strategy changes
chore: fix pre-existing format debt
```

Use a scope that names the affected package (`authyra`, `authyra_flutter`, `authyra_apple`) or area (`docs`, `ci`) when it's not obvious from the message alone.

## Adding a new provider

Every authentication strategy implements the `AuthProvider` interface (`packages/authyra/lib/src/interfaces/auth_provider.dart`). Before writing one:

- Providers are **stateless**: they hold configuration, never session state. Session state lives in `SessionManager`.
- `AuthSignInResult.accessToken` / `refreshToken` are **application session tokens**, never a raw identity-provider credential that still needs exchanging. A provider that only acquires an identity credential (an OAuth `id_token`, an Apple `identityToken`) puts it in `AuthAccount.providerData` instead. See `authyra_apple`'s `AppleProvider` for the pattern (identity-only constructor plus a `.withExchange` variant).
- Return `null` from `signIn` for an expected credential failure; throw an `AuthException` subclass for infrastructure errors.
- `signOut` must never throw.
- A provider that needs a native SDK or a platform-specific dependency belongs in its own package (see why `authyra_apple` is separate from `authyra_flutter` in the root README), not bundled into `authyra_flutter`.

## Reporting bugs and requesting features

Open a [GitHub issue](https://github.com/meragix/authyra/issues). For anything that could be a security vulnerability, see [SECURITY.md](SECURITY.md) instead, don't open a public issue.

## License

By contributing, you agree your contributions are licensed under this project's [MIT License](LICENSE).

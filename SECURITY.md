# Security Policy

## Supported versions

Authyra is `0.x`, pre-1.0. Only the latest published version of each package (`authyra`, `authyra_flutter`, `authyra_apple`) receives security fixes; there is no long-term-support line yet. Once `1.0.0` ships, this policy will be revisited.

## Reporting a vulnerability

Please **do not** open a public GitHub issue for a security vulnerability.

Instead, use GitHub's private reporting:

1. Go to the [Security tab](https://github.com/meragix/authyra/security) of this repository.
2. Click **Report a vulnerability** under "Advisories".

This opens a private draft advisory visible only to the maintainers and you, so the issue isn't disclosed before a fix is available.

## What to expect

This is a young, actively developed open source project without a dedicated security team. Reports are triaged on a best-effort basis. You can expect an initial acknowledgment, and to be kept in the loop as a fix is developed. Coordinated disclosure once a patched version is published.

## Scope

In scope: authentication logic, session handling, token storage, and provider implementations in this repository (`packages/authyra`, `packages/authyra_flutter`, `packages/authyra_apple`).

Out of scope: vulnerabilities in third-party dependencies (`dio`, `flutter_secure_storage`, `sign_in_with_apple`, etc.), report those upstream to their respective maintainers. If a dependency's vulnerability affects Authyra directly (e.g., a vulnerable version range in a `pubspec.yaml` constraint), that's still worth reporting here.

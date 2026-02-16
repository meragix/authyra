---
title: FAQ
# description: Text, title, and styling in standard markdown.
---


## General

### What is Authyra?

Authyra is a pure authentication logic framework for Flutter and Dart. It handles authentication state, session management, and provider orchestration while remaining completely agnostic to your navigation and UI choices.

### Why not use Firebase Auth / Supabase Auth?

You can! Authyra can work alongside or integrate with these services. The difference is:

- **Firebase/Supabase**: Full backend service (auth + database + storage)
- **Authyra**: Just the auth logic layer (bring your own backend)

Use Authyra when:

- You have your own backend API
- You want full control over auth logic
- You need to support multiple auth providers
- You want navigation-agnostic auth

### Is Authyra production-ready?

v0.1.0 is an **MVP release**. It's functional but we recommend:

- ✅ Using it in side projects
- ✅ Testing thoroughly
- ⚠️ Waiting for v1.0.0 for mission-critical production apps

### Does Authyra work offline?

Yes! Session state is cached in memory and persisted to storage. Your app can:

- Check auth status offline
- Navigate based on cached auth state
- Queue auth actions (sign in/out) when offline (coming in v0.4.0)

## Technical

### Why two packages?

**authyra** (pure Dart):

- No Flutter dependency
- Works on backend, CLI, scripts
- Faster tests
- Smaller bundle size

**flutter_authyra** (Flutter widgets):

- UI components
- BuildContext extensions
- Flutter-specific integrations

This separation allows Authyra to work everywhere while keeping Flutter-specific code optional.

### Can I use Authyra without Flutter?

Yes! Use the `authyra` package:

```yaml
dependencies:
  authyra: ^0.1.0  # Pure Dart, no Flutter
```

Perfect for:

- Backend APIs (Shelf, Dart Frog)
- CLI tools
- Scripts
- Testing

### Does Authyra support multi-account?

Yes! v0.1.0 has basic multi-account support. Full implementation in v0.2.0.

```dart
// Switch between accounts
await Authyra.instance.switchAccount(account);

// Get all accounts
final accounts = Authyra.instance.allAccounts;
```

### Can I use my own state management?

Absolutely! Authyra is state management agnostic.

**With Riverpod**:

```dart
final authProvider = StreamProvider<AuthAccount?>((ref) {
  return Authyra.instance.onAccountChanged;
});
```

**With Bloc**:

```dart
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final StreamSubscription _subscription;
  
  AuthBloc() : super(AuthInitial()) {
    _subscription = Authyra.instance.onAccountChanged.listen((account) {
      add(AuthChanged(account));
    });
  }
}
```

### How do I test code that uses Authyra?

Use `AuthyraClient` directly in tests (no singleton):

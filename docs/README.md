# Authyra 🔐

**Pure authentication logic framework for Flutter and Dart.**

Authyra is a navigation-agnostic, framework-agnostic authentication solution that works seamlessly across Flutter apps, Dart backends, and CLI tools.

## ✨ Why Authyra?

- 🎯 **Navigation-agnostic** - Works with GoRouter, AutoRoute, Navigator, or any routing solution
- 🔄 **Multi-account support** - Switch between accounts seamlessly
- ⚡ **Reactive state** - Stream-based architecture that automatically updates your UI
- 🎨 **Flutter UI included** - Optional widgets for common auth patterns
- 🧪 **Pure Dart core** - Use on backend, CLI, or any Dart platform
- 🛡️ **Type-safe** - Full type safety with immutable state
- 📦 **Zero dependencies** - Core package has minimal dependencies

## 🚀 Quick Start

### For Flutter Apps

```yaml
dependencies:
  flutter_authyra: ^0.1.0
```

```dart
import 'package:flutter/material.dart';
import 'package:flutter_authyra/flutter_authyra.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Configure Authyra
  Authyra.instance.configure(
    AuthyraClient(
      providers: [
        EmailAuthProvider(
          validateCredentials: (email, password) async {
            // Your auth logic here
            return AuthAccount(
              id: 'user-123',
              email: email,
              displayName: 'John Doe',
            );
          },
        ),
      ],
      storage: SecureAuthStorage(),
    ),
  );
  
  // Initialize (restores session)
  await Authyra.instance.initialize();
  
  runApp(
    AuthyraScope(
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: AuthGuard(
        fallback: const LoginScreen(),
        child: const HomeScreen(),
      ),
    );
  }
}
```

### For Dart Backend

```yaml
dependencies:
  authyra: ^0.1.0
```

```dart
import 'package:authyra/authyra.dart';

void main() async {
  final authClient = AuthyraClient(
    providers: [EmailAuthProvider()],
    storage: InMemoryAuthStorage(),
  );
  
  final account = await authClient.signIn(
    provider: 'email',
    credentials: {
      'email': 'user@example.com',
      'password': 'secret123',
    },
  );
  
  print('Logged in: ${account.displayName}');
}
```

## 📚 Documentation

- [Getting Started](docs/getting-started/installation.md)
- [Core Concepts](docs/core-concepts/architecture.md)
- [API Reference](docs/api-reference/authyra-client.md)
- [Flutter Integration](docs/flutter/authyra-scope.md)
- [Examples](docs/examples/basic-app.md)

## 🎯 Philosophy

Authyra separates **authentication logic** from **navigation logic**.

```
┌─────────────────────────────────────────────────┐
│ Your App                                        │
│  ├─ Routing (GoRouter, AutoRoute, etc.)        │
│  └─ UI (Material, Cupertino, custom)           │
└─────────────────────────────────────────────────┘
                     ↓ reacts to
┌─────────────────────────────────────────────────┐
│ Authyra                                         │
│  ├─ Authentication state                        │
│  ├─ Session management                          │
│  └─ Provider orchestration                      │
└─────────────────────────────────────────────────┘
```

**Authyra tells you WHAT the auth state is.**  
**You decide WHERE to navigate.**

This keeps your routing flexible while having rock-solid auth logic.

## 🏗️ Architecture

```
┌──────────────────────────────────────────┐
│ AuthyraClient (Core Logic)              │
│  • Orchestrate providers + storage       │
│  • No global state                       │
│  • 100% testable                         │
└──────────────────────────────────────────┘
              ↓ used by
┌──────────────────────────────────────────┐
│ AuthyraInstance (Singleton)              │
│  • Global access via Authyra.instance    │
│  • Reactive streams                      │
│  • Memory cache                          │
└──────────────────────────────────────────┘
              ↓ consumed by
┌──────────────────────────────────────────┐
│ Flutter UI (Optional)                    │
│  • AuthyraScope (state propagation)      │
│  • AuthBuilder (reactive UI)             │
│  • AuthGuard (route protection)          │
└──────────────────────────────────────────┘
```

## 🔌 Providers

v0.1.0 includes:

- **EmailAuthProvider** - Email/password authentication

Coming soon:
- GoogleAuthProvider (v0.2.0)
- GitHubAuthProvider (v0.2.0)
- AppleAuthProvider (v0.2.0)

[Learn how to create custom providers →](docs/guides/custom-provider.md)

## 💾 Storage

v0.1.0 includes:

- **InMemoryAuthStorage** - For testing and development
- **SecureAuthStorage** - Uses flutter_secure_storage (Flutter only)

[Learn how to create custom storage →](docs/guides/custom-storage.md)

## 🤝 Contributing

We welcome contributions! See [CONTRIBUTING.md](CONTRIBUTING.md)

## 📄 License

MIT License - see [LICENSE](LICENSE)

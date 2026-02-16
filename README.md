# Authyra

Pure authentication logic framework for Flutter and Dart.

## 📦 Packages

This monorepo contains:

### [`authyra`](packages/authyra)

[![pub package](https://img.shields.io/pub/v/authyra.svg)](https://pub.dev/packages/authyra)

Pure Dart authentication logic. Works on:

- Flutter (iOS, Android, Web, Desktop)
- Dart backend (Shelf, Dart Frog)
- Dart CLI
- Scripts

```yaml
dependencies:
  authyra: ^1.0.0
```

### [`flutter_authyra`](packages/flutter_authyra)

[![pub package](https://img.shields.io/pub/v/flutter_authyra.svg)](https://pub.dev/packages/flutter_authyra)

Flutter widgets and extensions for Authyra.

```yaml
dependencies:
  flutter_authyra: ^1.0.0
```

## 🚀 Quick Start

### For Flutter Apps

```dart
import 'package:flutter/material.dart';
import 'package:flutter_authyra/flutter_authyra.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  Authyra.instance.initialize(
    AuthyraClient(
      providers: [EmailAuthProvider()],
      storage: SecureAuthStorage(),
    ),
  );
  
  
  runApp(
    AuthyraScope(
      child: const MyApp(),
    ),
  );
}
```

### For Dart Backend

```dart
import 'package:authyra/authyra.dart';

void main() async {
  Authyra.instance.initialize(
    AuthyraClient(
      providers: [EmailAuthProvider()],
    ),
  );
  
  final account = await Authyra.instance.signIn(
    provider: 'email',
    credentials: {'email': 'user@app.com', 'password': '***'},
  );
}
```

## 🏗️ Development

This project uses [Melos](https://melos.invertase.dev/) for monorepo management.

```bash
# Install Melos
dart pub global activate melos

# Bootstrap packages
melos bootstrap

# Run all tests
melos run test

# Analyze all packages
melos run analyze

# Format code
melos run format
```

## 📚 Documentation

- [Getting Started](https://authyra.dev/docs/getting-started)
- [Route Protection](https://authyra.dev/docs/route-protection)
- [Multi-Account](https://authyra.dev/docs/multi-account)
- [Custom Providers](https://authyra.dev/docs/custom-providers)

## 🤝 Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md)

## 📄 License

MIT License - see [LICENSE](LICENSE)

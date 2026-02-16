
# authyra

Pure Dart authentication logic framework.

## Features

- 🔐 Session management
- 🔄 Multi-account support
- 🎯 Provider abstraction (Email, OAuth, etc.)
- 💾 Pluggable storage
- ⚡ Reactive streams
- 🧪 Fully tested
- 🌐 Platform agnostic (Flutter, backend, CLI)

## Installation

```yaml
dependencies:
  authyra: ^1.0.0
```

## Usage

```dart
import 'package:authyra/authyra.dart';

void main() async {
  // Configure
  Authyra.instance.configure(
    AuthyraClient(
      providers: [EmailAuthProvider()],
      storage: InMemoryAuthStorage(),
    ),
  );
  
  // Initialize
  await Authyra.instance.initialize();
  
  // Sign in
  final account = await Authyra.instance.signIn(
    provider: 'email',
    credentials: {
      'email': 'user@example.com',
      'password': 'secret123',
    },
  );
  
  print('Logged in: ${account?.displayName}');
}
```

## For Flutter Apps

Use `flutter_authyra` for widgets and BuildContext extensions:

```yaml
dependencies:
  flutter_authyra: ^1.0.0
```

[Documentation](https://authyra.dev/docs)

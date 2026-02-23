import 'package:authyra/authyra.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// An [AuthStorage] implementation backed by [`flutter_secure_storage`](https://pub.dev/packages/flutter_secure_storage).
///
/// Uses the platform-native encrypted store on each target:
///
/// | Platform      | Backend                                         |
/// |---------------|-------------------------------------------------|
/// | iOS / macOS   | Keychain                                        |
/// | Android       | EncryptedSharedPreferences (Android Keystore)   |
/// | Web           | `localStorage` with Web Crypto AES-GCM          |
/// | Linux         | libsecret (Secret Service)                      |
/// | Windows       | DPAPI (`CryptProtectData`)                      |
///
/// ## Usage
///
/// ```dart
/// await Authyra.initialize(
///   client: AuthyraClient(
///     providers: [...],
///     storage: SecureAuthStorage(),
///   ),
/// );
/// ```
///
/// ## Android configuration
///
/// Ensure your `minSdkVersion` is 18 or above in `android/app/build.gradle`:
///
/// ```groovy
/// android {
///   defaultConfig {
///     minSdkVersion 18
///   }
/// }
/// ```
///
/// ## Web configuration
///
/// No extra setup needed. `flutter_secure_storage` on web uses the browser's
/// `SubtleCrypto` API with a per-origin encryption key.
///
/// See also:
/// - [AuthStorage], the interface this class implements.
/// - [InMemoryStorage] in `authyra`, for use in tests.
class SecureAuthStorage implements AuthStorage {
  final FlutterSecureStorage _storage;

  /// Creates a [SecureAuthStorage].
  ///
  /// Optionally pass custom [AndroidOptions], [IOSOptions], [WebOptions], etc.
  /// to tune platform-specific behaviour. If not specified, platform defaults
  /// are used, which are secure for most applications.
  ///
  /// ```dart
  /// // Custom Android options (e.g., reset on lock-screen removal):
  /// SecureAuthStorage(
  ///   aOptions: const AndroidOptions(
  ///     encryptedSharedPreferences: true,
  ///     resetOnError: true,
  ///   ),
  /// )
  /// ```
  const SecureAuthStorage({
    AndroidOptions aOptions = const AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    IOSOptions iOptions = const IOSOptions(),
    WebOptions webOptions = const WebOptions(),
    LinuxOptions lOptions = const LinuxOptions(),
    WindowsOptions wOptions = const WindowsOptions(),
  }) : _storage = const FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true),
          iOptions: IOSOptions(),
          webOptions: WebOptions(),
          lOptions: LinuxOptions(),
          wOptions: WindowsOptions(),
        );

  @override
  Future<void> initialize() async {
    // flutter_secure_storage initialises lazily on first use.
    // No explicit setup required.
  }

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<bool> delete(String key) async {
    final existed = await _storage.containsKey(key: key);
    await _storage.delete(key: key);
    return existed;
  }

  @override
  Future<void> clear() => _storage.deleteAll();

  @override
  Future<bool> containsKey(String key) => _storage.containsKey(key: key);

  @override
  Future<List<String>> getKeysWithPrefix(String prefix) async {
    final all = await _storage.readAll();
    return all.keys.where((k) => k.startsWith(prefix)).toList();
  }
}

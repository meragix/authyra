import 'package:authyra/src/interfaces/auth_storage.dart';

/// An in-memory [AuthStorage] implementation for tests and server-side use.
///
/// All data is stored in a plain `Map<String, String>`. Nothing is persisted
/// to disk; the store is cleared when the object is garbage collected or when
/// [clear] is called explicitly.
///
/// ## Usage
///
/// ```dart
/// final client = AuthyraClient(
///   providers: [myProvider],
///   storage: InMemoryStorage(),
/// );
/// await client.initialize();
/// ```
///
/// Create a **new instance per test** to guarantee isolation between cases:
///
/// ```dart
/// setUp(() async {
///   client = AuthyraClient(
///     providers: [myProvider],
///     storage: InMemoryStorage(),
///   );
///   await client.initialize();
/// });
/// ```
///
/// ## Limitations
///
/// - **Not persistent**: sessions are lost on process restart or when the
///   instance is discarded. Use `SecureAuthStorage` (Flutter) or a custom
///   encrypted backend for production.
/// - **Not thread-safe**: avoid sharing a single instance across isolates.
///
/// See also:
/// - [AuthStorage], the interface this class implements.
/// - `SecureAuthStorage` in `authyra_flutter`, the production Flutter
///   implementation.
class InMemoryStorage implements AuthStorage {
  final Map<String, String> _store = {};

  /// Creates a new, empty [InMemoryStorage].
  InMemoryStorage();

  @override
  Future<void> initialize() async {
    // Nothing to initialise; the in-memory map is ready immediately.
  }

  @override
  Future<String?> read(String key) async => _store[key];

  @override
  Future<void> write(String key, String value) async {
    _store[key] = value;
  }

  @override
  Future<bool> delete(String key) async {
    final existed = _store.containsKey(key);
    _store.remove(key);
    return existed;
  }

  @override
  Future<void> clear() async => _store.clear();

  @override
  Future<bool> containsKey(String key) async => _store.containsKey(key);

  @override
  Future<List<String>> getKeysWithPrefix(String prefix) async =>
      _store.keys.where((k) => k.startsWith(prefix)).toList();

  /// The current number of entries in the store.
  ///
  /// Useful for assertions in tests:
  ///
  /// ```dart
  /// expect(storage.length, 1);
  /// ```
  int get length => _store.length;

  /// Whether the store contains no entries.
  bool get isEmpty => _store.isEmpty;

  /// Returns an unmodifiable view of all current entries.
  ///
  /// Useful for debugging test state:
  ///
  /// ```dart
  /// print(storage.entries);
  /// ```
  Map<String, String> get entries => Map.unmodifiable(_store);
}

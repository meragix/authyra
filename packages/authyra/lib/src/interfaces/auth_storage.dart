/// Pluggable storage interface for Authyra session persistence.
///
/// [AuthStorage] is the **single storage abstraction** used throughout Authyra.
/// The core package deliberately ships **no concrete implementation**; consumers
/// provide a backend suited to their runtime environment:
///
/// | Runtime       | Recommended backend                              |
/// |---------------|--------------------------------------------------|
/// | Flutter       | `flutter_secure_storage` (Keychain / Keystore)   |
/// | Dart CLI      | Encrypted file or OS keyring                     |
/// | Backend/Shelf | Redis, encrypted DB column, or secrets manager   |
///
/// ## Implementing a custom backend
///
/// ```dart
/// class SecureAuthStorage implements AuthStorage {
///   final _storage = const FlutterSecureStorage();
///
///   @override
///   Future<void> initialize() async {
///     // One-time setup: key derivation, schema migration, etc.
///   }
///
///   @override
///   Future<String?> read(String key) => _storage.read(key: key);
///
///   @override
///   Future<void> write(String key, String value) =>
///       _storage.write(key: key, value: value);
///
///   @override
///   Future<bool> delete(String key) async {
///     final exists = await _storage.containsKey(key: key);
///     await _storage.delete(key: key);
///     return exists;
///   }
///
///   @override
///   Future<void> clear() => _storage.deleteAll();
///
///   @override
///   Future<bool> containsKey(String key) =>
///       _storage.containsKey(key: key);
///
///   @override
///   Future<List<String>> getKeysWithPrefix(String prefix) async {
///     final all = await _storage.readAll();
///     return all.keys.where((k) => k.startsWith(prefix)).toList();
///   }
/// }
/// ```
///
/// ## Security guidance
///
/// Authyra serialises access tokens and refresh tokens into this storage.
/// **Never** use plaintext backends (`SharedPreferences`, browser
/// `localStorage`) for token data. Always use an encrypted store.
///
/// See also:
/// - [SessionManager], the primary consumer of this interface.
abstract class AuthStorage {
  /// Performs any one-time initialisation required by this storage backend.
  ///
  /// Must be called and awaited before any other method on this instance.
  /// Implementations should be **idempotent**; repeated calls must be safe
  /// and should not reinitialise state or corrupt existing data.
  ///
  /// Common tasks performed here:
  /// - Encryption key derivation or retrieval.
  /// - Database connection / schema migration.
  /// - Verification that the underlying store is accessible.
  ///
  /// Throws a [StorageNotInitializedException]-compatible error if the backend
  /// cannot be brought to a ready state.
  Future<void> initialize();

  /// Reads and returns the UTF-8 string value associated with [key].
  ///
  /// Returns `null` if [key] does not exist in the store. Never throws for a
  /// missing key; use [containsKey] first if presence matters.
  Future<String?> read(String key);

  /// Persists [value] under [key], overwriting any existing value.
  ///
  /// [value] is typically a JSON-encoded string produced by
  /// [SessionRegistry.toJson]. The implementation must guarantee
  /// **durability**; the write must survive process restarts and OS-level
  /// power events.
  Future<void> write(String key, String value);

  /// Removes the entry associated with [key].
  ///
  /// Returns `true` if [key] existed and was successfully removed, or `false`
  /// if [key] was not present. Never throws for a missing key.
  Future<bool> delete(String key);

  /// Removes **all** entries managed by this storage instance.
  ///
  /// This is a destructive, irreversible operation that permanently erases all
  /// authentication data; including tokens for every signed-in account. Call
  /// only during a full sign-out-all flow or a factory reset.
  Future<void> clear();

  /// Returns `true` if an entry for [key] is present in the store.
  Future<bool> containsKey(String key);

  /// Returns all keys whose names begin with [prefix].
  ///
  /// Useful for enumerating namespaced entries without knowing all keys
  /// upfront (e.g., listing all sessions for a specific provider or user).
  ///
  /// ```dart
  /// // Find all entries scoped to a specific user namespace
  /// final keys = await storage.getKeysWithPrefix('session:usr_01');
  /// ```
  Future<List<String>> getKeysWithPrefix(String prefix);
}

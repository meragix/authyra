/// Abstract storage interface for Authyra
///
/// Implement this interface to provide custom storage backends
/// (SharedPreferences, Hive, SQLite, File System, etc.)
abstract class AuthStorage {
  Future<void> initialize();

  /// Read a value from storage by key
  ///
  /// Returns null if the key doesn't exist
  Future<String?> read(String key);

  /// Write a value to storage
  ///
  /// [key] The storage key
  /// [value] The value to store (typically JSON string)
  Future<void> write(String key, String value);

  /// Delete a value from storage by key
  ///
  /// Returns true if the key existed and was deleted
  Future<bool> delete(String key);

  /// Clear all stored data
  ///
  /// Use with caution - this removes all authentication data
  Future<void> clear();

  /// Check if a key exists in storage
  Future<bool> containsKey(String key);

  /// Get all keys matching a prefix
  ///
  /// Useful for finding all accounts or sessions
  Future<List<String>> getKeysWithPrefix(String prefix);
}

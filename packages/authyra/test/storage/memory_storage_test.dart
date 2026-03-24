import 'package:test/test.dart';
import 'package:authyra/src/storage/memory_storage.dart';

void main() {
  group('InMemoryStorage', () {
    late InMemoryStorage storage;

    setUp(() async {
      storage = InMemoryStorage();
      await storage.initialize();
    });

    test('initialize is idempotent', () async {
      await storage.initialize();
      await storage.initialize();
      expect(storage.isEmpty, isTrue);
    });

    test('write and read a value', () async {
      await storage.write('key1', 'value1');
      expect(await storage.read('key1'), 'value1');
    });

    test('read returns null for missing key', () async {
      expect(await storage.read('missing'), isNull);
    });

    test('overwrite replaces existing value', () async {
      await storage.write('key', 'old');
      await storage.write('key', 'new');
      expect(await storage.read('key'), 'new');
    });

    test('delete removes a key', () async {
      await storage.write('key', 'value');
      await storage.delete('key');
      expect(await storage.read('key'), isNull);
    });

    test('delete on missing key is a no-op', () async {
      expect(() async => storage.delete('ghost'), returnsNormally);
    });

    test('containsKey returns true for existing key', () async {
      await storage.write('present', 'yes');
      expect(await storage.containsKey('present'), isTrue);
    });

    test('containsKey returns false for missing key', () async {
      expect(await storage.containsKey('absent'), isFalse);
    });

    test('clear removes all keys', () async {
      await storage.write('a', '1');
      await storage.write('b', '2');
      await storage.clear();
      expect(storage.isEmpty, isTrue);
      expect(await storage.read('a'), isNull);
    });

    test('getKeysWithPrefix returns matching keys', () async {
      await storage.write('user:1', 'alice');
      await storage.write('user:2', 'bob');
      await storage.write('session:1', 's1');

      final keys = await storage.getKeysWithPrefix('user:');
      expect(keys, containsAll(['user:1', 'user:2']));
      expect(keys, isNot(contains('session:1')));
    });

    test('getKeysWithPrefix returns empty when no match', () async {
      await storage.write('unrelated', 'value');
      final keys = await storage.getKeysWithPrefix('missing:');
      expect(keys, isEmpty);
    });

    test('length reflects number of stored entries', () async {
      expect(storage.length, 0);
      await storage.write('a', '1');
      await storage.write('b', '2');
      expect(storage.length, 2);
      await storage.delete('a');
      expect(storage.length, 1);
    });

    test('entries provides unmodifiable view', () async {
      await storage.write('x', '42');
      final entries = storage.entries;
      expect(entries['x'], '42');
    });
  });
}

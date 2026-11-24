import 'package:dtm_app/core/util/lru_cache.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LruCache', () {
    test('keeps entries under the ceiling', () {
      final cache = LruCache<int, String>(maxEntries: 2);
      cache[1] = 'a';
      cache[2] = 'b';
      expect(cache.length, 2);
      cache[3] = 'c';
      expect(cache.length, 2);
    });

    test('evicts the least recently used entry', () {
      final cache = LruCache<int, String>(maxEntries: 2);
      cache[1] = 'a';
      cache[2] = 'b';
      // Reading 1 makes 2 the least recently used.
      expect(cache[1], 'a');
      cache[3] = 'c';
      expect(cache.containsKey(1), isTrue);
      expect(cache.containsKey(2), isFalse);
      expect(cache.containsKey(3), isTrue);
    });

    test('writing an existing key refreshes its recency', () {
      final cache = LruCache<int, String>(maxEntries: 2);
      cache[1] = 'a';
      cache[2] = 'b';
      cache[1] = 'a2';
      cache[3] = 'c';
      expect(cache[1], 'a2');
      expect(cache.containsKey(2), isFalse);
    });

    test('a missing key reads as null and adds nothing', () {
      final cache = LruCache<int, String>(maxEntries: 2);
      expect(cache[7], isNull);
      expect(cache.length, 0);
    });
  });
}

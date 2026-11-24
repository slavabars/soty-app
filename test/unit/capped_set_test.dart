import 'package:dtm_app/core/util/capped_set.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CappedSet', () {
    test('add reports novelty and contains reflects membership', () {
      final set = CappedSet<String>(maxSize: 4);
      expect(set.add('a'), isTrue);
      expect(set.add('a'), isFalse);
      expect(set.contains('a'), isTrue);
      expect(set.length, 1);
    });

    test('evicts oldest entries once the cap is reached', () {
      final set = CappedSet<int>(maxSize: 3);
      set.add(1);
      set.add(2);
      set.add(3);
      set.add(4);
      expect(set.length, 3);
      expect(set.contains(1), isFalse);
      expect(set.contains(2), isTrue);
      expect(set.contains(4), isTrue);
    });

    test('a hostile flood never grows memory beyond the cap', () {
      final set = CappedSet<int>(maxSize: 128);
      for (var i = 0; i < 100000; i++) {
        set.add(i);
      }
      expect(set.length, 128);
      expect(set.contains(100000 - 1), isTrue);
    });

    test('remove and clear work', () {
      final set = CappedSet<String>(maxSize: 4);
      set.add('a');
      set.remove('a');
      expect(set.contains('a'), isFalse);
      set.add('b');
      set.clear();
      expect(set.length, 0);
    });

    test('defaults to the shared maxSeenIds bound', () {
      final set = CappedSet<int>();
      for (var i = 0; i < 5000; i++) {
        set.add(i);
      }
      expect(set.length, 4096);
    });
  });
}

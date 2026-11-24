import 'package:dtm_app/features/messenger/emoji_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every category carries a unique, non-empty emoji set', () {
    final seen = <String>{};
    for (final category in emojiCategories) {
      expect(category.id, isNotEmpty);
      expect(category.label, isNotEmpty);
      expect(category.emoji, isNotEmpty);
      for (final emoji in category.emoji) {
        expect(emoji, isNotEmpty);
        expect(seen.add(emoji), isTrue, reason: 'duplicate $emoji');
      }
    }
  });

  test('category ids are unique', () {
    final ids = emojiCategories.map((c) => c.id).toList();
    expect(ids.toSet(), hasLength(ids.length));
  });

  test('the picker offers a broad catalogue', () {
    final total = emojiCategories.fold<int>(
      0,
      (sum, c) => sum + c.emoji.length,
    );
    expect(total, greaterThanOrEqualTo(250));
  });
}

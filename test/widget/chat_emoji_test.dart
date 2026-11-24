import 'package:dtm_app/core/i18n/app_prefs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'chat_fixture.dart';

Future<void> openPicker(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.emoji_emotions_outlined));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the emoji button opens the picker', (tester) async {
    final f = await makeFixture();
    await tester.pumpWidget(wrap(chat(f)));
    await tester.pumpAndSettle();

    expect(find.text('😀'), findsNothing);
    await openPicker(tester);
    expect(find.text('😀'), findsOneWidget);
  });

  testWidgets('the picker is empty of grids until opened again',
      (tester) async {
    final f = await makeFixture();
    await tester.pumpWidget(wrap(chat(f)));
    await tester.pumpAndSettle();

    await openPicker(tester);
    await openPicker(tester);
    expect(find.text('😀'), findsNothing);
  });

  testWidgets('tapping an emoji inserts it and records it as recent',
      (tester) async {
    final f = await makeFixture();
    final prefs = AppPrefs();
    await tester.pumpWidget(wrap(chat(f, prefs: prefs)));
    await tester.pumpAndSettle();

    await openPicker(tester);
    await tester.tap(find.text('😀'));
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, '😀');
    expect(prefs.emojiRecents, ['😀']);
  });

  testWidgets('an emoji lands at the caret, not at the end', (tester) async {
    final f = await makeFixture();
    await tester.pumpWidget(wrap(chat(f)));
    await tester.pumpAndSettle();

    final controller = tester
        .widget<TextField>(find.byType(TextField))
        .controller!;
    controller.value = const TextEditingValue(
      text: 'ab',
      selection: TextSelection.collapsed(offset: 1),
    );
    await tester.pump();

    await openPicker(tester);
    await tester.tap(find.text('😀'));
    await tester.pumpAndSettle();

    expect(controller.text, 'a😀b');
  });

  testWidgets('a used emoji leads the recents tab', (tester) async {
    final f = await makeFixture();
    final prefs = AppPrefs();
    await tester.pumpWidget(wrap(chat(f, prefs: prefs)));
    await tester.pumpAndSettle();

    await openPicker(tester);
    await tester.tap(find.text('😀'));
    await tester.pumpAndSettle();
    // Dismiss the picker, then reopen: it should land on recents.
    await openPicker(tester);
    await openPicker(tester);

    expect(
      find.descendant(of: find.byType(GridView), matching: find.text('😀')),
      findsOneWidget,
    );
  });

  testWidgets('recents tab shows a hint when nothing was used yet',
      (tester) async {
    final f = await makeFixture();
    await tester.pumpWidget(wrap(chat(f)));
    await tester.pumpAndSettle();

    await openPicker(tester);
    await tester.tap(find.byTooltip('Recent'));
    await tester.pumpAndSettle();

    expect(find.text('No recent emoji'), findsOneWidget);
  });

  testWidgets('category tabs swap the grid', (tester) async {
    final f = await makeFixture();
    await tester.pumpWidget(wrap(chat(f)));
    await tester.pumpAndSettle();

    await openPicker(tester);
    expect(find.text('😀'), findsOneWidget);

    await tester.tap(find.byTooltip('Animals & nature'));
    await tester.pumpAndSettle();
    expect(find.text('🐶'), findsOneWidget);
    expect(find.text('😀'), findsNothing);
  });
}

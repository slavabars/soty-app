import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'chat_fixture.dart';

void main() {
  testWidgets('an inbound group bubble names its author', (tester) async {
    final f = await makeFixture();
    final group = await makeGroup(f);
    await sendGroupMemberMessage(f, group, 'в группу');
    await tester.pumpWidget(wrap(chat(f, conversationId: group.groupId)));
    await tester.pumpAndSettle();

    expect(find.text('в группу'), findsOneWidget);
    expect(find.text('Member'), findsOneWidget);
  });

  testWidgets('a 1:1 bubble carries no author name', (tester) async {
    final f = await makeFixture();
    await sendInbound(f, 'привет');
    await tester.pumpWidget(wrap(chat(f)));
    await tester.pumpAndSettle();

    expect(find.text('привет'), findsOneWidget);
    // The peer name is the app-bar title, never repeated above the bubble.
    expect(
      find.descendant(
        of: find.byType(ListView),
        matching: find.text('Zora'),
      ),
      findsNothing,
    );
  });

  testWidgets('our own group bubble carries no author name', (tester) async {
    final f = await makeFixture();
    final group = await makeGroup(f);
    await sendGroupMemberMessage(f, group, 'чужое');
    await tester.pumpWidget(wrap(chat(f, conversationId: group.groupId)));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'моё');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();

    expect(find.text('моё'), findsOneWidget);
    // The only name on screen is the inbound member's, never our own.
    expect(find.text('Member'), findsOneWidget);
  });
}

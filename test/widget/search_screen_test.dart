import 'package:dtm_app/core/i18n/app_prefs.dart';
import 'package:dtm_app/features/messenger/search_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'chat_fixture.dart';

Widget search(Fixture f, {String? conversationId}) => SearchScreen(
      messenger: f.controller,
      prefs: AppPrefs(),
      conversationId: conversationId,
    );

void main() {
  testWidgets('typing finds decrypted history and shows the chat title',
      (tester) async {
    final f = await makeFixture();
    await sendInbound(f, 'hello from the archive');

    await tester.pumpWidget(wrap(search(f)));
    await tester.pumpAndSettle();
    expect(find.text('Type to search your messages.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'archive');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.text('Zora'), findsOneWidget);
    expect(find.text('hello from the archive'), findsOneWidget);
  });

  testWidgets('a missing phrase reports no results', (tester) async {
    final f = await makeFixture();
    await sendInbound(f, 'hello');

    await tester.pumpWidget(wrap(search(f)));
    await tester.enterText(find.byType(TextField), 'nothing like this');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.text('No messages found'), findsOneWidget);
  });

  testWidgets('the unread filter follows the read cursor', (tester) async {
    final f = await makeFixture();
    await sendInbound(f, 'fresh message');

    await tester.pumpWidget(wrap(search(f)));
    await tester.tap(find.text('Unread'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.text('fresh message'), findsOneWidget);

    await f.controller.markConversationRead(f.peerX);
    await tester.tap(find.text('All'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unread'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.text('fresh message'), findsNothing);
  });

  testWidgets('a scoped search keeps the hint scoped', (tester) async {
    final f = await makeFixture();
    await tester.pumpWidget(wrap(search(f, conversationId: f.peerX)));
    await tester.pumpAndSettle();
    expect(find.text('Search in this chat'), findsOneWidget);
  });
}

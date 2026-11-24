import 'package:drift/drift.dart' show Value;
import 'package:dtm_app/core/storage/database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'chat_fixture.dart';

String composerText(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField)).controller!.text;

void main() {
  testWidgets('an over-byte message is not sent and keeps its text',
      (tester) async {
    final f = await makeFixture();
    await tester.pumpWidget(wrap(chat(f)));
    await tester.pumpAndSettle();

    // 3000 Cyrillic characters: under the 4096-character counter, but 6000
    // UTF-8 bytes, past the 4 KB wire limit.
    final heavy = 'ё' * 3000;
    await tester.enterText(find.byType(TextField), heavy);
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();

    expect(find.text('Message exceeds the 4 KB limit'), findsOneWidget);
    expect(composerText(tester), heavy);
    expect(await f.controller.messagesFor(f.peerX), isEmpty);

    // The chat recovers: a message inside the limit still goes out.
    // Let the banner fade first so it does not intercept the next tap.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'short');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();
    expect(
      (await f.controller.messagesFor(f.peerX)).map((m) => m.body),
      contains('short'),
    );
  });

  testWidgets('a send that throws keeps the typed text', (tester) async {
    final f = await makeFixture();
    // A roster written by an older build, before rosters were validated as
    // 32-byte hex. Creating such a group is refused now, but the row is still
    // on disk, so the fan-out throws when it composes that member's copy.
    final groupId = 'g' * 64;
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await f.db.into(f.db.conversations).insert(
          ConversationsCompanion.insert(
            id: groupId,
            kind: const Value('group'),
            title: const Value('Broken'),
            createdTs: Value(now),
            lastTs: Value(now),
          ),
        );
    await f.db.into(f.db.conversationMembers).insert(
          ConversationMembersCompanion.insert(
            conversationId: groupId,
            peerXKey: f.controller.myXPubKey,
            role: const Value('admin'),
          ),
        );
    await f.db.into(f.db.conversationMembers).insert(
          ConversationMembersCompanion.insert(
            conversationId: groupId,
            peerXKey: 'zz',
          ),
        );
    await f.controller.renameConversation(groupId, 'Broken');
    await tester.pumpWidget(wrap(chat(f, conversationId: groupId)));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'hi group');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();

    expect(find.text('Message could not be sent'), findsOneWidget);
    expect(composerText(tester), 'hi group');
    expect(tester.takeException(), isNull);
  });

  testWidgets('typing hides the attach and voice buttons and widens the field',
      (tester) async {
    final f = await makeFixture();
    await tester.pumpWidget(wrap(chat(f)));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.attach_file), findsOneWidget);
    expect(find.byIcon(Icons.mic), findsOneWidget);
    final before = tester.getSize(find.byType(TextField)).width;

    await tester.enterText(find.byType(TextField), 'hello');
    await tester.pump();

    expect(find.byIcon(Icons.attach_file), findsNothing);
    expect(find.byIcon(Icons.mic), findsNothing);
    final after = tester.getSize(find.byType(TextField)).width;
    expect(after, greaterThan(before));

    await tester.enterText(find.byType(TextField), '');
    await tester.pump();
    expect(find.byIcon(Icons.attach_file), findsOneWidget);
    expect(find.byIcon(Icons.mic), findsOneWidget);
  });

  testWidgets('the quote header counts against the byte limit',
      (tester) async {
    final f = await makeFixture();
    await sendInbound(f, 'original');
    await tester.pumpWidget(wrap(chat(f)));
    await tester.pumpAndSettle();

    // 3900 bytes fit inside an `x1` container (68 bytes of header), so the
    // same text would go out plain — but not once the `x2` reply header and
    // the preview are added, so it is refused rather than silently dropped.
    final heavy = '𐍈' * 975;
    await tester.longPress(find.text('original'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reply'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), heavy);
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();

    expect(find.text('Message exceeds the 4 KB limit'), findsOneWidget);
    expect(composerText(tester), heavy);
    expect(
      (await f.controller.messagesFor(f.peerX)).where((m) => m.outgoing),
      isEmpty,
    );
  });

  testWidgets('the same text goes out plain, with no quote header',
      (tester) async {
    final f = await makeFixture();
    await tester.pumpWidget(wrap(chat(f)));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '𐍈' * 975);
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();

    expect(
      (await f.controller.messagesFor(f.peerX)).where((m) => m.outgoing),
      hasLength(1),
    );
  });

  testWidgets('a forward too large to carry its author is refused',
      (tester) async {
    final f = await makeFixture();
    final otherX = await makeSecondConversation(f);
    // A bare 4096-byte plaintext, the most a legacy or hostile sender can
    // deliver: it fits inbound, but the `↪ author\n` prefix pushes the
    // forward past the limit.
    final huge = '𐍈' * 1024;
    await sendInboundRaw(f, huge);
    await tester.pumpWidget(wrap(chat(f)));
    await tester.pumpAndSettle();

    final bubble = find.text(huge);
    await tester.longPress(bubble, warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Forward'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Second'));
    await tester.pumpAndSettle();

    expect(find.text('Message exceeds the 4 KB limit'), findsOneWidget);
    expect(
      (await f.controller.messagesFor(otherX)).where((m) => m.outgoing),
      isEmpty,
    );
  });
}

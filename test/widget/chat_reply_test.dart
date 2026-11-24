import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'chat_fixture.dart';

Future<void> longPressBubble(WidgetTester tester, Finder bubble) async {
  await tester.longPress(bubble);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('long press offers reply, forward, copy and share',
      (tester) async {
    final f = await makeFixture();
    await sendInbound(f, 'original');
    await tester.pumpWidget(wrap(chat(f)));
    await tester.pumpAndSettle();

    await longPressBubble(tester, find.text('original'));

    expect(find.text('Reply'), findsOneWidget);
    expect(find.text('Forward'), findsOneWidget);
    expect(find.text('Copy'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
  });

  testWidgets('replying to a message quotes it on send', (tester) async {
    final f = await makeFixture();
    await sendInbound(f, 'original text');
    await tester.pumpWidget(wrap(chat(f)));
    await tester.pumpAndSettle();

    await longPressBubble(tester, find.text('original text'));
    await tester.tap(find.text('Reply'));
    await tester.pumpAndSettle();

    expect(find.text('Reply'), findsWidgets);

    await tester.enterText(find.byType(TextField), 'the answer');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();

    final messages = await f.controller.messagesFor(f.peerX);
    final outgoing = messages.singleWhere((m) => m.outgoing);
    expect(outgoing.body, 'the answer');
    expect(outgoing.quote, isNotNull);
    expect(outgoing.quote!.preview, 'original text');
    expect(outgoing.quote!.authorX, f.peerX);

    // The quote plaque renders on the reply bubble.
    expect(find.text('the answer'), findsOneWidget);
    expect(find.text('original text'), findsWidgets);
  });

  testWidgets('a reply carries the inbound author key', (tester) async {
    final f = await makeFixture();
    await sendInbound(f, 'first');
    await tester.pumpWidget(wrap(chat(f)));
    await tester.pumpAndSettle();

    await longPressBubble(tester, find.text('first'));
    await tester.tap(find.text('Reply'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'second');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();

    final outgoing = (await f.controller.messagesFor(f.peerX))
        .singleWhere((m) => m.outgoing);
    expect(outgoing.quote!.authorX, f.peerX);
  });

  testWidgets('dismissing the reply banner keeps the draft', (tester) async {
    final f = await makeFixture();
    await sendInbound(f, 'quoted');
    await tester.pumpWidget(wrap(chat(f)));
    await tester.pumpAndSettle();

    await longPressBubble(tester, find.text('quoted'));
    await tester.tap(find.text('Reply'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'half a thought');
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    final messages = await f.controller.messagesFor(f.peerX);
    expect(messages.where((m) => m.outgoing), isEmpty);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'half a thought',
    );
  });

  testWidgets('a quoted inbound renders the preview plaque', (tester) async {
    final f = await makeFixture();
    await sendInbound(f, 'the original line');
    await tester.pumpWidget(wrap(chat(f)));
    await tester.pumpAndSettle();

    await longPressBubble(tester, find.text('the original line'));
    await tester.tap(find.text('Reply'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'answer');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();

    final replies = find.text('answer');
    expect(replies, findsOneWidget);
    final quoteTexts = find.text('the original line');
    expect(quoteTexts, findsNWidgets(2));
  });

  testWidgets('forwarding a message lands in the picked chat', (tester) async {
    final f = await makeFixture();
    final otherX = await makeSecondConversation(f);
    await sendInbound(f, 'please forward this');
    await tester.pumpWidget(wrap(chat(f)));
    await tester.pumpAndSettle();

    await longPressBubble(tester, find.text('please forward this'));
    await tester.tap(find.text('Forward'));
    await tester.pumpAndSettle();

    expect(find.text('Forward to'), findsOneWidget);
    await tester.tap(find.text('Second'));
    await tester.pumpAndSettle();

    final forwarded = (await f.controller.messagesFor(otherX))
        .where((m) => m.outgoing)
        .toList();
    expect(forwarded, hasLength(1));
    expect(forwarded.single.body, contains('please forward this'));
    // A forward is plain text: no quote, so no key leaks to the recipient.
    expect(forwarded.single.quote, isNull);
  });

  testWidgets('an undecryptable bubble offers no reply', (tester) async {
    final f = await makeFixture();
    await sendInbound(f, '🔒 Encrypted');
    await tester.pumpWidget(wrap(chat(f)));
    await tester.pumpAndSettle();

    await longPressBubble(tester, find.text('🔒 Encrypted'));

    expect(find.text('Reply'), findsNothing);
    expect(find.text('Forward'), findsOneWidget);
    expect(find.text('Copy'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
  });

  testWidgets('a legacy group message offers no reply', (tester) async {
    final f = await makeFixture();
    final group = await makeGroup(f);
    await sendLegacyGroupInbound(
      f,
      group.groupId,
      'legacy group line',
      member: group.member,
    );
    await tester.pumpWidget(wrap(chat(f, conversationId: group.groupId)));
    await tester.pumpAndSettle();

    await longPressBubble(tester, find.text('legacy group line'));

    expect(find.text('Reply'), findsNothing);
    expect(find.text('Forward'), findsOneWidget);
  });

  testWidgets('a group message from a member can be replied to',
      (tester) async {
    final f = await makeFixture();
    final group = await makeGroup(f);
    await sendGroupMemberMessage(f, group, 'current group');
    await tester.pumpWidget(wrap(chat(f, conversationId: group.groupId)));
    await tester.pumpAndSettle();

    await longPressBubble(tester, find.text('current group'));
    expect(find.text('Reply'), findsOneWidget);

    await tester.tap(find.text('Reply'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'group answer');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();

    final outgoing = (await f.controller.messagesFor(group.groupId))
        .singleWhere((m) => m.outgoing);
    expect(outgoing.quote?.authorX, group.memberX);
    expect(outgoing.quote?.preview, 'current group');
  });

  testWidgets('choosing reply keeps the draft the user was typing',
      (tester) async {
    final f = await makeFixture();
    await sendInbound(f, 'quoted');
    await tester.pumpWidget(wrap(chat(f)));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'half a thought');
    await longPressBubble(tester, find.text('quoted'));
    await tester.tap(find.text('Reply'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'half a thought',
    );
  });

  testWidgets('forwarding with nowhere to go says so', (tester) async {
    final f = await makeFixture();
    await sendInbound(f, 'lonely');
    await tester.pumpWidget(wrap(chat(f)));
    await tester.pumpAndSettle();

    await longPressBubble(tester, find.text('lonely'));
    await tester.tap(find.text('Forward'));
    await tester.pumpAndSettle();

    expect(find.text('Forward to'), findsNothing);
    expect(find.text('No conversations yet.'), findsOneWidget);
  });

  testWidgets('sharing falls back to the clipboard off Android',
      (tester) async {
    final f = await makeFixture();
    await sendInbound(f, 'share me');
    // Force the non-Android path: the widget test host reports android, where
    // the share channel would wait for an engine reply that never comes.
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });
    final clips = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        final args = call.arguments as Map<Object?, Object?>;
        clips.add(args['text']! as String);
      }
      return null;
    });

    await tester.pumpWidget(wrap(chat(f)));
    await tester.pumpAndSettle();
    await longPressBubble(tester, find.text('share me'));
    await tester.tap(find.text('Share'));
    await tester.pumpAndSettle();
    debugDefaultTargetPlatformOverride = null;

    expect(find.text('Copied'), findsOneWidget);
    expect(clips, ['share me']);
  });

  testWidgets('a forward too big for a group is refused, not thrown',
      (tester) async {
    final f = await makeFixture();
    final group = await makeGroup(f);
    // 3900 bytes fit an `x1` inbound container (68 bytes of header), and even
    // fit a forwarded `x1`, but not the longer `g2` group header.
    final heavy = '𐍈' * 975;
    await sendInbound(f, heavy);
    await tester.pumpWidget(wrap(chat(f)));
    await tester.pumpAndSettle();

    await longPressBubble(tester, find.text(heavy));
    await tester.tap(find.text('Forward'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Team'));
    await tester.pumpAndSettle();

    expect(find.text('Message exceeds the 4 KB limit'), findsOneWidget);
    expect(
      (await f.controller.messagesFor(group.groupId))
          .where((m) => m.outgoing),
      isEmpty,
    );
  });
}

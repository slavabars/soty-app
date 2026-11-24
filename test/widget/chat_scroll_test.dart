import 'package:dtm_app/core/i18n/app_prefs.dart';
import 'package:dtm_app/models/message_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'chat_fixture.dart';

/// How many inbound messages it takes to overflow the 800x600 test viewport.
/// The bubbles are one line each, so 40 is comfortably past the fold.
const int _filler = 40;

/// Unread messages piled up while the chat was closed. More than fit on the
/// 800x600 test viewport, so the first unread one can sit at the top.
const int _backlog = 25;

/// Pixels from the bottom the viewport may sit at and still count as the
/// tail (mirrors the chat screen's own follow threshold).
const double _tailSlack = 48;


void main() {
  testWidgets('messages render newest at the bottom', (tester) async {
    final f = await makeFixture();
    await sendInbound(f, 'first');
    await sendInbound(f, 'second');

    await tester.pumpWidget(wrap(chat(f)));
    await tester.pumpAndSettle();

    final bubbles = tester.widgetList<Text>(find.byType(Text));
    final bodies = bubbles.map((w) => w.data).whereType<String>().toList();
    expect(bodies.indexOf('second'), lessThan(bodies.indexOf('first')));
  });

  testWidgets('a read chat opens at the newest message', (tester) async {
    final f = await makeFixture();
    for (var i = 0; i < _filler; i++) {
      await sendInbound(f, 'msg $i');
    }
    // Everything is read, so the tail is where the reader left off.
    await f.controller.markConversationRead(f.peerX);

    await tester.pumpWidget(wrap(chat(f)));
    await tester.pumpAndSettle();

    expect(maxOffset(tester), greaterThan(0));
    expect(offset(tester), lessThanOrEqualTo(_tailSlack));
    expect(find.text('msg ${_filler - 1}'), findsOneWidget);
  });

  testWidgets('a read chat never opens on the beginning of the conversation', (
    tester,
  ) async {
    final f = await makeFixture();
    for (var i = 0; i < _filler; i++) {
      await sendInbound(f, 'msg $i');
    }
    await f.controller.markConversationRead(f.peerX);

    await tester.pumpWidget(wrap(chat(f)));
    var frames = 0;
    while (!tester.any(find.byType(ListView))) {
      await tester.pump();
      expect(++frames, lessThan(50)); // the list must appear, not hang
    }

    // The very first frame the list lays out is already the tail: the newest
    // message is built and the oldest was never on screen.
    expect(find.text('msg ${_filler - 1}'), findsOneWidget);
    expect(find.text('msg 0'), findsNothing);
    expect(offset(tester), lessThanOrEqualTo(_tailSlack));

    await tester.pumpAndSettle();
    expect(find.text('msg 0'), findsNothing);
    expect(offset(tester), lessThanOrEqualTo(_tailSlack));
  });

  testWidgets('an inbound message at the tail is followed', (tester) async {
    final f = await makeFixture();
    for (var i = 0; i < _filler; i++) {
      await sendInbound(f, 'msg $i');
    }
    await f.controller.markConversationRead(f.peerX);
    await tester.pumpWidget(wrap(chat(f)));
    await tester.pumpAndSettle();

    await sendInbound(f, 'fresh one');
    await tester.pumpAndSettle();

    expect(offset(tester), lessThanOrEqualTo(_tailSlack));
    expect(find.text('fresh one'), findsOneWidget);
  });

  testWidgets('sending follows to the newest message', (tester) async {
    final f = await makeFixture();
    for (var i = 0; i < _filler; i++) {
      await sendInbound(f, 'msg $i');
    }
    await f.controller.markConversationRead(f.peerX);
    await tester.pumpWidget(wrap(chat(f)));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'from me');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();

    expect(offset(tester), lessThanOrEqualTo(_tailSlack));
    expect(find.text('from me'), findsOneWidget);
  });

  testWidgets('the composer auto-capitalizes sentences', (tester) async {
    final f = await makeFixture();
    await tester.pumpWidget(wrap(chat(f)));
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.textCapitalization, TextCapitalization.sentences);
  });

  testWidgets('enter sends while send-on-enter is on', (tester) async {
    final f = await makeFixture();
    await tester.pumpWidget(wrap(chat(f)));
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.textInputAction, TextInputAction.send);

    await tester.enterText(find.byType(TextField), 'sent by enter');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();

    expect(find.text('sent by enter'), findsOneWidget);
    expect(
      (await f.controller.messagesFor(f.peerX)).map((m) => m.body),
      contains('sent by enter'),
    );
  });

  testWidgets('hardware enter sends while send-on-enter is on',
      (tester) async {
    final f = await makeFixture();
    await tester.pumpWidget(wrap(chat(f)));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'hardware enter');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(
      (await f.controller.messagesFor(f.peerX)).map((m) => m.body),
      contains('hardware enter'),
    );
  });

  testWidgets('shift+enter keeps a new line instead of sending',
      (tester) async {
    final f = await makeFixture();
    await tester.pumpWidget(wrap(chat(f)));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'first line');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle();

    expect(
      (await f.controller.messagesFor(f.peerX)).map((m) => m.body),
      isNot(contains('first line')),
    );
  });

  testWidgets('enter inserts a new line when send-on-enter is off',
      (tester) async {
    final f = await makeFixture();
    final prefs = AppPrefs();
    await prefs.setSendOnEnter(false);
    await tester.pumpWidget(wrap(chat(f, prefs: prefs)));
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.textInputAction, TextInputAction.newline);

    await tester.enterText(find.byType(TextField), 'not sent');
    await tester.testTextInput.receiveAction(TextInputAction.newline);
    await tester.pumpAndSettle();

    expect(
      (await f.controller.messagesFor(f.peerX)).map((m) => m.body),
      isNot(contains('not sent')),
    );
  });

  testWidgets('an inbound message does not move a reader back in history',
      (tester) async {
    final f = await makeFixture();
    for (var i = 0; i < _filler; i++) {
      await sendInbound(f, 'msg $i');
    }
    await f.controller.markConversationRead(f.peerX);
    await tester.pumpWidget(wrap(chat(f)));
    await tester.pumpAndSettle();

    // Scroll back into the backlog the way a person reading would. History sits
    // above the latest message, so the finger moves down (a downward drag).
    await tester.drag(find.byType(ListView), const Offset(0, 900));
    await tester.pumpAndSettle();
    final parked = offset(tester);
    expect(parked, greaterThan(_tailSlack));
    expect(parked, lessThan(maxOffset(tester) - 100));

    await sendInbound(f, 'arrives while reading');
    await tester.pumpAndSettle();

    expect(offset(tester), moreOrLessEquals(parked, epsilon: 1));
  });

  testWidgets('an unread backlog opens at the first unread message', (
    tester,
  ) async {
    final f = await makeFixture();
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    for (var i = 0; i < _filler; i++) {
      await sendInbound(f, 'old $i', timestamp: now - 100000 - i);
    }
    await f.controller.markConversationRead(f.peerX);
    // The chat is closed again, otherwise the controller keeps counting it as
    // on screen and marks the new arrivals read before the screen opens.
    f.controller.clearVisibleConversation(f.peerX);
    // A backlog far larger than the viewport, stamped well past the read
    // cursor. Explicit future stamps keep it deterministic: creating the older
    // messages costs real wall clock time, so a stamp just above the captured
    // `now` could still land behind the cursor.
    for (var i = 0; i < _backlog; i++) {
      await sendInbound(f, 'unread $i', timestamp: now + 60000 + i);
    }
    // The unread count is refreshed off the controller change stream, so let a
    // frame land before reading the cached conversation view.
    await tester.pump();
    expect(f.controller.conversationView(f.peerX)?.unreadCount, _backlog);

    await tester.pumpWidget(wrap(chat(f)));
    await tester.pumpAndSettle();

    // Reading picks up where it stopped: the first unread message is on screen
    // and the backlog is not scrolled past to the newest one.
    expect(find.text('unread 0'), findsOneWidget);
    expect(offset(tester), greaterThan(_tailSlack));
    expect(offset(tester), lessThan(maxOffset(tester) - 100));
    expect(find.text('unread ${_backlog - 1}'), findsNothing);
  });

  testWidgets(
      'an unread chat reveals anchored and never shows the conversation start',
      (tester) async {
    final f = await makeFixture();
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    for (var i = 0; i < _filler; i++) {
      await sendInbound(f, 'old $i', timestamp: now - 100000 - i);
    }
    await f.controller.markConversationRead(f.peerX);
    f.controller.clearVisibleConversation(f.peerX);
    for (var i = 0; i < _backlog; i++) {
      await sendInbound(f, 'unread $i', timestamp: now + 60000 + i);
    }
    await tester.pump();
    expect(f.controller.conversationView(f.peerX)?.unreadCount, _backlog);

    await tester.pumpWidget(wrap(chat(f)));
    var frames = 0;
    while (!tester.any(find.byType(ListView))) {
      await tester.pump();
      expect(++frames, lessThan(50)); // the list must appear, not hang
    }

    // The backlog hunt hides under the overlay: no content frame is shown
    // until the anchor row has been located.
    expect(find.byKey(const ValueKey('anchorOverlay')), findsOneWidget);
    while (tester.any(find.byKey(const ValueKey('anchorOverlay')))) {
      expect(++frames, lessThan(200));
      await tester.pump();
    }
    await tester.pumpAndSettle();

    // The first visible frame rests exactly on the first unread message, at
    // the top of the viewport; history and the newest tail never show.
    expect(find.text('old 0'), findsNothing);
    expect(find.text('unread 0'), findsOneWidget);
    expect(find.text('unread ${_backlog - 1}'), findsNothing);
    expect(offset(tester), greaterThan(_tailSlack));
    expect(offset(tester), lessThan(maxOffset(tester) - 100));
    final listTop = tester.getTopLeft(find.byType(ListView)).dy;
    final unreadTop = tester.getTopLeft(find.text('unread 0')).dy;
    expect(unreadTop - listTop, greaterThan(0));
    expect(unreadTop - listTop, lessThan(60));
  });

  testWidgets('a backlog that fits on screen still shows the newest message', (
    tester,
  ) async {
    final f = await makeFixture();
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    for (var i = 0; i < _filler; i++) {
      await sendInbound(f, 'old $i', timestamp: now - 100000 - i);
    }
    await f.controller.markConversationRead(f.peerX);
    f.controller.clearVisibleConversation(f.peerX);
    for (var i = 0; i < 2; i++) {
      await sendInbound(f, 'unread $i', timestamp: now + 60000 + i);
    }
    await tester.pump();
    expect(f.controller.conversationView(f.peerX)?.unreadCount, 2);

    await tester.pumpWidget(wrap(chat(f)));
    await tester.pumpAndSettle();

    // Two unread messages cannot be forced off the viewport, so the list rests
    // at the tail with all of them visible.
    expect(offset(tester), lessThanOrEqualTo(_tailSlack));
    expect(find.text('unread 0'), findsOneWidget);
    expect(find.text('unread 1'), findsOneWidget);
  });

  testWidgets('sending while the unread backlog is being anchored follows',
      (tester) async {
    final f = await makeFixture();
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    for (var i = 0; i < _filler; i++) {
      await sendInbound(f, 'old $i', timestamp: now - 100000 - i);
    }
    await f.controller.markConversationRead(f.peerX);
    f.controller.clearVisibleConversation(f.peerX);
    for (var i = 0; i < _backlog; i++) {
      await sendInbound(f, 'unread $i', timestamp: now + 60000 + i);
    }
    await tester.pump();
    expect(f.controller.conversationView(f.peerX)?.unreadCount, _backlog);

    // The first frame builds the list and the anchor seek starts on it; the
    // seek needs a further frame per attempt, so the send below lands while
    // the viewport is still parked on the first unread message.
    await tester.pumpWidget(wrap(chat(f)));
    await tester.pump();
    expect(offset(tester), lessThan(maxOffset(tester) - 100));

    await tester.enterText(find.byType(TextField), 'typed mid seek');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();

    // The send is recorded and the follow lands on the newest message. The
    // unread backlog here is stamped 60 s in the future (the deterministic
    // fixture trick), so it outranks the freshly sent message.
    final stored = await f.controller.messagesFor(f.peerX);
    expect(stored.map((m) => m.body), contains('typed mid seek'));
    expect(offset(tester), lessThanOrEqualTo(_tailSlack));
    expect(find.text('unread ${_backlog - 1}'), findsOneWidget);
  });

  testWidgets('leaving the chat cancels the change subscription', (
    tester,
  ) async {
    final f = await makeFixture();
    await sendInbound(f, 'hello');
    await tester.pumpWidget(wrap(chat(f)));
    await tester.pumpAndSettle();

    await tester.pumpWidget(wrap(const Scaffold(body: SizedBox())));
    await tester.pumpAndSettle();

    // A tick after the screen is gone must not call setState on it.
    await sendInbound(f, 'after the screen closed');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('an outgoing bubble carries a wait mark with no transport', (
    tester,
  ) async {
    final f = await makeFixture();
    await f.controller.sendText(recipientPubKey: f.peerX, plaintext: 'hi');

    await tester.pumpWidget(wrap(chat(f)));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.schedule), findsOneWidget);
    expect(find.byTooltip('Sending'), findsOneWidget);
  });

  testWidgets('a read outgoing message renders the read mark', (
    tester,
  ) async {
    final f = await makeFixture();
    await f.controller.sendText(recipientPubKey: f.peerX, plaintext: 'hi');
    final id = (await f.controller.messagesFor(f.peerX)).single.id;
    await f.controller.dao.setStatus(id, MessageStatus.read);

    await tester.pumpWidget(wrap(chat(f)));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.done_all), findsOneWidget);
    expect(find.byTooltip('Read'), findsOneWidget);
  });
}
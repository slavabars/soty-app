import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'chat_fixture.dart';

String composerText(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField)).controller!.text;

void main() {
  testWidgets('a stored draft is restored into the composer', (tester) async {
    final f = await makeFixture();
    await f.controller.saveDraft(f.peerX, 'half a thought');

    await tester.pumpWidget(wrap(chat(f)));
    await tester.pumpAndSettle();

    expect(composerText(tester), 'half a thought');
  });

  testWidgets('typing is persisted as a draft after the debounce',
      (tester) async {
    final f = await makeFixture();
    await tester.pumpWidget(wrap(chat(f)));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'not sent yet');
    await tester.pump(const Duration(milliseconds: 500));

    expect(await f.controller.draftFor(f.peerX), 'not sent yet');
  });

  testWidgets('a freshly queued message does not flash the red banner',
      (tester) async {
    final f = await makeFixture();
    await tester.pumpWidget(wrap(chat(f)));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'into the void');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();

    // No transports are wired, so the envelope stays queued, but a normal
    // send is still inside the grace window: no red banner yet.
    expect(find.text('Not delivered yet (1)'), findsNothing);
    // The text is no longer a draft: it is a stored envelope now.
    expect(await f.controller.draftFor(f.peerX), isNull);

    // Age the envelope, then let the delayed check run: the banner appears.
    await f.db.customStatement(
      'UPDATE messages SET timestamp = ?',
      [DateTime.now().millisecondsSinceEpoch - 60000],
    );
    await tester.pump(const Duration(seconds: 11));
    await tester.pumpAndSettle();
    expect(find.text('Not delivered yet (1)'), findsOneWidget);
    expect(
      find.text(
        'Message not delivered yet — Soty will retry when the peer is '
        'reachable.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Not delivered yet (1)'), findsOneWidget);
  });
}

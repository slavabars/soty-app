import 'package:flutter_test/flutter_test.dart';

import 'chat_fixture.dart';

void main() {
  testWidgets('tapping a soty link in a message opens the app route',
      (tester) async {
    final f = await makeFixture();
    const link = 'soty://invite?claim=eyJhIjoxfQ';
    await sendInbound(f, 'join $link');
    final routes = <String>[];
    await tester.pumpWidget(
      wrap(chat(f, onSotyLink: (route) async => routes.add(route))),
    );
    await tester.pumpAndSettle();

    await tester.tapOnText(find.textRange.ofSubstring(link));
    await tester.pump();

    expect(routes, [link]);
  });

  testWidgets('a soty link the app does not handle is not tappable',
      (tester) async {
    final f = await makeFixture();
    const link = 'soty://evil?claim=x';
    await sendInbound(f, 'join $link');
    final routes = <String>[];
    await tester.pumpWidget(
      wrap(chat(f, onSotyLink: (route) async => routes.add(route))),
    );
    await tester.pumpAndSettle();

    await tester.tapOnText(find.textRange.ofSubstring(link));
    await tester.pump();

    expect(routes, isEmpty);
    expect(find.text('join $link'), findsOneWidget);
  });

  testWidgets('a chat with no soty handler still renders the link text',
      (tester) async {
    final f = await makeFixture();
    const link = 'soty://invite?claim=1';
    await sendInbound(f, 'join $link');
    await tester.pumpWidget(wrap(chat(f)));
    await tester.pumpAndSettle();

    await tester.tapOnText(find.textRange.ofSubstring(link));
    await tester.pump();

    expect(find.text('join $link'), findsOneWidget);
  });
}

import 'package:dtm_app/features/messenger/linkified_text.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const urlChannel = MethodChannel('ru.dcns.soty/url');

  void mockUrl(Object? Function(MethodCall call)? handler) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(urlChannel, (call) async {
      return handler?.call(call);
    });
  }

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(urlChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets('tapping a link in the text opens its target', (tester) async {
    final opened = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LinkifiedText(
            'go https://example.com/x now',
            onOpen: (url) async => opened.add(url),
          ),
        ),
      ),
    );
    await tester.tapOnText(find.textRange.ofSubstring('https://example.com/x'));
    await tester.pump();
    expect(opened, ['https://example.com/x']);
  });

  testWidgets('plain text has nothing to tap', (tester) async {
    final opened = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LinkifiedText(
            'no link here',
            onOpen: (u) async => opened.add(u),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(LinkifiedText));
    await tester.pump();
    expect(opened, isEmpty);
  });

  testWidgets('a soty link goes to the app handler, not the browser',
      (tester) async {
    final routes = <String>[];
    final opened = <String>[];
    final clipboard = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') clipboard.add(call);
      return null;
    });
    mockUrl((call) => fail('the browser must never see a soty link'));
    const link = 'soty://invite?claim=eyJhIjoxfQ';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LinkifiedText(
            'join $link now',
            onOpen: (url) async => opened.add(url),
            onSotyLink: (route) async => routes.add(route),
          ),
        ),
      ),
    );
    await tester.tapOnText(find.textRange.ofSubstring(link));
    await tester.pump();

    expect(routes, [link]);
    expect(opened, isEmpty);
    expect(clipboard, isEmpty);
  });

  testWidgets('a soty link with no handler stays inert', (tester) async {
    final clipboard = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') clipboard.add(call);
      return null;
    });
    mockUrl((call) => fail('the browser must never see a soty link'));
    const link = 'soty://host?addr=wss%3A%2F%2Fexample.org%2Fws';
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: LinkifiedText('relay $link')),
      ),
    );
    await tester.tapOnText(find.textRange.ofSubstring(link));
    await tester.pump();

    expect(clipboard, isEmpty);
    expect(find.text('Link copied to clipboard'), findsNothing);
  });

  testWidgets('an http link still opens while a soty handler is set',
      (tester) async {
    final routes = <String>[];
    final opened = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LinkifiedText(
            'go https://example.com and soty://invite?claim=1',
            onOpen: (url) async => opened.add(url),
            onSotyLink: (route) async => routes.add(route),
          ),
        ),
      ),
    );
    await tester.tapOnText(
      find.textRange.ofSubstring('https://example.com'),
    );
    await tester.pump();

    expect(opened, ['https://example.com']);
    expect(routes, isEmpty);
  });

  testWidgets('a failed open copies the url and shows the notice',
      (tester) async {
    final clipboard = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') clipboard.add(call);
      return null;
    });
    mockUrl((_) => false);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: LinkifiedText('go https://example.com now')),
      ),
    );
    await tester.tapOnText(find.textRange.ofSubstring('https://example.com'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(clipboard, hasLength(1));
    expect(
      (clipboard.single.arguments as Map)['text'],
      'https://example.com',
    );
    expect(find.text('Link copied to clipboard'), findsOneWidget);
  });
}

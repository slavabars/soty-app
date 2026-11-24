import 'package:dtm_app/features/messenger/chat_screen.dart';
import 'package:dtm_app/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Two-device chat over the fixed p2p forwards (BUILD.md).
///
/// ```bash
/// flutter test integration_test/chat_e2e_test.dart -d emulator-5556 \
///   --dart-define=SOTY_ROLE=b
/// flutter test integration_test/chat_e2e_test.dart -d emulator-5554 \
///   --dart-define=SOTY_ROLE=a
/// ```
/// Role `a` lives on emulator-5554, role `b` on emulator-5556; each side
/// adds the other's X25519 key, libp2p peer id and multiaddr through the
/// "New chat" dialog, then one side pings and the other one answers.

const String _deviceAKey =
    '0478918d446ad70cf78542c4ec779db6acb34fa4e18d440a8979f9fda553707e';
const String _deviceAPeerId =
    '12D3KooWJcSLn9Zyp4TGLPqGtHujp7WDBV33DqduSdUpYGjWPfzb';
const String _deviceAAddr = '/ip4/10.0.2.2/tcp/5011';

const String _deviceBKey =
    'b54419b7a000d50f79bef603207a70aa2cd180d49444a954e6788657d918941e';
const String _deviceBPeerId =
    '12D3KooWKeqdaDTXEWMc9KfD9uuTH5dfV55DgwFpMULjM6MFyovz';
const String _deviceBAddr = '/ip4/10.0.2.2/tcp/5010';

const String _role = String.fromEnvironment('SOTY_ROLE');

String get _peerKey => _role == 'a' ? _deviceBKey : _deviceAKey;
String get _peerId => _role == 'a' ? _deviceBPeerId : _deviceAPeerId;
String get _peerAddr => _role == 'a' ? _deviceBAddr : _deviceAAddr;
String get _outgoing => _role == 'a' ? 'ping from A' : 'pong from B';
String get _incoming => _role == 'a' ? 'pong from B' : 'ping from A';

const String _peerName = 'E2E peer';

Future<void> _idle(WidgetTester tester, int frames) async {
  for (var i = 0; i < frames; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    await tester.pump();
  }
}

Future<bool> _waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 90),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (finder.evaluate().isNotEmpty) return true;
    await Future<void>.delayed(const Duration(milliseconds: 500));
    await tester.pump();
  }
  return finder.evaluate().isNotEmpty;
}

void _dismissKeyboard() {
  FocusManager.instance.primaryFocus?.unfocus();
}

/// Polls for [text] in the open chat; the seed DB carries a long history, so
/// a freshly delivered message appends below the fold and is invisible to
/// `find.text` until the list scrolls to its tail.
Future<bool> _waitForIncoming(
  WidgetTester tester,
  String text, {
  Duration timeout = const Duration(seconds: 300),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (find.text(text).evaluate().isNotEmpty) return true;
    await tester.fling(
      find.byType(ListView).first,
      const Offset(0, -800),
      1200,
    );
    await tester.pump(const Duration(milliseconds: 300));
  }
  return find.text(text).evaluate().isNotEmpty;
}

Future<void> _addContact(WidgetTester tester) async {
  await tester.tap(find.byType(FloatingActionButton));
  await tester.pump(const Duration(milliseconds: 500));
  await tester.tap(find.text('New chat'));
  await tester.pump(const Duration(milliseconds: 500));

  final fields = find.byType(TextField);
  expect(fields, findsNWidgets(4));
  await tester.enterText(fields.at(0), _peerKey);
  await tester.enterText(fields.at(1), _peerName);
  await tester.enterText(fields.at(2), _peerId);
  await tester.enterText(fields.at(3), _peerAddr);
  _dismissKeyboard();
  await tester.pump(const Duration(milliseconds: 500));

  await tester.tap(find.text('Start'));
  expect(
    await _waitFor(tester, find.byType(ChatScreen)),
    isTrue,
    reason: '$_role: chat with $_peerName did not open',
  );
  await _idle(tester, 8);
}

Future<void> _send(WidgetTester tester, String text) async {
  final composer = find.byType(TextField);
  expect(composer, findsOneWidget, reason: '$_role: composer not found');
  await tester.enterText(composer, text);
  _dismissKeyboard();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(find.byIcon(Icons.send));
  expect(
    await _waitFor(
      tester,
      find.text(text),
      timeout: const Duration(seconds: 20),
    ),
    isTrue,
    reason: '$_role: own message "$text" never showed up',
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('p2p chat A<->B carries an envelope', (tester) async {
    expect(
      _role,
      anyOf('a', 'b'),
      reason: 'run with --dart-define=SOTY_ROLE=a|b',
    );
    debugPrint('SotyE2E: role $_role starting');

    app.main();
    await _idle(tester, 40);
    expect(
      find.byType(FloatingActionButton),
      findsOneWidget,
      reason: '$_role: home screen never appeared',
    );

    await _addContact(tester);

    if (_role == 'b') {
      expect(
        await _waitForIncoming(tester, _incoming),
        isTrue,
        reason: '$_role: inbound "$_incoming" never arrived',
      );
      await _send(tester, _outgoing);
      debugPrint('SotyE2E: role b answered');
      // Keep the app alive so the pong flushes over p2p/relay and the
      // peer can render it before this test tears the process down.
      await _idle(tester, 40);
    } else {
      await _send(tester, _outgoing);
      expect(
        await _waitForIncoming(tester, _incoming),
        isTrue,
        reason: '$_role: inbound "$_incoming" never arrived',
      );
      debugPrint('SotyE2E: role a got the answer');
    }
  });
}

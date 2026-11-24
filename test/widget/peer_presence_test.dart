import 'package:dtm_app/core/i18n/soty_l10n.dart';
import 'package:dtm_app/features/messenger/peer_presence.dart';
import 'package:dtm_app/models/peer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

DtmPeer peerAt(Duration ago, {bool online = false}) => DtmPeer(
  pubKey: 'a' * 64,
  lastSeen: DateTime.now().subtract(ago),
  online: online,
);

Future<String> labelOf(
  WidgetTester tester,
  DtmPeer? peer, {
  Locale locale = const Locale('en'),
}) async {
  late String label;
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, w) => SotyL10n(locale: locale, child: w!),
      home: Builder(
        builder: (context) {
          label = presenceLabel(context, peer);
          return const SizedBox();
        },
      ),
    ),
  );
  return label;
}

void main() {
  group('presenceOf', () {
    test('a live transport is online, an unknown peer is offline', () {
      expect(presenceOf(peerAt(const Duration(days: 9), online: true)),
          PeerPresence.online);
      expect(presenceOf(null), PeerPresence.offline);
    });

    test('a peer heard of within the window is recent', () {
      expect(
        presenceOf(peerAt(const Duration(minutes: 4))),
        PeerPresence.recent,
      );
      expect(
        presenceOf(peerAt(const Duration(minutes: 6))),
        PeerPresence.offline,
      );
    });

    test('a backwards clock counts as recent, not as an absurd age', () {
      final future = DtmPeer(
        pubKey: 'a' * 64,
        lastSeen: DateTime.now().add(const Duration(hours: 3)),
      );
      expect(presenceOf(future), PeerPresence.recent);
    });
  });

  group('presenceLabel', () {
    testWidgets('online, just now, minutes, hours and days', (tester) async {
      expect(
        await labelOf(tester, peerAt(const Duration(hours: 2), online: true)),
        'online',
      );
      expect(
        await labelOf(tester, peerAt(const Duration(seconds: 20))),
        'last seen just now',
      );
      expect(
        await labelOf(tester, peerAt(const Duration(minutes: 7))),
        'last seen 7 min ago',
      );
      expect(
        await labelOf(tester, peerAt(const Duration(hours: 5))),
        'last seen 5 h ago',
      );
      expect(
        await labelOf(tester, peerAt(const Duration(days: 3))),
        'last seen 3 d ago',
      );
      expect(await labelOf(tester, null), 'offline');
    });

    testWidgets('russian picks the right plural form', (tester) async {
      expect(
        await labelOf(
          tester,
          peerAt(const Duration(minutes: 3)),
          locale: const Locale('ru'),
        ),
        'был(а) 3 минуты назад',
      );
      expect(
        await labelOf(
          tester,
          peerAt(const Duration(minutes: 5)),
          locale: const Locale('ru'),
        ),
        'был(а) 5 минут назад',
      );
      expect(
        await labelOf(
          tester,
          peerAt(const Duration(hours: 21)),
          locale: const Locale('ru'),
        ),
        'был(а) 21 час назад',
      );
    });
  });
}

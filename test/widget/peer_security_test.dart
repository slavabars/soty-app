import 'package:dtm_app/core/crypto/keypair.dart';
import 'package:dtm_app/core/crypto/safety_number.dart';
import 'package:dtm_app/features/messenger/peer_security_screen.dart';
import 'package:dtm_app/models/peer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'chat_fixture.dart';

Future<void> swapKey(Fixture f) async {
  final replacement = await DtmKeyPair.generate();
  await f.controller.importPeer(
    DtmPeer(
      pubKey: f.peerX,
      edPubKey: await replacement.ed25519PublicKeyHex,
      displayName: 'Zora',
      lastSeen: DateTime.now(),
    ),
  );
}

Widget security(Fixture f) => PeerSecurityScreen(
      messenger: f.controller,
      peerPubKey: f.peerX,
    );

void useTallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('shows the pair safety number and marks it verified',
      (tester) async {
    useTallView(tester);
    final f = await makeFixture();
    await tester.pumpWidget(wrap(security(f)));
    await tester.pumpAndSettle();

    final expected = await SafetyNumber.forPair(
      myX: f.controller.myXPubKey,
      myEd: f.controller.myEdPubKey,
      theirX: f.peerX,
      theirEd: (await f.remote.ed25519PublicKeyHex),
    );
    final shown = tester
        .widget<SelectableText>(find.byType(SelectableText))
        .data;
    expect(shown, expected);
    expect(find.text('Not verified'), findsOneWidget);

    await tester.tap(find.text('Mark as verified'));
    await tester.pumpAndSettle();

    expect(f.controller.peers[f.peerX]!.isVerified, isTrue);
    expect(find.text('Verified'), findsOneWidget);
    expect(find.text('Security code changed'), findsNothing);
  });

  testWidgets('a swapped Ed25519 key raises the warning and can be re-verified',
      (tester) async {
    useTallView(tester);
    final f = await makeFixture();
    await f.controller.markPeerVerified(f.peerX);
    await swapKey(f);

    await tester.pumpWidget(wrap(security(f)));
    await tester.pumpAndSettle();

    expect(find.text('Security code changed'), findsWidgets);
    expect(
      find.textContaining('presented a new key'),
      findsOneWidget,
    );

    await tester.tap(find.text('Mark as verified'));
    await tester.pumpAndSettle();

    expect(f.controller.peers[f.peerX]!.isVerified, isTrue);
    expect(find.text('Verified'), findsOneWidget);
    expect(find.text('Security code changed'), findsNothing);
  });

  testWidgets('a contact without an Ed25519 binding has no safety number',
      (tester) async {
    final f = await makeFixture();
    final bare = await DtmKeyPair.generate();
    final x = await bare.x25519PublicKeyHex;
    await f.controller.importPeer(
      DtmPeer(pubKey: x, displayName: 'Bare', lastSeen: DateTime.now()),
    );

    await tester.pumpWidget(
      wrap(
        PeerSecurityScreen(messenger: f.controller, peerPubKey: x),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Safety code unavailable'), findsOneWidget);
    expect(
      find.text('This contact has not published an Ed25519 key yet.'),
      findsOneWidget,
    );
    expect(find.byType(SelectableText), findsNothing);
  });

  testWidgets('the chat shows a banner and opens the security screen',
      (tester) async {
    final f = await makeFixture();
    await f.controller.markPeerVerified(f.peerX);
    await swapKey(f);

    await tester.pumpWidget(wrap(chat(f)));
    await tester.pumpAndSettle();
    expect(find.text('Security code changed'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.shield_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Safety number'), findsWidgets);
    expect(find.byType(SelectableText), findsOneWidget);
  });

  testWidgets('no banner for an unverified but unchanged contact',
      (tester) async {
    final f = await makeFixture();
    await tester.pumpWidget(wrap(chat(f)));
    await tester.pumpAndSettle();
    expect(find.text('Security code changed'), findsNothing);
  });

  testWidgets('report abuse opens the site form with the peer key',
      (tester) async {
    useTallView(tester);
    final f = await makeFixture();
    Uri? opened;
    await tester.pumpWidget(
      wrap(
        PeerSecurityScreen(
          messenger: f.controller,
          peerPubKey: f.peerX,
          opener: (uri) async {
            opened = uri;
            return true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Report abuse'));
    await tester.tap(find.text('Report abuse'));
    await tester.pumpAndSettle();

    expect(opened, isNotNull);
    expect(opened!.host, 'soty.su');
    expect(opened!.path, '/en/abuse');
    expect(opened!.queryParameters['peer'], f.peerX);
  });

  testWidgets('blocking a contact persists and flips the switch',
      (tester) async {
    useTallView(tester);
    final f = await makeFixture();
    await tester.pumpWidget(wrap(security(f)));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Block contact'));
    await tester.tap(find.text('Block contact'));
    await tester.pumpAndSettle();

    expect(f.controller.isPeerBlocked(f.peerX), isTrue);
    expect(
      tester
          .widget<SwitchListTile>(
            find.widgetWithText(SwitchListTile, 'Block contact'),
          )
          .value,
      isTrue,
    );

    await tester.tap(find.text('Block contact'));
    await tester.pumpAndSettle();
    expect(f.controller.isPeerBlocked(f.peerX), isFalse);
  });

  testWidgets('a blocked contact shows the banner and a locked composer',
      (tester) async {
    final f = await makeFixture();
    await f.controller.setPeerBlocked(f.peerX, true);
    await tester.pumpWidget(wrap(chat(f)));
    await tester.pumpAndSettle();

    expect(
      find.text('You blocked this contact. Unblock it in the safety screen.'),
      findsOneWidget,
    );
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
  });
}

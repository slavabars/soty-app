import 'package:dtm_app/core/crypto/envelope_crypto.dart';
import 'package:dtm_app/core/storage/database.dart';
import 'package:dtm_app/core/transport/transport.dart';
import 'package:flutter_test/flutter_test.dart';

import 'chat_fixture.dart';

Future<void> _deliver(Fixture f, int index) async {
  final envelope = await createEnvelopeForPubKey(
    sender: f.remote,
    recipientX25519PubKeyHex: f.controller.myXPubKey,
    plaintext: 'burst $index',
    timestamp: 20000 + index,
  );
  await f.processor.process(envelope, source: TransportSource.mesh, hops: 0);
}

void main() {
  testWidgets('a burst of inbound messages collapses into one render pass',
      (tester) async {
    final f = await makeFixture();
    await tester.pumpWidget(wrap(chat(f)));
    await tester.pumpAndSettle();

    final before = f.controller.messageRenderPasses;
    await Future.wait([for (var i = 0; i < 40; i++) _deliver(f, i)]);
    await tester.pumpAndSettle();

    expect(find.text('burst 39'), findsOneWidget);
    expect(
      f.controller.messageRenderPasses - before,
      lessThan(12),
      reason: 'a burst must not re-read the conversation once per envelope',
    );
  });

  testWidgets('a 10k history does not slow a burst in the open chat',
      (tester) async {
    final f = await makeFixture();
    final remoteEd = await f.remote.ed25519PublicKeyHex;
    await f.db.batch((batch) {
      batch.insertAll(f.db.messages, [
        for (var i = 0; i < 10000; i++)
          MessagesCompanion.insert(
            id: '4${i.toRadixString(16).padLeft(63, '0')}',
            senderPubKey: remoteEd,
            recipientPubKey: f.controller.myXPubKey,
            timestamp: 1000 + i,
            ciphertext: 'ciphertext',
            ephemeralPubKey: 'ee' * 32,
            signature: 'ff' * 64,
            source: 'mesh',
          ),
      ]);
    });
    await f.controller.markConversationRead(f.peerX);

    await tester.pumpWidget(wrap(chat(f)));
    await tester.pumpAndSettle();

    final before = f.controller.messageRenderPasses;
    final watch = Stopwatch()..start();
    await Future.wait([for (var i = 0; i < 40; i++) _deliver(f, i)]);
    await tester.pumpAndSettle();
    watch.stop();

    expect(find.text('burst 39'), findsOneWidget);
    expect(f.controller.messageRenderPasses - before, lessThan(12));
    expect(watch.elapsed, lessThan(const Duration(seconds: 5)));
  });
}

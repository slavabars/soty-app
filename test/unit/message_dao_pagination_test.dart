import 'package:dtm_app/core/crypto/envelope_crypto.dart';
import 'package:dtm_app/core/crypto/keypair.dart';
import 'package:dtm_app/core/storage/database.dart';
import 'package:dtm_app/core/storage/message_dao.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pagination is what keeps opening a long chat from decoding the whole
/// archive: the newest page only, oldest-first inside that page.
void main() {
  late AppDatabase db;
  late MessageDao dao;
  late DtmKeyPair sender;
  late DtmKeyPair recipient;
  late String recipientX;
  late String senderEd;
  late String senderX;

  setUp(() async {
    db = AppDatabase.inMemory();
    dao = MessageDao(db);
    sender = await DtmKeyPair.generate();
    recipient = await DtmKeyPair.generate();
    recipientX = await recipient.x25519PublicKeyHex;
    senderEd = await sender.ed25519PublicKeyHex;
    senderX = await sender.x25519PublicKeyHex;
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> seed(int count) async {
    for (var i = 0; i < count; i++) {
      final envelope = await createEnvelopeForPubKey(
        sender: sender,
        recipientX25519PubKeyHex: recipientX,
        plaintext: 'm$i',
        timestamp: 1000 + i,
      );
      await dao.insertIfAbsent(envelope, source: 'p2p');
    }
  }

  test('a page holds the newest envelopes, ordered oldest-first', () async {
    await seed(10);
    final page = await dao.messagesFor(
      senderX,
      myXPubKey: recipientX,
      myEdPubKey: await recipient.ed25519PublicKeyHex,
      peerEdPubKey: senderEd,
      limit: 3,
    );
    expect(page.map((e) => e.timestamp), [1007, 1008, 1009]);
  });

  test('a page without a limit returns the whole thread', () async {
    await seed(5);
    final all = await dao.messagesFor(
      senderX,
      myXPubKey: recipientX,
      myEdPubKey: await recipient.ed25519PublicKeyHex,
      peerEdPubKey: senderEd,
    );
    expect(all, hasLength(5));
  });

  test('before walks backwards through the history', () async {
    await seed(10);
    final older = await dao.messagesFor(
      senderX,
      myXPubKey: recipientX,
      myEdPubKey: await recipient.ed25519PublicKeyHex,
      peerEdPubKey: senderEd,
      limit: 2,
      before: 1007,
    );
    expect(older.map((e) => e.timestamp), [1005, 1006]);
  });

  test('outgoing rows are included only for this device', () async {
    final own = await createEnvelopeForPubKey(
      sender: recipient,
      recipientX25519PubKeyHex: senderX,
      plaintext: 'mine',
      timestamp: 2000,
    );
    await dao.insertIfAbsent(own, source: 'local');
    final page = await dao.messagesFor(
      senderX,
      myXPubKey: recipientX,
      myEdPubKey: await recipient.ed25519PublicKeyHex,
      peerEdPubKey: senderEd,
      limit: 10,
    );
    expect(page.single.id, own.id);
    expect(page.single.senderPubKey, await recipient.ed25519PublicKeyHex);
  });
}

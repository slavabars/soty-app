import 'package:dtm_app/core/crypto/envelope_crypto.dart';
import 'package:dtm_app/core/crypto/keypair.dart';
import 'package:dtm_app/core/storage/database.dart';
import 'package:dtm_app/core/storage/message_dao.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MessageDao.latestTimestamp', () {
    test('is null on an empty store', () async {
      final db = AppDatabase.inMemory();
      addTearDown(db.close);
      final dao = MessageDao(db);
      expect(await dao.latestTimestamp(), isNull);
    });

    test('returns the newest envelope timestamp', () async {
      final db = AppDatabase.inMemory();
      addTearDown(db.close);
      final dao = MessageDao(db);
      final sender = await DtmKeyPair.generate();
      final recipient = await DtmKeyPair.generate();
      final recipientX = await recipient.x25519PublicKeyHex;

      final older = await createEnvelopeForPubKey(
        sender: sender,
        recipientX25519PubKeyHex: recipientX,
        plaintext: 'old',
        timestamp: 1000,
      );
      final newer = await createEnvelopeForPubKey(
        sender: sender,
        recipientX25519PubKeyHex: recipientX,
        plaintext: 'new',
        timestamp: 2000,
      );
      await dao.insertIfAbsent(older, source: 'p2p');
      expect(await dao.latestTimestamp(), 1000);

      await dao.insertIfAbsent(newer, source: 'p2p');
      expect(await dao.latestTimestamp(), 2000);
    });
  });

  group('MessageDao.latestInboundTimestamp', () {
    test('is null on an empty store', () async {
      final db = AppDatabase.inMemory();
      addTearDown(db.close);
      final dao = MessageDao(db);
      expect(await dao.latestInboundTimestamp('aa', 'bb'), isNull);
    });

    test('counts only inbound addressed to self', () async {
      final db = AppDatabase.inMemory();
      addTearDown(db.close);
      final dao = MessageDao(db);
      final me = await DtmKeyPair.generate();
      final peer = await DtmKeyPair.generate();
      final myX = await me.x25519PublicKeyHex;
      final myEd = await me.ed25519PublicKeyHex;
      final peerX = await peer.x25519PublicKeyHex;

      final inbound = await createEnvelopeForPubKey(
        sender: peer,
        recipientX25519PubKeyHex: myX,
        plaintext: 'to me',
        timestamp: 3000,
      );
      final outbound = await createEnvelopeForPubKey(
        sender: me,
        recipientX25519PubKeyHex: peerX,
        plaintext: 'from me',
        timestamp: 4000,
      );
      final relayed = await createEnvelopeForPubKey(
        sender: peer,
        recipientX25519PubKeyHex: peerX,
        plaintext: 'not mine',
        timestamp: 5000,
      );

      await dao.insertIfAbsent(relayed, source: 'mesh');
      await dao.insertIfAbsent(outbound, source: 'local');
      // Own outbound and relayed mail must not advance the host cursor.
      expect(await dao.latestInboundTimestamp(myX, myEd), isNull);

      await dao.insertIfAbsent(inbound, source: 'p2p');
      expect(await dao.latestInboundTimestamp(myX, myEd), 3000);

      // A newer outbound still does not advance the inbound cursor.
      final newerOutbound = await createEnvelopeForPubKey(
        sender: me,
        recipientX25519PubKeyHex: peerX,
        plaintext: 'from me again',
        timestamp: 6000,
      );
      await dao.insertIfAbsent(newerOutbound, source: 'local');
      expect(await dao.latestInboundTimestamp(myX, myEd), 3000);
    });
  });
}
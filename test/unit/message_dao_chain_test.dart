import 'package:drift/drift.dart';
import 'package:dtm_app/core/crypto/envelope_crypto.dart';
import 'package:dtm_app/core/crypto/keypair.dart';
import 'package:dtm_app/core/storage/database.dart';
import 'package:dtm_app/core/storage/message_dao.dart';
import 'package:dtm_app/models/envelope.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MessageDao chain tracking', () {
    late AppDatabase db;
    late MessageDao dao;
    late DtmKeyPair sender;
    late DtmKeyPair recipient;
    late String recipientX;

    setUp(() async {
      db = AppDatabase.inMemory();
      dao = MessageDao(db);
      sender = await DtmKeyPair.generate();
      recipient = await DtmKeyPair.generate();
      recipientX = await recipient.x25519PublicKeyHex;
    });

    tearDown(() {
      db.close();
    });

    Future<Envelope> link(
      String plaintext, {
      required String chainLink,
      required int ts,
    }) {
      return createEnvelopeForPubKey(
        sender: sender,
        recipientX25519PubKeyHex: recipientX,
        plaintext: plaintext,
        timestamp: ts,
        chainLink: chainLink,
      );
    }

    test('first message for a pair is genesis and becomes the head', () async {
      final first = await link('one', chainLink: '', ts: 1);
      expect(await dao.insertIfAbsent(first, source: 'p2p'), isTrue);
      expect(await dao.isForked(first.id), isFalse);
      expect(
        await dao.chainLinkFor(await sender.ed25519PublicKeyHex, recipientX),
        first.id,
      );
    });

    test('chained inserts advance the head with a growing count', () async {
      final senderEd = await sender.ed25519PublicKeyHex;
      final first = await link('one', chainLink: '', ts: 1);
      await dao.insertIfAbsent(first);
      final second = await link('two', chainLink: first.id, ts: 2);
      await dao.insertIfAbsent(second);
      final third = await link('three', chainLink: second.id, ts: 3);
      await dao.insertIfAbsent(third);

      expect(await dao.isForked(first.id), isFalse);
      expect(await dao.isForked(second.id), isFalse);
      expect(await dao.isForked(third.id), isFalse);
      expect(await dao.chainLinkFor(senderEd, recipientX), third.id);

      final rows = await (db.conversationHeads.select()).get();
      expect(rows.single.count, 3);
      expect(rows.single.headId, third.id);
    });

    test('a wrong chainLink forks the row and keeps the head', () async {
      final first = await link('one', chainLink: '', ts: 1);
      await dao.insertIfAbsent(first);
      final second = await link('two', chainLink: first.id, ts: 2);
      await dao.insertIfAbsent(second);

      final forged = await link('forged', chainLink: first.id, ts: 4);
      expect(await dao.insertIfAbsent(forged), isTrue);
      expect(await dao.isForked(forged.id), isTrue);
      expect(
        await dao.chainLinkFor(await sender.ed25519PublicKeyHex, recipientX),
        second.id,
      );
    });

    test('a genesis-looking insert after a real head also forks', () async {
      final first = await link('one', chainLink: '', ts: 1);
      await dao.insertIfAbsent(first);

      final duplicateGenesis = await link('dup genesis', chainLink: '', ts: 5);
      await dao.insertIfAbsent(duplicateGenesis);
      expect(await dao.isForked(duplicateGenesis.id), isTrue);
    });

    test('out-of-order delivery is not a fork and does not poison the chain',
        () async {
      final first = await link('one', chainLink: '', ts: 1);
      await dao.insertIfAbsent(first);
      // The second message arrives after the third: its parent is unknown yet.
      final third = await link('three', chainLink: 'f' * 64, ts: 3);
      await dao.insertIfAbsent(third);
      final second = await link('two', chainLink: first.id, ts: 2);
      await dao.insertIfAbsent(second);

      expect(await dao.isForked(second.id), isFalse);
      expect(await dao.isForked(third.id), isFalse);
    });

    test('a chain rebuilt after a reinstall is accepted, not flagged',
        () async {
      // No local history at all: the first envelope for the pair carries a
      // chainLink to a message this device never stored.
      final orphan = await link('after reinstall', chainLink: 'a' * 64, ts: 7);
      await dao.insertIfAbsent(orphan);

      expect(await dao.isForked(orphan.id), isFalse);
      expect(
        await dao.chainLinkFor(await sender.ed25519PublicKeyHex, recipientX),
        orphan.id,
      );
    });

    test('a stale envelope behind the head keeps the head', () async {
      final first = await link('one', chainLink: '', ts: 1);
      await dao.insertIfAbsent(first);
      final second = await link('two', chainLink: first.id, ts: 5);
      await dao.insertIfAbsent(second);
      final late = await link('late', chainLink: 'b' * 64, ts: 2);
      await dao.insertIfAbsent(late);

      expect(await dao.isForked(late.id), isFalse);
      expect(
        await dao.chainLinkFor(await sender.ed25519PublicKeyHex, recipientX),
        second.id,
      );
    });

    test('two envelopes claiming the same parent are a real fork', () async {
      final first = await link('one', chainLink: '', ts: 1);
      await dao.insertIfAbsent(first);
      final branchA = await link('branch a', chainLink: first.id, ts: 2);
      await dao.insertIfAbsent(branchA);
      final branchB = await link('branch b', chainLink: first.id, ts: 3);
      await dao.insertIfAbsent(branchB);

      expect(await dao.isForked(branchB.id), isTrue);
      expect(
        await dao.chainLinkFor(await sender.ed25519PublicKeyHex, recipientX),
        branchA.id,
      );
    });

    test('replay of an existing id never alters the head', () async {
      final first = await link('one', chainLink: '', ts: 1);
      await dao.insertIfAbsent(first);
      final second = await link('two', chainLink: first.id, ts: 2);
      await dao.insertIfAbsent(second);

      expect(await dao.insertIfAbsent(second), isFalse);
      final rows = await (db.conversationHeads.select()).get();
      expect(rows.single.count, 2);
      expect(rows.single.headId, second.id);
    });

    test('the two directions of a conversation are independent chains',
        () async {
      final first = await link('a->b', chainLink: '', ts: 1);
      await dao.insertIfAbsent(first);

      final reply = await createEnvelopeForPubKey(
        sender: recipient,
        recipientX25519PubKeyHex: await sender.x25519PublicKeyHex,
        plaintext: 'b->a',
        timestamp: 2,
        chainLink: '',
      );
      await dao.insertIfAbsent(reply);

      expect(
        await dao.chainLinkFor(await sender.ed25519PublicKeyHex, recipientX),
        first.id,
      );
      expect(
        await dao.chainLinkFor(
          await recipient.ed25519PublicKeyHex,
          await sender.x25519PublicKeyHex,
        ),
        reply.id,
      );
    });
  });
}
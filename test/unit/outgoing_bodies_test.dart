import 'dart:convert';

import 'package:dtm_app/core/crypto/keypair.dart';
import 'package:dtm_app/core/storage/database.dart';
import 'package:dtm_app/core/storage/message_dao.dart';
import 'package:dtm_app/models/envelope.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late MessageDao dao;
  late DtmKeyPair device;

  final now = DateTime.now().toUtc().millisecondsSinceEpoch;
  int daysAgo(int days) => now - const Duration(days: 1).inMilliseconds * days;

  setUp(() async {
    db = AppDatabase.inMemory();
    dao = MessageDao(db);
    device = await DtmKeyPair.generate();
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> insertEnvelope(String id, {int? timestamp}) async {
    await dao.insertIfAbsent(
      Envelope(
        id: id,
        senderPubKey: 'sender',
        recipientPubKey: 'recipient',
        timestamp: timestamp ?? now,
        ciphertext: base64Encode(utf8.encode('ciphertext-$id')),
        ephemeralPubKey: 'ephemeral',
        signature: 'signature',
      ),
      source: 'test',
      hops: 0,
    );
  }

  group('outgoing bodies', () {
    test('putBody/bodyFor round-trips the plaintext', () async {
      await dao.putBody('env-1', plaintext: 'kept body', timestamp: 5);
      expect(await dao.bodyFor('env-1'), 'kept body');
    });

    test('bodyFor is null for an unknown id', () async {
      expect(await dao.bodyFor('env-missing'), isNull);
    });

    test('putBody is idempotent and never overwrites', () async {
      await dao.putBody('env-1', plaintext: 'first', timestamp: 5);
      await dao.putBody('env-1', plaintext: 'second', timestamp: 6);
      expect(await dao.bodyFor('env-1'), 'first');
    });

    test('pruning deletes bodies together with their envelopes', () async {
      await insertEnvelope('old-x', timestamp: daysAgo(40));
      await insertEnvelope('fresh-x', timestamp: daysAgo(1));
      await dao.putBody('old-x', plaintext: 'old body', timestamp: daysAgo(40));
      await dao.putBody(
        'fresh-x',
        plaintext: 'fresh body',
        timestamp: daysAgo(1),
      );

      await dao.pruneOlderThan(
        const Duration(days: 30),
        deviceKey: device,
      );

      expect(await dao.bodyFor('old-x'), isNull);
      expect(await dao.bodyFor('fresh-x'), 'fresh body');
    });

    test('pruneByPolicy strips bodies of pruned own rows too', () async {
      await dao.insertIfAbsent(
        Envelope(
          id: 'own-old',
          senderPubKey: await device.ed25519PublicKeyHex,
          recipientPubKey: 'bob-x',
          timestamp: daysAgo(60),
          ciphertext: base64Encode(utf8.encode('c')),
          ephemeralPubKey: 'ephemeral',
          signature: 'signature',
        ),
        source: 'test',
        hops: 0,
      );
      await dao.putBody(
        'own-old',
        plaintext: 'own body',
        timestamp: daysAgo(60),
      );

      final pub = await device.ed25519PublicKeyHex;
      final xPub = await device.x25519PublicKeyHex;
      await dao.pruneByPolicy(
        ownAge: const Duration(days: 30),
        relayedAge: const Duration(days: 30),
        relayedMaxBytes: 10 * 1024 * 1024 * 1024,
        myEdPubKey: pub,
        myXPubKey: xPub,
        deviceKey: device,
      );

      expect(await dao.bodyFor('own-old'), isNull);
    });
  });
}
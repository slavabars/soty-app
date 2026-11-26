import 'dart:convert';

import 'package:dtm_app/core/crypto/keypair.dart';
import 'package:dtm_app/core/storage/database.dart';
import 'package:dtm_app/core/storage/merkle.dart';
import 'package:dtm_app/core/storage/message_dao.dart';
import 'package:dtm_app/core/storage/pruned_roots_dao.dart';
import 'package:dtm_app/models/envelope.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late MessageDao dao;
  late PrunedRootsDao roots;
  late DtmKeyPair device;
  late String devicePub;
  late String deviceXPub;

  Future<int> storedCount() async {
    final rows = await db.select(db.messages).get();
    return rows.length;
  }

  Future<void> insertAt({
    required String id,
    required int timestamp,
    String sender = 'sender',
    String recipient = 'recipient',
    String? ciphertext,
  }) async {
    await dao.insertIfAbsent(
      Envelope(
        id: id,
        senderPubKey: sender,
        recipientPubKey: recipient,
        timestamp: timestamp,
        ciphertext: ciphertext ?? base64Encode(utf8.encode('ciphertext-$id')),
        ephemeralPubKey: 'ephemeral',
        signature: 'signature',
      ),
      source: 'test',
      hops: 0,
    );
  }

  int now() => DateTime.now().toUtc().millisecondsSinceEpoch;
  int daysAgo(int days) => now() - Duration(days: days).inMilliseconds;

  setUp(() async {
    db = AppDatabase.inMemory();
    dao = MessageDao(db);
    roots = PrunedRootsDao(db);
    device = await DtmKeyPair.generate();
    devicePub = await device.ed25519PublicKeyHex;
    deviceXPub = await device.x25519PublicKeyHex;
  });

  tearDown(() async {
    await db.close();
  });

  group('30-day retention pruning', () {
    test('prunes old messages and persists a verifiable signed root', () async {
      await insertAt(id: 'old-1', timestamp: daysAgo(40));
      await insertAt(id: 'old-2', timestamp: daysAgo(35));
      await insertAt(id: 'fresh-1', timestamp: daysAgo(1)); // still kept
      expect(await storedCount(), 3);

      final batch = await dao.pruneOlderThan(
        const Duration(days: 30),
        deviceKey: device,
      );

      expect(batch.count, 2);
      expect(batch.deletedAny, isTrue);
      expect(batch.merkleRoot, isNotNull);
      expect(batch.signature, isNotNull);
      expect(await storedCount(), 1);

      final entries = await roots.getPrunedRoots();
      expect(entries, hasLength(1));
      final entry = entries.single;
      expect(entry.count, 2);
      expect(
        entry.cutoffTs,
        lessThan(now() - const Duration(days: 20).inMilliseconds),
      );
      expect(entry.merkleRoot, batch.merkleRoot);
      expect(entry.devicePubKey, devicePub);

      expect(
        await roots.verifyRootSignature(entry, devicePubKeyHex: devicePub),
        isTrue,
      );
    });

    test('empty prunes write no root and delete nothing', () async {
      final batch = await dao.pruneOlderThan(
        const Duration(days: 30),
        deviceKey: device,
      );
      expect(batch.count, 0);
      expect(batch.deletedAny, isFalse);
      expect(batch.merkleRoot, isNull);
      expect(await roots.getPrunedRoots(), isEmpty);
    });

    test('a wrong device key invalidates the root signature', () async {
      await insertAt(id: 'old-x', timestamp: daysAgo(40));
      await dao.pruneOlderThan(const Duration(days: 30), deviceKey: device);

      final other = await DtmKeyPair.generate();
      final entries = await roots.getPrunedRoots();
      expect(
        await roots.verifyRootSignature(
          entries.single,
          devicePubKeyHex: await other.ed25519PublicKeyHex,
        ),
        isFalse,
      );
    });
  });

  group('retention policy pruning', () {
    Future<List<PrunedBatch>> prune({
      int? ownDays,
      int relayedDays = 30,
      int relayedMaxBytes = 10 * 1024 * 1024 * 1024,
    }) =>
        dao.pruneByPolicy(
          ownAge: ownDays == null ? null : Duration(days: ownDays),
          relayedAge: Duration(days: relayedDays),
          relayedMaxBytes: relayedMaxBytes,
          myEdPubKey: devicePub,
          myXPubKey: deviceXPub,
          deviceKey: device,
        );

    test('prunes old own and relayed rows independently of each other',
        () async {
      // Own conversation: device sent them (sender == devicePub).
      await insertAt(
        id: 'own-old',
        timestamp: daysAgo(60),
        sender: devicePub,
        recipient: 'bob-x',
      );
      await insertAt(
        id: 'own-fresh',
        timestamp: daysAgo(5),
        sender: devicePub,
        recipient: 'bob-x',
      );
      // Relayed (for strangers): neither endpoint is ours.
      await insertAt(id: 'relay-old', timestamp: daysAgo(60));
      await insertAt(id: 'relay-fresh', timestamp: daysAgo(5));
      expect(await storedCount(), 4);

      final batches = await prune(ownDays: 30);

      expect(await storedCount(), 2);
      expect(
        await db.select(db.messages).get().then(
          (rows) => rows.map((r) => r.id).toSet(),
        ),
        {'own-fresh', 'relay-fresh'},
      );
      final deleted = batches.fold<int>(0, (sum, b) => sum + b.count);
      expect(deleted, 2);
      final entries = await roots.getPrunedRoots();
      expect(entries, hasLength(2));
      for (final entry in entries) {
        expect(
          await roots.verifyRootSignature(
            entry,
            devicePubKeyHex: devicePub,
          ),
          isTrue,
        );
      }
    });

    test('forever keeps own rows old but still prunes relayed ones', () async {
      await insertAt(
        id: 'own-old',
        timestamp: daysAgo(400),
        sender: devicePub,
        recipient: 'bob-x',
      );
      await insertAt(id: 'relay-old', timestamp: daysAgo(400));
      await insertAt(id: 'relay-fresh', timestamp: daysAgo(1));

      final batches = await prune(ownDays: 0);

      expect(await storedCount(), 2);
      final remaining = await db
          .select(db.messages)
          .get()
          .then((rows) => rows.map((r) => r.id).toSet());
      expect(remaining, {'own-old', 'relay-fresh'});
      expect(batches.single.count, 1);
    });

    test('inbound own messages are kept to the user age too', () async {
      await insertAt(
        id: 'recv-old',
        timestamp: daysAgo(40),
        sender: 'alice-ed',
        recipient: deviceXPub,
      );
      await insertAt(
        id: 'recv-fresh',
        timestamp: daysAgo(1),
        sender: 'alice-ed',
        recipient: deviceXPub,
      );

      final batches = await prune(ownDays: 30);

      expect(await storedCount(), 1);
      expect(batches.single.count, 1);
    });

    test('relayed byte cap evicts the oldest relayed rows first', () async {
      final payload = base64Encode(List.filled(8, 0xab));
      for (var i = 0; i < 20; i++) {
        await insertAt(
          id: 'r${i.toString().padLeft(2, '0')}',
          timestamp: now() - (20 - i) * 1000,
          ciphertext: payload,
        );
      }
      expect(await storedCount(), 20);

      final batches = await prune(ownDays: null, relayedMaxBytes: 40);

      expect(await storedCount(), 5);
      final remaining = await db
          .select(db.messages)
          .get()
          .then((rows) => rows.map((r) => r.id).toSet());
      expect(remaining, {'r15', 'r16', 'r17', 'r18', 'r19'});
      final bytePrune = batches.last;
      expect(bytePrune.count, 15);
      final entries = await roots.getPrunedRoots();
      expect(entries, hasLength(1));
      expect(
        await roots.verifyRootSignature(
          entries.single,
          devicePubKeyHex: devicePub,
        ),
        isTrue,
      );
    });

    test('relayed policy never touches own rows', () async {
      await insertAt(
        id: 'own-old',
        timestamp: daysAgo(400),
        sender: devicePub,
        recipient: 'bob-x',
      );
      await insertAt(id: 'relay-old', timestamp: daysAgo(400));

      final batches = await prune(ownDays: 0);

      expect(await storedCount(), 1);
      expect(
        await db.select(db.messages).get().then(
          (rows) => rows.map((r) => r.id).toSet(),
        ),
        {'own-old'},
      );
      expect(batches.single.count, 1);
    });

    test('no old own rows and no relayed rows writes nothing', () async {
      final batches = await prune(ownDays: 30);
      expect(batches, isEmpty);
      expect(await roots.getPrunedRoots(), isEmpty);
    });
    test('prunes more rows than a typical SQLite bound-variable limit',
        () async {
      // 1500 > 999, the lowest common SQLITE_MAX_VARIABLE_NUMBER on Android.
      // The DAO must split the delete into chunks; one giant IN (…) would
      // throw and roll the retention transaction back on a real device.
      for (var i = 0; i < 1500; i++) {
        await insertAt(id: 'old-$i', timestamp: daysAgo(40));
      }
      final batches = await prune(relayedDays: 30);
      expect(await storedCount(), 0);
      expect(batches.fold<int>(0, (sum, b) => sum + b.count), 1500);
    });
  });

  group('per-conversation cap', () {
    test(
      'keeps the newest rows and prunes the rest with a signed root',
      () async {
        for (var i = 0; i < 12; i++) {
          await insertAt(id: 'c-$i', timestamp: now() + i);
        }
        expect(await storedCount(), 12);

        final batch = await dao.pruneConversationOverCap(
          'recipient',
          myXPubKey: 'sender',
          myEdPubKey: 'sender',
          cap: 10,
          deviceKey: device,
        );

        expect(batch.count, 2);
        expect(await storedCount(), 10);

        final entries = await roots.getPrunedRoots();
        expect(entries, hasLength(1));
        expect(
          await roots.verifyRootSignature(
            entries.single,
            devicePubKeyHex: devicePub,
          ),
          isTrue,
        );
      },
    );
  });

  group('MerkleTree', () {
    test('a single leaf root is the lowercased id', () async {
      final root = await const MerkleTree(['ABC123']).root();
      expect(root, 'abc123');
    });

    test('is deterministic for the same id set', () async {
      final ids = ['123', '456', '789', 'abc'];
      final a = await merkleRoot(ids);
      final b = await merkleRoot(ids);
      final reversed = await merkleRoot(ids.reversed.toList());
      expect(a, b);
      expect(a, isNot(reversed), reason: 'ordering must be canonical');
    });

    test('empty tree has no root', () async {
      expect(await merkleRoot(const []), isNull);
    });

  });
}

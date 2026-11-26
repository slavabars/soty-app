import 'dart:convert';
import 'dart:io';

import 'package:dtm_app/core/backup/backup_crypto.dart';
import 'package:dtm_app/core/backup/backup_format.dart';
import 'package:dtm_app/core/backup/backup_service.dart';
import 'package:dtm_app/core/crypto/envelope_crypto.dart';
import 'package:dtm_app/core/crypto/keypair.dart';
import 'package:dtm_app/core/security_limits.dart';
import 'package:dtm_app/core/storage/database.dart';
import 'package:dtm_app/core/storage/identity_dao.dart';
import 'package:dtm_app/core/storage/message_dao.dart';
import 'package:dtm_app/core/storage/peer_dao.dart';
import 'package:dtm_app/core/storage/secure_identity_store.dart';
import 'package:dtm_app/models/message_status.dart';
import 'package:dtm_app/models/peer.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeStore implements SecureIdentityStore {
  SecureSeeds? seeds;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<SecureSeeds?> read() async => seeds;

  @override
  Future<void> write(SecureSeeds value) async => seeds = value;

  @override
  Future<void> clear() async => seeds = null;
}

final _edSeed = '11' * 32;
final _xSeed = '22' * 32;

Future<DtmKeyPair> _identity() => DtmKeyPair.fromSeeds(
      ed25519SeedHex: _edSeed,
      x25519SeedHex: _xSeed,
    );

DtmPeer _peer(
  String x, {
  String? ed,
  String name = 'Anna',
  bool contact = true,
}) =>
    _peerWith(x, ed: ed ?? 'aa' * 32, name: name, contact: contact);

DtmPeer _peerWith(
  String x, {
  required String ed,
  String name = 'Anna',
  bool contact = true,
}) =>
    DtmPeer(
      pubKey: x,
      edPubKey: ed,
      displayName: name,
      peerId: '12D3KooWAnna',
      addrs: const ['/ip4/10.0.2.2/tcp/5010'],
      lastSeen: DateTime.fromMillisecondsSinceEpoch(1700000000000),
      isContact: contact,
    );

void main() {
  late AppDatabase db;
  late _FakeStore store;
  late IdentityDao identityDao;
  late PeerDao peerDao;
  late BackupService service;

  setUp(() async {
    db = AppDatabase.inMemory();
    store = _FakeStore();
    identityDao = IdentityDao(db, secureStore: store);
    peerDao = PeerDao(db);
    service = BackupService(identityDao: identityDao, peerDao: peerDao);
    await identityDao.save(await _identity(), displayName: 'Alice');
    await peerDao.upsert(_peer('a1' * 32));
    await peerDao.upsert(_peer('b2' * 32, ed: 'bb' * 32, name: 'Bob'));
    await peerDao.markVerified('a1' * 32, 'aa' * 32);
  });

  tearDown(() async {
    await db.close();
  });

  test('a backup round-trips identity, contacts and verification', () async {
    final raw = await service.exportBackup(password: 'correct horse');
    final payload = await service.readBackup(
      raw: raw,
      password: 'correct horse',
    );

    final keyPair = await _identity();
    expect(payload.identity.edSeedHex, await keyPair.ed25519SeedHex);
    // X25519 seeds are clamped on load; the public key is what must survive.
    expect(payload.identity.xSeedHex, await keyPair.x25519SeedHex);
    expect(payload.identity.displayName, 'Alice');
    expect(payload.peers, hasLength(2));
    final anna = payload.peers.firstWhere((p) => p.pubKey == 'a1' * 32);
    expect(anna.displayName, 'Anna');
    expect(anna.verifiedEdPubKey, 'aa' * 32);
    final bob = payload.peers.firstWhere((p) => p.pubKey == 'b2' * 32);
    expect(bob.verifiedEdPubKey, isNull);
  });

  test('control rows never enter the backup', () async {
    final pair = await _identity();
    final normal = await createEnvelopeForPubKey(
      sender: pair,
      recipientX25519PubKeyHex: 'a1' * 32,
      plaintext: 'hello',
    );
    final control = await createEnvelopeForPubKey(
      sender: pair,
      recipientX25519PubKeyHex: 'a1' * 32,
      plaintext: 'd1\n${'cd' * 32}',
    );
    final dao = MessageDao(db);
    await dao.insertIfAbsent(normal, source: 'local', hops: 0);
    await dao.insertIfAbsent(control, source: 'local', hops: 0);
    await dao.markControl(control.id);

    final raw = await service.exportBackup(password: 'pw');
    final payload = await service.readBackup(raw: raw, password: 'pw');
    final ids = payload.history!.messages.map((m) => m.id).toSet();
    expect(ids, contains(normal.id));
    expect(ids, isNot(contains(control.id)));
  });

  test('a streaming backup round-trips into a fresh database', () async {
    final pair = await _identity();
    final envelope = await createEnvelopeForPubKey(
      sender: pair,
      recipientX25519PubKeyHex: 'a1' * 32,
      plaintext: 'streamed hello',
    );
    final dao = MessageDao(db);
    await dao.insertIfAbsent(envelope, source: 'local', hops: 0);
    await dao.setStatus(envelope.id, MessageStatus.sent);
    await db.into(db.outgoingBodies).insert(
          OutgoingBodiesCompanion.insert(
            id: envelope.id,
            plaintext: 'streamed hello',
            timestamp: envelope.timestamp,
          ),
        );

    final dir = await Directory.systemTemp.createTemp('soty_backup_service');
    addTearDown(() => dir.delete(recursive: true));
    final path = '${dir.path}/backup.soty';
    await service.exportBackupToFile(path: path, password: 'pw');

    final freshDb = AppDatabase.inMemory();
    addTearDown(freshDb.close);
    final freshStore = _FakeStore();
    final freshIdentity = IdentityDao(freshDb, secureStore: freshStore);
    final freshPeers = PeerDao(freshDb);
    final freshService = BackupService(
      identityDao: freshIdentity,
      peerDao: freshPeers,
    );
    await freshService.restoreBackupFromFile(
      path: path,
      password: 'pw',
      replaceExisting: true,
    );

    expect((await freshIdentity.load())!.displayName, 'Alice');
    expect(await freshPeers.all(), hasLength(2));
    final rows = await freshDb.select(freshDb.messages).get();
    expect(rows.map((r) => r.id), contains(envelope.id));
    expect((await freshDb.select(freshDb.messageStatuses).get()).single.status,
        MessageStatus.sent.index);
    expect((await freshDb.select(freshDb.outgoingBodies).get()).single.id,
        envelope.id);
  });

  test('a streaming backup pages through more than 500 messages', () async {
    await db.batch((batch) {
      batch.insertAll(db.messages, [
        for (var i = 0; i < 1100; i++)
          MessagesCompanion.insert(
            id: i.toRadixString(16).padLeft(64, '0'),
            senderPubKey: 'aa' * 32,
            recipientPubKey: 'bb' * 32,
            timestamp: 1000 + i,
            ciphertext: 'ciphertext-$i',
            ephemeralPubKey: 'ee' * 32,
            signature: 'ff' * 64,
            source: 'local',
          ),
      ]);
    });

    final dir = await Directory.systemTemp.createTemp('soty_backup_service');
    addTearDown(() => dir.delete(recursive: true));
    final path = '${dir.path}/backup.soty';
    await service.exportBackupToFile(path: path, password: 'pw');

    final freshDb = AppDatabase.inMemory();
    addTearDown(freshDb.close);
    final freshService = BackupService(
      identityDao: IdentityDao(freshDb, secureStore: _FakeStore()),
      peerDao: PeerDao(freshDb),
    );
    await freshService.restoreBackupFromFile(
      path: path,
      password: 'pw',
      replaceExisting: true,
    );
    final rows = await freshDb.select(freshDb.messages).get();
    expect(rows, hasLength(1100));
  });

  test('a streaming backup rejects a wrong password', () async {
    final dir = await Directory.systemTemp.createTemp('soty_backup_service');
    addTearDown(() => dir.delete(recursive: true));
    final path = '${dir.path}/backup.soty';
    await service.exportBackupToFile(path: path, password: 'right');
    await expectLater(
      service.restoreBackupFromFile(
        path: path,
        password: 'wrong',
        replaceExisting: true,
      ),
      throwsA(isA<BackupAuthFailure>()),
    );
  });

  test('restoring into a fresh database recreates the identity and book',
      () async {
    final raw = await service.exportBackup(password: 'pw');
    final payload = await service.readBackup(raw: raw, password: 'pw');
    final keyPair = await _identity();

    final freshDb = AppDatabase.inMemory();
    addTearDown(freshDb.close);
    final freshStore = _FakeStore();
    final freshIdentity = IdentityDao(freshDb, secureStore: freshStore);
    final freshPeers = PeerDao(freshDb);
    final freshService = BackupService(
      identityDao: freshIdentity,
      peerDao: freshPeers,
    );

    await freshService.restore(payload, replaceExisting: false);

    final restored = await freshIdentity.load();
    expect(restored!.displayName, 'Alice');
    expect(
      await restored.keyPair.ed25519SeedHex,
      await keyPair.ed25519SeedHex,
    );
    expect(freshStore.seeds!.edSeedHex, await keyPair.ed25519SeedHex);
    final row = await freshDb.select(freshDb.identityEntry).getSingle();
    expect(row.edSeedHex, isEmpty);

    final peers = await freshPeers.all();
    expect(peers, hasLength(2));
    final anna = peers.firstWhere((p) => p.pubKey == 'a1' * 32);
    expect(anna.isVerified, isTrue);
    expect(anna.verifiedEdPubKey, 'aa' * 32);
    final bob = peers.firstWhere((p) => p.pubKey == 'b2' * 32);
    expect(bob.isVerified, isFalse);
  });

  test('history round-trips: chats, envelopes, statuses and bodies', () async {
    final kp = await _identity();
    final myX = await kp.x25519PublicKeyHex;
    final db2 = AppDatabase.inMemory();
    addTearDown(db2.close);
    await db2.customStatement(
      'INSERT INTO conversations '
      '(id, kind, title, created_ts, last_ts, read_at) '
      'VALUES (?, ?, ?, ?, ?, ?)',
      ['aa' * 32, 'group', 'Team', 10, 40, 25],
    );
    await db2.customStatement(
      'INSERT INTO conversation_members (conversation_id, peer_x_key, role) '
      'VALUES (?, ?, ?), (?, ?, ?)',
      ['aa' * 32, 'bb' * 32, 'admin', 'aa' * 32, 'cc' * 32, 'member'],
    );
    await db2.customStatement(
      'INSERT INTO messages (id, sender_pub_key, recipient_pub_key, timestamp, '
      'ciphertext, ephemeral_pub_key, signature, source, hops, chain_link, '
      'forked, control, group_payload, group_id) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?), '
      '(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [
        '11' * 32, 'bb' * 32, myX, 20, 'cipher', '22' * 32, '33' * 64,
        'mesh', 1, '', 0, 0, 1, 'aa' * 32,
        '44' * 32, 'bb' * 32, myX, 30, 'cipher2', '55' * 32, '66' * 64,
        'p2p', 0, '', 0, 0, 1, 'aa' * 32,
      ],
    );
    await db2.customStatement(
      'INSERT INTO message_statuses (id, status, updated_at) '
      'VALUES (?, ?, ?)',
      ['11' * 32, 2, 35],
    );
    await db2.customStatement(
      'INSERT INTO outgoing_bodies (id, plaintext, timestamp) '
      'VALUES (?, ?, ?)',
      ['44' * 32, 'sent text', 30],
    );

    final store2 = _FakeStore();
    final service2 = BackupService(
      identityDao: IdentityDao(db2, secureStore: store2),
      peerDao: PeerDao(db2),
    );
    await IdentityDao(db2, secureStore: store2).save(
      await _identity(),
      displayName: 'Alice',
    );

    final raw = await service2.exportBackup(password: 'pw');
    final payload = await service2.readBackup(raw: raw, password: 'pw');
    expect(payload.history, isNotNull);
    expect(payload.history!.conversations, hasLength(1));
    expect(payload.history!.conversations.single.members, hasLength(2));
    expect(payload.history!.messages, hasLength(2));
    expect(payload.history!.statuses.single.status, 2);
    expect(payload.history!.bodies.single.plaintext, 'sent text');

    final freshDb = AppDatabase.inMemory();
    addTearDown(freshDb.close);
    final fresh = BackupService(
      identityDao: IdentityDao(freshDb, secureStore: _FakeStore()),
      peerDao: PeerDao(freshDb),
    );
    await fresh.restore(payload, replaceExisting: false);

    final restored = await freshDb.customSelect(
      'SELECT id, kind, title, last_ts, read_at FROM conversations',
    ).get();
    expect(restored.single.read<String>('title'), 'Team');
    expect(restored.single.read<int>('last_ts'), 40);
    expect(
      await freshDb.customSelect('SELECT id FROM messages').get(),
      hasLength(2),
    );
    expect(
      await freshDb.customSelect('SELECT status FROM message_statuses').get(),
      hasLength(1),
    );
    expect(
      await freshDb.customSelect('SELECT plaintext FROM outgoing_bodies').get(),
      hasLength(1),
    );

    // The host subscription cursor is the newest restored inbound message, so
    // a reconnect asks only for mail newer than what the backup already has
    // instead of replaying the whole relay store one envelope at a time.
    final cursor = await MessageDao(freshDb).latestInboundTimestamp(
      myX,
      await kp.ed25519PublicKeyHex,
    );
    expect(cursor, 30);

    // Restoring the same file twice dedupes.
    await fresh.restore(payload, replaceExisting: true);
    expect(
      await freshDb.customSelect('SELECT id FROM messages').get(),
      hasLength(2),
    );
    expect(
      await freshDb.customSelect('SELECT id FROM conversations').get(),
      hasLength(1),
    );
  });

  test('a payload with too many messages is rejected', () async {
    final messages = [
      for (var i = 0; i < maxBackupMessages + 1; i++)
        {
          'id': i.toRadixString(16).padLeft(64, '0'),
          'senderPubKey': _edSeed,
          'recipientPubKey': _edSeed,
          'timestamp': i,
          'ciphertext': 'c',
          'ephemeralPubKey': _edSeed,
          'signature': _edSeed,
          'source': 'mesh',
          'hops': 0,
          'chainLink': '',
          'forked': false,
          'control': false,
          'groupPayload': false,
        },
    ];
    final payload = jsonEncode({
      'format': 'soty-backup-payload-2',
      'identity': {
        'edSeedHex': _edSeed,
        'xSeedHex': _edSeed,
        'displayName': 'Alice',
      },
      'peers': <Object>[],
      'history': {
        'conversations': <Object>[],
        'messages': messages,
        'statuses': <Object>[],
        'bodies': <Object>[],
      },
    });
    final raw = await BackupFile.seal(payload: payload, password: 'pw');
    await expectLater(
      service.readBackup(raw: raw, password: 'pw'),
      throwsA(isA<FormatException>()),
    );
  });

  test('a wrong password is rejected without leaking anything', () async {
    final raw = await service.exportBackup(password: 'right');
    await expectLater(
      service.readBackup(raw: raw, password: 'wrong'),
      throwsA(isA<BackupAuthFailure>()),
    );
  });

  test('a truncated file is rejected', () async {
    final raw = await service.exportBackup(password: 'pw');
    await expectLater(
      service.readBackup(
        raw: raw.substring(0, raw.length ~/ 2),
        password: 'pw',
      ),
      throwsA(isA<FormatException>()),
    );
    await expectLater(
      service.readBackup(
        raw: raw.substring(0, raw.length - 24),
        password: 'pw',
      ),
      throwsA(anyOf(isA<FormatException>(), isA<BackupAuthFailure>())),
    );
  });

  test('a tampered ciphertext is rejected', () async {
    final raw = await service.exportBackup(password: 'pw');
    final object = jsonDecode(raw) as Map<String, dynamic>;
    final cipher = object['cipher'] as Map<String, dynamic>;
    final bytes = base64Decode(cipher['ciphertext'] as String);
    bytes[0] ^= 1;
    cipher['ciphertext'] = base64Encode(bytes);
    await expectLater(
      service.readBackup(raw: jsonEncode(object), password: 'pw'),
      throwsA(isA<BackupAuthFailure>()),
    );
  });

  test('a backup file cannot demand unbounded KDF memory', () async {
    final raw = await service.exportBackup(password: 'pw');
    final object = jsonDecode(raw) as Map<String, dynamic>;
    (object['kdf'] as Map<String, dynamic>)['memoryKib'] = 4 * 1024 * 1024;
    await expectLater(
      service.readBackup(raw: jsonEncode(object), password: 'pw'),
      throwsA(isA<FormatException>()),
    );

    (object['kdf'] as Map<String, dynamic>)['memoryKib'] = backupKdfMemoryKib;
    (object['kdf'] as Map<String, dynamic>)['iterations'] = 1;
    await expectLater(
      service.readBackup(raw: jsonEncode(object), password: 'pw'),
      throwsA(isA<FormatException>()),
    );
  });

  test('the backup file ceiling is one gibibyte', () {
    expect(maxBackupBytes, 1024 * 1024 * 1024);
    expect(maxBackupUploadBytes, maxBackupBytes);
  });

  test('an oversize document is rejected before parsing', () async {
    await expectLater(
      service.readBackup(raw: 'x' * (maxBackupBytes + 1), password: 'pw'),
      throwsA(isA<FormatException>()),
    );
  });

  test('a payload with too many peers is rejected', () async {
    final peers = [
      for (var i = 0; i < maxBackupPeers + 1; i++)
        {
          'pubKey': i.toRadixString(16).padLeft(64, '0'),
          'displayName': '',
          'addrs': <String>[],
          'lastSeen': 1,
          'isContact': false,
        },
    ];
    final payload = jsonEncode({
      'format': 'soty-backup-payload-1',
      'identity': {
        'edSeedHex': _edSeed,
        'xSeedHex': _xSeed,
        'displayName': 'Alice',
      },
      'peers': peers,
    });
    final raw = await BackupFile.seal(payload: payload, password: 'pw');
    await expectLater(
      service.readBackup(raw: raw, password: 'pw'),
      throwsA(isA<FormatException>()),
    );
  });

  test('malformed keys and names in a payload are rejected', () async {
    final payload = jsonEncode({
      'format': 'soty-backup-payload-1',
      'identity': {
        'edSeedHex': 'zz',
        'xSeedHex': _xSeed,
        'displayName': 'Alice',
      },
      'peers': <Object>[],
    });
    final raw = await BackupFile.seal(payload: payload, password: 'pw');
    await expectLater(
      service.readBackup(raw: raw, password: 'pw'),
      throwsA(isA<FormatException>()),
    );
  });

  test('restoring over an existing identity needs explicit confirmation',
      () async {
    final raw = await service.exportBackup(password: 'pw');
    final payload = await service.readBackup(raw: raw, password: 'pw');

    await expectLater(
      service.restore(payload, replaceExisting: false),
      throwsStateError,
    );
    final still = await identityDao.load();
    expect(await still!.keyPair.ed25519SeedHex, _edSeed);

    await service.restore(payload, replaceExisting: true);
    expect((await identityDao.load())!.displayName, 'Alice');
  });

  test('a changed binding is restored as unverified, not trusted', () async {
    final raw = await service.exportBackup(password: 'pw');
    final payload = await service.readBackup(raw: raw, password: 'pw');
    final tampered = BackupPayload(
      identity: payload.identity,
      peers: [
        BackupPeer(
          pubKey: payload.peers.first.pubKey,
          edPubKey: 'cc' * 32,
          displayName: payload.peers.first.displayName,
          addrs: payload.peers.first.addrs,
          lastSeen: payload.peers.first.lastSeen,
          isContact: true,
          verifiedEdPubKey: payload.peers.first.verifiedEdPubKey,
        ),
      ],
    );
    await service.restore(tampered, replaceExisting: true);

    final anna = await peerDao.find('a1' * 32);
    expect(anna!.edPubKey, 'cc' * 32);
    expect(anna.isVerified, isFalse);
    expect(anna.keyChanged, isTrue);
  });

  test('an empty or overlong password is refused', () async {
    await expectLater(
      service.exportBackup(password: ''),
      throwsA(isA<FormatException>()),
    );
    await expectLater(
      service.exportBackup(password: 'p' * (maxBackupPasswordLength + 1)),
      throwsA(isA<FormatException>()),
    );
  });
  test('a non-stream backup file over the cap is rejected before reading',
      () async {
    final dir = Directory.systemTemp.createTempSync('soty_big_backup');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = '${dir.path}/huge.bin';
    final file = await File(path).open(mode: FileMode.write);
    await file.truncate(maxBackupBytes + 64 * 1024 * 1024 + 1);
    await file.close();

    await expectLater(
      service.restoreBackupFromFile(
        path: path,
        password: 'secret',
        replaceExisting: true,
      ),
      throwsA(isA<FormatException>()),
    );
  });

}

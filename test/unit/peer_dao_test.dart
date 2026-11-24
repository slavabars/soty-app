import 'package:drift/drift.dart' show Value;
import 'package:dtm_app/core/storage/database.dart';
import 'package:dtm_app/core/storage/peer_dao.dart';
import 'package:dtm_app/models/peer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late PeerDao dao;

  setUp(() async {
    db = AppDatabase.inMemory();
    dao = PeerDao(db);
  });

  tearDown(() => db.close());

  DtmPeer peer(
    String key, {
    String name = '',
    String? ed,
    String? peerId,
    List<String> addrs = const [],
    DateTime? lastSeen,
    bool isContact = false,
  }) {
    return DtmPeer(
      pubKey: key,
      edPubKey: ed,
      displayName: name,
      peerId: peerId,
      addrs: addrs,
      lastSeen: lastSeen ?? DateTime.fromMillisecondsSinceEpoch(1000),
      isContact: isContact,
    );
  }

  test('upsert stores a peer and all() returns it', () async {
    await dao.upsert(
      peer(
        'a' * 64,
        name: 'Anna',
        ed: 'b' * 64,
        peerId: '12D3KooWAnna',
        addrs: const ['/ip4/10.0.2.2/tcp/5010'],
      ),
    );

    final all = await dao.all();
    expect(all, hasLength(1));
    expect(all.single.displayName, 'Anna');
    expect(all.single.edPubKey, 'b' * 64);
    expect(all.single.peerId, '12D3KooWAnna');
    expect(all.single.addrs, ['/ip4/10.0.2.2/tcp/5010']);
    expect(all.single.online, isFalse);
  });

  test('upsert replaces an existing row for the same key', () async {
    final key = 'a' * 64;
    await dao.upsert(peer(key, name: 'Old'));
    await dao.upsert(peer(key, name: 'New', ed: 'c' * 64));

    final all = await dao.all();
    expect(all, hasLength(1));
    expect(all.single.displayName, 'New');
    expect(all.single.edPubKey, 'c' * 64);
  });

  test('isContact defaults to false and round-trips through upsert',
      () async {
    final key = 'a' * 64;
    await dao.upsert(peer(key, name: 'Anna'));
    expect((await dao.find(key))?.isContact, isFalse);

    await dao.upsert(
      DtmPeer(
        pubKey: key,
        displayName: 'Anna',
        lastSeen: DateTime.fromMillisecondsSinceEpoch(1000),
        isContact: true,
      ),
    );
    expect((await dao.find(key))?.isContact, isTrue);

    await dao.upsert(peer(key, name: 'Anna', isContact: false));
    expect((await dao.find(key))?.isContact, isFalse);
  });

  test('find returns null for an unknown key', () async {
    expect(await dao.find('a' * 64), isNull);
    await dao.upsert(peer('a' * 64, name: 'Anna'));
    expect(await dao.find('a' * 64), isNotNull);
  });

  test('remove deletes only the addressed row', () async {
    await dao.upsert(peer('a' * 64, name: 'Anna'));
    await dao.upsert(peer('b' * 64, name: 'Bob'));
    await dao.remove('a' * 64);

    final all = await dao.all();
    expect(all, hasLength(1));
    expect(all.single.pubKey, 'b' * 64);
    await dao.remove('b' * 64);
    expect(await dao.all(), isEmpty);
    await dao.remove('b' * 64);
  });

  test('pruneTo evicts the least-recently-seen peers beyond the cap',
      () async {
    await dao.upsert(peer(
      'a' * 64,
      name: 'Oldest',
      lastSeen: DateTime.fromMillisecondsSinceEpoch(1000).toUtc(),
    ));
    await dao.upsert(peer(
      'b' * 64,
      name: 'Newest',
      lastSeen: DateTime.fromMillisecondsSinceEpoch(2000).toUtc(),
    ));

    await dao.pruneTo(1);

    final all = await dao.all();
    expect(all, hasLength(1));
    expect(all.single.pubKey, 'b' * 64);
    await dao.pruneTo(10);
    expect(await dao.all(), hasLength(1));
  });

test('malformed addrs JSON degrades to an empty list', () async {
    await dao.upsert(peer('a' * 64, name: 'Anna'));
    await (db.update(db.peers)).write(
      const PeersCompanion(addrsJson: Value('not json {')),
    );

    final all = await dao.all();
    expect(all.single.addrs, isEmpty);
  });

  test('markVerified stores the binding and survives a later upsert',
      () async {
    final key = 'a' * 64;
    final ed = 'b' * 64;
    await dao.upsert(peer(key, name: 'Anna', ed: ed));
    await dao.markVerified(key, ed);

    var stored = await dao.find(key);
    expect(stored!.verifiedEdPubKey, ed);
    expect(stored.verifiedAt, isNotNull);
    expect(stored.isVerified, isTrue);
    expect(stored.keyChanged, isFalse);

    await dao.upsert(peer(key, name: 'Anna Renamed', ed: ed));
    stored = await dao.find(key);
    expect(stored!.displayName, 'Anna Renamed');
    expect(stored.isVerified, isTrue);
  });

  test('a changed Ed25519 key stops counting as verified', () async {
    final key = 'a' * 64;
    await dao.upsert(peer(key, name: 'Anna', ed: 'b' * 64));
    await dao.markVerified(key, 'b' * 64);

    await dao.upsert(peer(key, name: 'Anna', ed: 'c' * 64));

    final stored = (await dao.find(key))!;
    expect(stored.edPubKey, 'c' * 64);
    expect(stored.verifiedEdPubKey, 'b' * 64);
    expect(stored.isVerified, isFalse);
    expect(stored.keyChanged, isTrue);
  });

  test('an unverified peer is neither verified nor changed', () async {
    await dao.upsert(peer('a' * 64, name: 'Anna', ed: 'b' * 64));
    final stored = (await dao.find('a' * 64))!;
    expect(stored.verifiedEdPubKey, isNull);
    expect(stored.isVerified, isFalse);
    expect(stored.keyChanged, isFalse);
  });

  test('markVerified rejects a malformed key or binding', () async {
    await dao.upsert(peer('a' * 64, name: 'Anna', ed: 'b' * 64));
    await expectLater(
      dao.markVerified('a' * 64, 'zz'),
      throwsFormatException,
    );
    await expectLater(
      dao.markVerified('nope', 'b' * 64),
      throwsFormatException,
    );
    expect((await dao.find('a' * 64))!.verifiedEdPubKey, isNull);
  });

  test('blocking is local, survives upserts and feeds the filter', () async {
    final key = 'a' * 64;
    await dao.upsert(peer(key, name: 'Anna', ed: 'b' * 64));

    await dao.setBlocked(key, true);
    expect(await dao.blockedPubKeys(), {key});
    expect(await dao.blockedEdKeys(), {'b' * 64});

    // An identify refresh must never clear the block.
    await dao.upsert(
      peer(key, name: 'Anna', ed: 'b' * 64, lastSeen: DateTime.now()),
    );
    expect(await dao.blockedPubKeys(), {key});
    expect(await dao.blockedEdKeys(), {'b' * 64});

    await dao.setBlocked(key, false);
    expect(await dao.blockedPubKeys(), isEmpty);
    expect(await dao.blockedEdKeys(), isEmpty);
  });

  test('setBlocked rejects a malformed key', () async {
    await expectLater(dao.setBlocked('nope', true), throwsFormatException);
  });
}

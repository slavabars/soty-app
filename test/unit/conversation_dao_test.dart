import 'package:drift/drift.dart' show Value;
import 'package:dtm_app/core/security_limits.dart';
import 'package:dtm_app/core/storage/conversation_dao.dart';
import 'package:dtm_app/core/storage/database.dart';
import 'package:dtm_app/core/storage/message_dao.dart';
import 'package:dtm_app/core/storage/peer_dao.dart';
import 'package:dtm_app/models/conversation.dart';
import 'package:dtm_app/models/peer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late ConversationDao dao;

  setUp(() async {
    db = AppDatabase.inMemory();
    dao = ConversationDao(db);
  });

  tearDown(() => db.close());

  Future<void> seedMessage({
    required String id,
    required String sender,
    required String recipient,
    required int ts,
    bool group = false,
    String? groupId,
  }) async {
    await db.into(db.messages).insert(
      MessagesCompanion.insert(
        id: id,
        senderPubKey: sender,
        recipientPubKey: recipient,
        timestamp: ts,
        ciphertext: 'c',
        ephemeralPubKey: 'e',
        signature: 's',
        source: 'seed',
        groupPayload: Value(group ? 1 : 0),
        groupId: Value(groupId),
      ),
    );
  }

  test('ensureOneOnOne creates a dm chat with exactly the peer as member',
      () async {
    await dao.ensureOneOnOne('a' * 64, ts: 11);

    final c = await dao.byId('a' * 64);
    expect(c, isNotNull);
    expect(c!.kind, ConversationKind.dm);
    expect(c.isGroup, isFalse);
    expect(c.memberKeys, ['a' * 64]);
    expect(c.createdTs, 11);
    expect(c.lastTs, 11);
  });

  test('ensureOneOnOne is idempotent and never resets lastTs', () async {
    await dao.ensureOneOnOne('a' * 64, ts: 11);
    await dao.ensureOneOnOne('a' * 64, ts: 5);

    final c = await dao.byId('a' * 64);
    expect(c!.lastTs, 11);
  });

  test('createGroup stores roster incl. self, sorted and deduped', () async {
    final roster = ['b' * 64, 'a' * 64, 'c' * 64, 'b' * 64];
    await dao.createGroup(
      id: 'g' * 64,
      title: 'Trip',
      memberKeys: roster,
      ts: 42,
    );

    final c = await dao.byId('g' * 64);
    expect(c, isNotNull);
    expect(c!.isGroup, isTrue);
    expect(c.title, 'Trip');
    expect(c.memberKeys, ['a' * 64, 'b' * 64, 'c' * 64]);
    expect(c.createdTs, 42);
    expect(c.lastTs, 42);
  });

  test('createGroup rejects a roster with a non-hex member', () async {
    await expectLater(
      dao.createGroup(
        id: 'g' * 64,
        title: 'X',
        memberKeys: ['a' * 64, 'self'],
        ts: 1,
      ),
      throwsArgumentError,
    );
    expect(await dao.byId('g' * 64), isNull);
  });

  test('createGroup stops at maxGroupCount instead of growing forever',
      () async {
    for (var i = 0; i < maxGroupCount; i++) {
      await dao.createGroup(
        id: i.toRadixString(16).padLeft(64, '0'),
        title: 'g$i',
        memberKeys: ['a' * 64],
        ts: i,
      );
    }
    await expectLater(
      dao.createGroup(
        id: 'f' * 64,
        title: 'one too many',
        memberKeys: ['a' * 64],
        ts: 99,
      ),
      throwsArgumentError,
    );
  });

  test('createGroup rejects a roster over maxGroupMembers', () async {
    final tooMany = List<String>.generate(maxGroupMembers + 1, (i) => '$i');
    await expectLater(
      dao.createGroup(
        id: 'g' * 64,
        title: 'X',
        memberKeys: tooMany,
        ts: 1,
      ),
      throwsArgumentError,
    );
  });

  test('rename stores the title; overlong titles are rejected', () async {
    await dao.ensureOneOnOne('a' * 64, ts: 1);
    await dao.rename('a' * 64, 'Renamed');

    final c = await dao.byId('a' * 64);
    expect(c!.title, 'Renamed');
    expect(c.kind, ConversationKind.dm);

    await expectLater(
      dao.rename('a' * 64, 'x' * (maxGroupTitleLength + 1)),
      throwsArgumentError,
    );
  });

  test('setLastTs and all() order by lastTs descending', () async {
    await dao.ensureOneOnOne('a' * 64, ts: 1);
    await dao.ensureOneOnOne('b' * 64, ts: 2);
    await dao.setLastTs('a' * 64, 99);

    final all = await dao.all(myXPubKey: 'x' * 64, myEdPubKey: 'e' * 64);
    expect(all.map((c) => c.id), ['a' * 64, 'b' * 64]);
  });

  test('byId returns null for unknown ids', () async {
    expect(await dao.byId('a' * 64), isNull);
  });

  group('unread counts', () {
    // Real hex keys: a group roster is validated as 32-byte hex.
    final myX = 'a' * 64;
    final myEd = 'e' * 64;
    final peerX = 'b' * 64;
    final peerEd = 'f' * 64;

    test('counts inbound dm messages newer than readAt, outgoing excluded',
        () async {
      await dao.ensureOneOnOne(peerX, ts: 1);
      await PeerDao(db).upsert(
        DtmPeer(pubKey: peerX, edPubKey: peerEd, lastSeen: DateTime.now()),
      );
      await seedMessage(
        id: '1' * 64,
        sender: peerEd,
        recipient: myX,
        ts: 10,
      );
      await seedMessage(
        id: '2' * 64,
        sender: peerEd,
        recipient: myX,
        ts: 20,
      );
      await seedMessage(
        id: '3' * 64,
        sender: myEd,
        recipient: peerX,
        ts: 30,
      );
      await seedMessage(
        id: '4' * 64,
        sender: peerEd,
        recipient: 'z' * 64,
        ts: 40,
      );

      final counts = await dao.unreadCounts(
        myXPubKey: myX,
        myEdPubKey: myEd,
      );
      expect(counts[peerX], 2);

      await dao.markRead(peerX, 20);
      expect(
        (await dao.unreadCounts(myXPubKey: myX, myEdPubKey: myEd))[peerX],
        0,
      );
      await dao.markRead(peerX, 25);
      expect(
        (await dao.unreadCounts(myXPubKey: myX, myEdPubKey: myEd))[peerX],
        0,
      );
    });

    test('an inbound addressed to the X key also counts', () async {
      await dao.ensureOneOnOne(peerX, ts: 1);
      await seedMessage(
        id: '5' * 64,
        sender: peerX,
        recipient: myX,
        ts: 10,
      );
      final counts = await dao.unreadCounts(
        myXPubKey: myX,
        myEdPubKey: myEd,
      );
      expect(counts[peerX], 1);
    });

    test('a control message never counts as unread', () async {
      await dao.ensureOneOnOne(peerX, ts: 1);
      await seedMessage(
        id: '9' * 64,
        sender: peerX,
        recipient: myX,
        ts: 10,
      );
      await seedMessage(
        id: 'f' * 64,
        sender: peerX,
        recipient: myX,
        ts: 20,
      );
      await MessageDao(db).markControl('f' * 64);

      final counts = await dao.unreadCounts(
        myXPubKey: myX,
        myEdPubKey: myEd,
      );
      expect(counts[peerX], 1);
    });

    test('group unread counts only the members', () async {
      await dao.createGroup(
        id: 'g' * 64,
        memberKeys: [myX, peerX, 'c' * 64],
        title: 'Group',
        ts: 1,
      );
      await PeerDao(db).upsert(
        DtmPeer(pubKey: peerX, edPubKey: peerEd, lastSeen: DateTime.now()),
      );
      await seedMessage(
        id: '6' * 64,
        sender: peerEd,
        recipient: myX,
        ts: 10,
        group: true,
        groupId: 'g' * 64,
      );
      await seedMessage(
        id: '7' * 64,
        sender: 'd' * 64,
        recipient: myX,
        ts: 11,
        group: true,
        groupId: 'g' * 64,
      );

      final counts = await dao.unreadCounts(
        myXPubKey: myX,
        myEdPubKey: myEd,
      );
      expect(counts['g' * 64], 1);
    });

    test('a copy attributed to another group is not counted here', () async {
      await dao.createGroup(
        id: 'g' * 64,
        memberKeys: [myX, peerX],
        title: 'One',
        ts: 1,
      );
      await dao.createGroup(
        id: 'h' * 64,
        memberKeys: [myX, peerX],
        title: 'Two',
        ts: 1,
      );
      await PeerDao(db).upsert(
        DtmPeer(pubKey: peerX, edPubKey: peerEd, lastSeen: DateTime.now()),
      );
      await seedMessage(
        id: '9' * 64,
        sender: peerEd,
        recipient: myX,
        ts: 10,
        group: true,
        groupId: 'h' * 64,
      );

      final counts = await dao.unreadCounts(
        myXPubKey: myX,
        myEdPubKey: myEd,
      );
      expect(counts['h' * 64], 1);
      expect(counts['g' * 64], 0);
    });

    test('a direct message from a member never counts against the group',
        () async {
      await dao.createGroup(
        id: 'g' * 64,
        memberKeys: [myX, peerX],
        title: 'Group',
        ts: 1,
      );
      await PeerDao(db).upsert(
        DtmPeer(pubKey: peerX, edPubKey: peerEd, lastSeen: DateTime.now()),
      );
      await seedMessage(
        id: '6' * 64,
        sender: peerEd,
        recipient: myX,
        ts: 10,
      );

      final counts = await dao.unreadCounts(
        myXPubKey: myX,
        myEdPubKey: myEd,
      );
      expect(counts['g' * 64], 0, reason: 'a plain DM is not a group copy');
    });

    test('a group copy never counts against the sender 1:1 chat', () async {
      await dao.ensureOneOnOne(peerX, ts: 1);
      await dao.createGroup(
        id: 'g' * 64,
        memberKeys: [myX, peerX],
        title: 'Group',
        ts: 1,
      );
      await PeerDao(db).upsert(
        DtmPeer(pubKey: peerX, edPubKey: peerEd, lastSeen: DateTime.now()),
      );
      await seedMessage(
        id: '6' * 64,
        sender: peerEd,
        recipient: myX,
        ts: 10,
      );
      await seedMessage(
        id: 'a' * 64,
        sender: peerEd,
        recipient: myX,
        ts: 20,
        group: true,
        groupId: 'g' * 64,
      );

      final counts = await dao.unreadCounts(
        myXPubKey: myX,
        myEdPubKey: myEd,
      );
      expect(counts[peerX], 1, reason: 'only the direct message is a DM');
      expect(counts['g' * 64], 1, reason: 'the group copy stays in the group');
    });

    test('a chat with nothing new reports zero', () async {
      await dao.ensureOneOnOne(peerX, ts: 1);
      final counts = await dao.unreadCounts(
        myXPubKey: myX,
        myEdPubKey: myEd,
      );
      expect(counts[peerX], 0);
    });

    test('all() carries the unread count per conversation', () async {
      await dao.ensureOneOnOne(peerX, ts: 1);
      await seedMessage(
        id: '8' * 64,
        sender: peerX,
        recipient: myX,
        ts: 10,
      );
      final views = await dao.all(myXPubKey: myX, myEdPubKey: myEd);
      expect(views.single.unreadCount, 1);
    });
  });

  test(
      'backfillOneOnOne materializes dm chats from existing threads, '
      'folding a known peer ed key into its X address and taking max ts',
      () async {
    // Real hex keys: a group roster is validated as 32-byte hex.
    final myX = 'a' * 64;
    final myEd = 'e' * 64;
    final peerX = 'b' * 64;
    final peerEd = 'f' * 64;

    await PeerDao(db).upsert(
      DtmPeer(
        pubKey: peerX,
        edPubKey: peerEd,
        displayName: 'Peer',
        lastSeen: DateTime.fromMillisecondsSinceEpoch(1),
      ),
    );
    await seedMessage(
      id: '1' * 64,
      sender: myEd,
      recipient: peerX,
      ts: 10,
    );
    await seedMessage(
      id: '2' * 64,
      sender: peerEd,
      recipient: myX,
      ts: 50,
    );

    await dao.backfillOneOnOne(myXPubKey: myX, myEdPubKey: myEd);

    final all = await dao.all(myXPubKey: myX, myEdPubKey: myEd);
    expect(all, hasLength(1));
    expect(all.single.id, peerX);
    expect(all.single.kind, ConversationKind.dm);
    expect(all.single.memberKeys, [peerX]);
    expect(all.single.lastTs, 50);
  });

  test('backfillOneOnOne keeps an unknown sender as its own conversation id',
      () async {
    final myX = 'x' * 64;
    final myEd = 'e' * 64;
    final stranger = 'z' * 64;

    await seedMessage(
      id: '3' * 64,
      sender: stranger,
      recipient: myX,
      ts: 7,
    );

    await dao.backfillOneOnOne(myXPubKey: myX, myEdPubKey: myEd);

    final all = await dao.all(myXPubKey: myX, myEdPubKey: myEd);
    expect(all, hasLength(1));
    expect(all.single.id, stranger);
  });

  test(
      'backfillOneOnOne folds a learned-Ed legacy DM into its X chat',
      () async {
    // Real hex keys: a group roster is validated as 32-byte hex.
    final myX = 'a' * 64;
    final myEd = 'e' * 64;
    final peerX = 'b' * 64;
    final peerEd = 'f' * 64;

    await seedMessage(
      id: '4' * 64,
      sender: peerEd,
      recipient: myX,
      ts: 50,
    );
    await dao.ensureOneOnOne(peerEd, ts: 99);
    await dao.rename(peerEd, 'Legacy title');

    await dao.backfillOneOnOne(
      myXPubKey: myX,
      myEdPubKey: myEd,
      learnedEdToX: {peerEd: peerX},
    );

    final all = await dao.all(myXPubKey: myX, myEdPubKey: myEd);
    expect(all, hasLength(1));
    expect(all.single.id, peerX);
    expect(all.single.lastTs, 99);
    expect(all.single.title, 'Legacy title');
  });
}
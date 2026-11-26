import 'dart:convert';

import 'package:dtm_app/core/crypto/envelope_crypto.dart';
import 'package:dtm_app/core/crypto/keypair.dart';
import 'package:dtm_app/core/security_limits.dart'
    show maxGroupMembers, maxPlaintextBytes;
import 'package:dtm_app/core/storage/conversation_dao.dart';
import 'package:dtm_app/core/storage/database.dart';
import 'package:dtm_app/core/storage/message_dao.dart';
import 'package:dtm_app/core/storage/peer_dao.dart';
import 'package:dtm_app/core/storage/pruned_roots_dao.dart';
import 'package:dtm_app/core/sync/envelope_processor.dart';
import 'package:dtm_app/core/transport/transport.dart';
import 'package:dtm_app/features/messenger/messenger_controller.dart';
import 'package:dtm_app/models/group_payload.dart' show GroupContainerKind;
import 'package:dtm_app/models/message_payload.dart';
import 'package:dtm_app/models/peer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late MessageDao dao;
  late ConversationDao conversationDao;
  late EnvelopeProcessor processor;
  late MessengerController controller;
  late DtmKeyPair alice;
  late DtmKeyPair bob;
  late String aliceX;
  late String bobX;

  setUp(() async {
    db = AppDatabase.inMemory();
    dao = MessageDao(db);
    conversationDao = ConversationDao(db);
    final identity = await DtmKeyPair.generate();
    processor = EnvelopeProcessor(identity: identity, dao: dao);
    controller = MessengerController(
      processor: processor,
      dao: dao,
      peerDao: PeerDao(db),
      conversationDao: conversationDao,
      prunedRootsDao: PrunedRootsDao(db),
      identity: identity,
      transports: const <Transport>[],
      storeOutgoing: () => true,
    );
    await controller.init();
    controller.startListening();
    alice = await DtmKeyPair.generate();
    bob = await DtmKeyPair.generate();
    aliceX = await alice.x25519PublicKeyHex;
    bobX = await bob.x25519PublicKeyHex;
    for (final (keypair, name) in [(alice, 'Alice'), (bob, 'Bob')]) {
      await controller.importPeer(
        DtmPeer(
          pubKey: await keypair.x25519PublicKeyHex,
          edPubKey: await keypair.ed25519PublicKeyHex,
          displayName: name,
          lastSeen: DateTime.now(),
        ),
      );
    }
  });

  tearDown(() async {
    await controller.dispose();
    await processor.dispose();
    await db.close();
  });

  Future<void> deliver(
    DtmKeyPair sender,
    String plaintext, {
    int? timestamp,
  }) async {
    final envelope = await createEnvelopeForPubKey(
      sender: sender,
      recipientX25519PubKeyHex: controller.myXPubKey,
      plaintext: plaintext,
      timestamp: timestamp,
    );
    await processor.process(envelope, source: TransportSource.mesh, hops: 0);
    for (var i = 0; i < 100; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  Future<String> createdGroup() async {
    final id = await controller.createGroup(
      title: 'Team',
      memberPeerKeys: [aliceX],
      ts: 1,
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));
    return id;
  }

  test('the creator is admin and can change the roster', () async {
    final id = await createdGroup();
    expect(await controller.isGroupAdmin(id), isTrue);
    expect(await controller.addGroupMember(id, bobX), isTrue);

    final members = await controller.groupMembers(id);
    expect(
      {for (final m in members) m.key: m.role},
      {
        controller.myXPubKey: ConversationDao.adminRole,
        aliceX: ConversationDao.memberRole,
        bobX: ConversationDao.memberRole,
      },
    );

    expect(await controller.removeGroupMember(id, bobX), isTrue);
    expect(
      (await controller.groupMembers(id)).map((m) => m.key),
      isNot(contains(bobX)),
    );
  });

  test('a member is not allowed to change the roster or the title', () async {
    final id = await createdGroup();
    await conversationDao.setRole(id, aliceX, ConversationDao.adminRole);
    await conversationDao.setRole(
      id,
      controller.myXPubKey,
      ConversationDao.memberRole,
    );
    controller.invalidateSearchIndex();

    expect(await controller.isGroupAdmin(id), isFalse);
    expect(await controller.addGroupMember(id, bobX), isFalse);
    expect(await controller.removeGroupMember(id, aliceX), isFalse);
    expect(await controller.setGroupMemberRole(id, aliceX, 'member'), isFalse);

    await controller.renameConversation(id, 'Hacked');
    expect(controller.chatTitle(id), 'Team');
  });

  test('membership changes are broadcast as roster syncs to everyone',
      () async {
    final id = await createdGroup();
    await controller.addGroupMember(id, bobX);

    final groupRows = await dao.messagesForGroup(
      myXPubKey: controller.myXPubKey,
      myEdPubKey: controller.myEdPubKey,
      memberXKeys: [controller.myXPubKey, aliceX, bobX],
      memberEdKeys: [
        controller.myEdPubKey,
        await alice.ed25519PublicKeyHex,
        await bob.ed25519PublicKeyHex,
      ],
    );
    var frames = 0;
    for (final envelope in groupRows) {
      final body = await dao.bodyFor(envelope.id);
      if (body == null) continue;
      final payload = MessagePayload.parse(body);
      if (payload is GroupMessagePayload &&
          payload.kind == GroupContainerKind.roster &&
          payload.rosterAction == 'a') {
        frames++;
      }
    }
    // One sync per recipient: Alice and Bob learn about the new member.
    expect(frames, 2);
  });

  test('an admin roster sync creates the group and a system line', () async {
    final id = 'ab' * 32;
    await deliver(
      alice,
      MessagePayload.composeGroupRoster(
        conversationId: id,
        senderX: aliceX,
        action: 'c',
        targetKey: '',
        roster: [aliceX, controller.myXPubKey],
      ),
    );

    expect(controller.isGroup(id), isTrue);
    expect(await controller.isGroupAdmin(id), isFalse);
    final members = await controller.groupMembers(id);
    expect(
      members.firstWhere((m) => m.key == aliceX).role,
      ConversationDao.adminRole,
    );

    // The creation sync seeds the roster silently; a later add is a visible
    // system line.
    await deliver(
      alice,
      MessagePayload.composeGroupRoster(
        conversationId: id,
        senderX: aliceX,
        action: 'a',
        targetKey: bobX,
        roster: [aliceX, controller.myXPubKey, bobX],
      ),
    );
    final messages = await controller.messagesFor(id);
    final system = messages.where((m) => m.isSystem).toList();
    expect(system, hasLength(1));
    expect(system.single.systemAction, 'a');
    expect(system.single.systemTarget, bobX);
  });

  test('a member shared by two groups does not pollute the other unread',
      () async {
    final first = '12' * 32;
    final second = '34' * 32;
    for (final id in [first, second]) {
      await deliver(
        alice,
        MessagePayload.composeGroupRoster(
          conversationId: id,
          senderX: aliceX,
          action: 'c',
          targetKey: '',
          roster: [aliceX, controller.myXPubKey],
        ),
      );
    }
    await deliver(
      alice,
      MessagePayload.composeGroupMessage(
        conversationId: first,
        corrId: '56' * 32,
        senderX: aliceX,
        text: 'only in the first',
      ),
    );

    expect(await controller.unreadCountFor(first), 1);
    expect(await controller.unreadCountFor(second), 0);
  });

  test('the creation sync does not count as an unread message', () async {
    final id = 'ef' * 32;
    await deliver(
      alice,
      MessagePayload.composeGroupRoster(
        conversationId: id,
        senderX: aliceX,
        action: 'c',
        targetKey: '',
        roster: [aliceX, controller.myXPubKey],
      ),
    );
    expect(await controller.unreadCountFor(id), 0);
    expect(await controller.messagesFor(id), isEmpty);
  });

  test('a non-admin roster sync and a removed member message are dropped',
      () async {
    final id = 'cd' * 32;
    await deliver(
      alice,
      MessagePayload.composeGroupRoster(
        conversationId: id,
        senderX: aliceX,
        action: 'c',
        targetKey: '',
        roster: [aliceX, controller.myXPubKey, bobX],
      ),
    );
    expect(await controller.addGroupMember(id, bobX), isFalse); // not admin

    // Bob, a plain member, tries to add himself as admin: ignored.
    await deliver(
      bob,
      MessagePayload.composeGroupRoster(
        conversationId: id,
        senderX: bobX,
        action: 'p',
        targetKey: bobX,
        roster: [aliceX, controller.myXPubKey, bobX],
      ),
    );
    expect(await controller.isGroupAdmin(id), isFalse);
    final members = await controller.groupMembers(id);
    expect(
      members.firstWhere((m) => m.key == bobX).role,
      ConversationDao.memberRole,
    );

    // A normal message from Bob is accepted while he is a member...
    await deliver(
      bob,
      MessagePayload.composeGroupMessage(
        conversationId: id,
        corrId: '11' * 32,
        senderX: bobX,
        text: 'hello group',
      ),
    );
    expect(
      (await controller.messagesFor(id)).map((m) => m.body),
      contains('hello group'),
    );

    // ...and dropped after Alice removes him.
    await deliver(
      alice,
      MessagePayload.composeGroupRoster(
        conversationId: id,
        senderX: aliceX,
        action: 'r',
        targetKey: bobX,
        roster: [aliceX, controller.myXPubKey],
      ),
    );
    await deliver(
      bob,
      MessagePayload.composeGroupMessage(
        conversationId: id,
        corrId: '22' * 32,
        senderX: bobX,
        text: 'still here?',
      ),
    );
    expect(
      (await controller.messagesFor(id)).map((m) => m.body),
      isNot(contains('still here?')),
    );
  });
  test('the maximum roster fits one plaintext envelope', () {
    final keys = [
      for (var i = 0; i < maxGroupMembers; i++)
        i.toRadixString(16).padLeft(64, '0'),
    ];
    final raw = MessagePayload.composeGroupRoster(
      conversationId: 'a' * 64,
      senderX: 'b' * 64,
      action: 'a',
      targetKey: 'c' * 64,
      roster: keys,
    );
    expect(utf8.encode(raw).length, lessThanOrEqualTo(maxPlaintextBytes));
  });

}

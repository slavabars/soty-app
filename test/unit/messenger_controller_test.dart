import 'dart:async';
import 'dart:convert' show base64Encode;
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart' as crypto;
import 'package:drift/drift.dart' show Value;
import 'package:dtm_app/core/crypto/envelope_crypto.dart';
import 'package:dtm_app/core/crypto/identity_claim.dart';
import 'package:dtm_app/core/crypto/keypair.dart';
import 'package:dtm_app/core/invite_link.dart';
import 'package:dtm_app/core/media/chunked_transfer.dart';
import 'package:dtm_app/core/media/media_store.dart';
import 'package:dtm_app/core/security_limits.dart'
    show
        autoDownloadBytes,
        maxMediaBlobBytes,
        maxOutstandingChunkRequests,
        senderPushBytes,
        transferChunkBytes;
import 'package:dtm_app/core/storage/conversation_dao.dart';
import 'package:dtm_app/core/storage/database.dart';
import 'package:dtm_app/core/storage/message_dao.dart';
import 'package:dtm_app/core/storage/peer_dao.dart';
import 'package:dtm_app/core/storage/pruned_roots_dao.dart';
import 'package:dtm_app/core/sync/envelope_processor.dart';
import 'package:dtm_app/core/transport/transport.dart';
import 'package:dtm_app/features/messenger/messenger_controller.dart';
import 'package:dtm_app/models/envelope.dart';
import 'package:dtm_app/models/group_payload.dart';
import 'package:dtm_app/models/message_payload.dart';
import 'package:dtm_app/models/message_status.dart';
import 'package:dtm_app/models/peer.dart';
import 'package:flutter_test/flutter_test.dart';

class SpyTransport implements Transport, PeerImportable {
  SpyTransport([this.label = 'spy']);

  final String label;
  final _peers = StreamController<DtmPeer>.broadcast();
  final List<Envelope> sent = [];
  final Map<String, bool> directOnly = {};
  final List<DtmPeer> imported = [];
  bool running = false;

  @override
  String get name => label;

  @override
  bool get isRunning => running;

  @override
  Stream<DtmPeer> get peers => _peers.stream;

  @override
  void setEnvelopeSink(EnvelopeSink sink) {}

  @override
  Future<void> start({
    required String myEdPubKey,
    required String myXPubKey,
    required String displayName,
  }) async {
    running = true;
  }

  @override
  Future<void> stop() async {
    running = false;
  }

  @override
  Future<bool> send(Envelope envelope, {bool directOnly = false}) async {
    sent.add(envelope);
    this.directOnly[envelope.id] = directOnly;
    return true;
  }

  @override
  void importPeer(DtmPeer peer) => imported.add(peer);

  void emit(DtmPeer peer) => _peers.add(peer);

  Future<void> dispose() async {
    await _peers.close();
  }
}

void main() {
  late AppDatabase db;
  late MessageDao dao;
  late ConversationDao conversationDao;
  late PrunedRootsDao rootsDao;
  late DtmKeyPair identity;
  late EnvelopeProcessor processor;
  late SpyTransport transport;
  late MessengerController controller;
  late String myXPubKey;
  late String myEdPubKey;
  late bool receiptsEnabled;
  late Directory mediaDir;

  setUp(() async {
    mediaDir = await Directory.systemTemp.createTemp('soty_controller_media');
    MediaStore.overrideRoot = mediaDir;
    db = AppDatabase.inMemory();
    dao = MessageDao(db);
    conversationDao = ConversationDao(db);
    rootsDao = PrunedRootsDao(db);
    identity = await DtmKeyPair.generate();
    processor = EnvelopeProcessor(identity: identity, dao: dao);
    transport = SpyTransport();
    receiptsEnabled = true;
    controller = MessengerController(
      processor: processor,
      dao: dao,
      peerDao: PeerDao(db),
      conversationDao: conversationDao,
      prunedRootsDao: rootsDao,
      identity: identity,
      transports: [transport],
      storeOutgoing: () => false,
      readReceipts: () => receiptsEnabled,
    );
    await controller.init();
    myXPubKey = controller.myXPubKey;
    myEdPubKey = controller.myEdPubKey;
  });

  tearDown(() async {
    await controller.dispose();
    await processor.dispose();
    await transport.dispose();
    await db.close();
    MediaStore.overrideRoot = null;
    await mediaDir.delete(recursive: true);
  });

  String mediaBytes(int len) =>
      base64Encode(List<int>.filled(len, 0x41));

  Future<DtmKeyPair> importRemote(String name) async {
    final remote = await DtmKeyPair.generate();
    final imported = await controller.importPeer(
      DtmPeer(
        pubKey: await remote.x25519PublicKeyHex,
        edPubKey: await remote.ed25519PublicKeyHex,
        displayName: name,
        lastSeen: DateTime.now(),
      ),
    );
    expect(imported, isTrue);
    return remote;
  }

  Future<DtmKeyPair> importRemoteWith(
    MessengerController into,
    String name,
  ) async {
    final remote = await DtmKeyPair.generate();
    final imported = await into.importPeer(
      DtmPeer(
        pubKey: await remote.x25519PublicKeyHex,
        edPubKey: await remote.ed25519PublicKeyHex,
        displayName: name,
        lastSeen: DateTime.now(),
      ),
    );
    expect(imported, isTrue);
    return remote;
  }

  Future<String> decryptFor(
    Envelope envelope, {
    crypto.SimpleKeyPair? recipientX25519KeyPair,
  }) async {
    final plaintext = await decryptPayload(
      envelope: envelope,
      recipientX25519KeyPair: recipientX25519KeyPair ?? identity.xKeyPair,
      senderEd25519PubKeyHex: envelope.senderPubKey,
    );
    return plaintext!;
  }

  /// Polls until [predicate] holds or a short deadline passes, letting the
  /// controller's unawaited inbound listener finish before assertions.
  Future<void> waitUntil(bool Function() predicate) async {
    final deadline = DateTime.now().add(const Duration(seconds: 3));
    while (!predicate() && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
  }

  test('init exposes this device public keys', () async {
    expect(myXPubKey, await identity.x25519PublicKeyHex);
    expect(myEdPubKey, await identity.ed25519PublicKeyHex);
  });

  test('events and notifications after dispose are dropped, not thrown',
      () async {
    controller.startListening();
    await controller.dispose();
    final remote = await DtmKeyPair.generate();
    final peer = DtmPeer(
      pubKey: await remote.x25519PublicKeyHex,
      edPubKey: await remote.ed25519PublicKeyHex,
      displayName: 'late arrival',
      lastSeen: DateTime.now(),
    );
    transport.emit(peer);
    await expectLater(controller.importPeer(peer), completes);
    await Future<void>.delayed(const Duration(milliseconds: 5));
  });

  test('importPeer rejects malformed keys and forwards valid ones', () async {
    expect(
      await controller.importPeer(
        DtmPeer(pubKey: 'nope', lastSeen: DateTime.now()),
      ),
      isFalse,
    );
    expect(controller.peers, isEmpty);

    final remote = await importRemote('Remote');
    expect(controller.peers, hasLength(1));
    expect(transport.imported, hasLength(1));
    expect(transport.imported.single.displayName, 'Remote');
    expect(
      controller.peers[await remote.x25519PublicKeyHex]!.displayName,
      'Remote',
    );
  });

  test('init re-imports persisted peers into transports', () async {
    final saved = await DtmKeyPair.generate();
    final savedTransport = SpyTransport();
    final first = MessengerController(
      processor: processor,
      dao: dao,
      peerDao: PeerDao(db),
      conversationDao: ConversationDao(db),
      prunedRootsDao: rootsDao,
      identity: identity,
      transports: [savedTransport],
      storeOutgoing: () => false,
    );
    await first.init();
    final savedPeer = DtmPeer(
      pubKey: await saved.x25519PublicKeyHex,
      edPubKey: await saved.ed25519PublicKeyHex,
      displayName: 'Persisted',
      peerId: '12D3KooWABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghij',
      addrs: const ['/ip4/10.0.2.2/tcp/5010'],
      lastSeen: DateTime.now(),
    );
    await first.importPeer(savedPeer);
    expect(savedTransport.imported, hasLength(1));
    await first.dispose();
    await savedTransport.dispose();

    final freshTransport = SpyTransport();
    final restarted = MessengerController(
      processor: processor,
      dao: dao,
      peerDao: PeerDao(db),
      conversationDao: ConversationDao(db),
      prunedRootsDao: rootsDao,
      identity: identity,
      transports: [freshTransport],
      storeOutgoing: () => false,
    );
    await restarted.init();
    expect(
      freshTransport.imported.map((p) => p.pubKey),
      contains(savedPeer.pubKey),
    );
    await restarted.dispose();
    await freshTransport.dispose();
  });

  test('importInvite accepts a signed claim and rejects tampering', () async {
    final remote = await DtmKeyPair.generate();
    final claim = await IdentityClaim.forIdentity(
      identity: remote,
      displayName: 'Carol',
    );
    expect(await controller.importInvite(claim.encode()), isTrue);

    final stored = controller.peers[await remote.x25519PublicKeyHex];
    expect(stored, isNotNull);
    expect(stored!.edPubKey, await remote.ed25519PublicKeyHex);

    final tampered = claim.toJson()..['displayName'] = 'Mallory';
    expect(await controller.importInvite(claim.encode()), isTrue);
    expect(
      await controller.importInvite(IdentityClaim.fromJson(tampered).encode()),
      isFalse,
    );
    expect(await controller.importInvite('not json'), isFalse);
  });

  test('importInvite accepts a claim inside a shareable deep link', () async {
    final remote = await DtmKeyPair.generate();
    final claim = await IdentityClaim.forIdentity(
      identity: remote,
      displayName: 'Delia',
    );
    final link = InviteLink.encode(claim.encode());
    final json = InviteLink.claimFromRoute(link)!;
    expect(await controller.importInvite(json), isTrue);
    expect(controller.peers.containsKey(claim.xPubKey), isTrue);

    final tamperedLink = InviteLink.encode(
      IdentityClaim.fromJson(claim.toJson()..['displayName'] = 'Mallory')
          .encode(),
    );
    expect(
      await controller.importInvite(InviteLink.claimFromRoute(tamperedLink)!),
      isFalse,
    );
  });

  group('conversations', () {
    test('sending stores an outgoing message with its plaintext', () async {
      final remote = await importRemote('Remote');
      final remoteX = await remote.x25519PublicKeyHex;

      await controller.sendText(recipientPubKey: remoteX, plaintext: 'hi you');

      final messages = await controller.messagesFor(remoteX);
      expect(messages, hasLength(1));
      expect(messages.single.outgoing, isTrue);
      expect(messages.single.body, 'hi you');
    });

    test('inbound messages are scoped to their sender', () async {
      final remoteA = await importRemote('A');
      final remoteB = await importRemote('B');
      final aX = await remoteA.x25519PublicKeyHex;
      final bX = await remoteB.x25519PublicKeyHex;

      final fromA = await createEnvelopeForPubKey(
        sender: remoteA,
        recipientX25519PubKeyHex: myXPubKey,
        plaintext: 'from A',
      );
      await processor.process(fromA, source: TransportSource.mesh, hops: 0);

      final fromB = await createEnvelopeForPubKey(
        sender: remoteB,
        recipientX25519PubKeyHex: myXPubKey,
        plaintext: 'from B',
      );
      await processor.process(fromB, source: TransportSource.mesh, hops: 0);

      final aMessages = await controller.messagesFor(aX);
      expect(aMessages, hasLength(1));
      expect(aMessages.single.body, 'from A');
      expect(aMessages.single.outgoing, isFalse);

      final bMessages = await controller.messagesFor(bX);
      expect(bMessages, hasLength(1));
      expect(bMessages.single.body, 'from B');
    });

    test(
      'inbound Ed25519 keys fold into the peer X25519 conversation',
      () async {
        final remote = await importRemote('Remote');
        final remoteX = await remote.x25519PublicKeyHex;

        final inbound = await createEnvelopeForPubKey(
          sender: remote,
          recipientX25519PubKeyHex: myXPubKey,
          plaintext: 'hey',
        );
        await processor.process(inbound, source: TransportSource.mesh, hops: 0);

        expect(await controller.conversations(), [remoteX]);
      },
    );

    test('an unknown sender key is reported as its own conversation', () async {
      final sender = await DtmKeyPair.generate();
      final inbound = await createEnvelopeForPubKey(
        sender: sender,
        recipientX25519PubKeyHex: myXPubKey,
        plaintext: 'stranger',
      );
      await processor.process(inbound, source: TransportSource.mesh, hops: 0);

      expect(await controller.conversations(), [
        await sender.ed25519PublicKeyHex,
      ]);
    });

    test('storeOutgoing reloads own dm plaintext after a restart', () async {
      final sending = MessengerController(
        processor: processor,
        dao: dao,
        peerDao: PeerDao(db),
        conversationDao: conversationDao,
        prunedRootsDao: rootsDao,
        identity: identity,
        storeOutgoing: () => true,
      );
      addTearDown(sending.dispose);
      await sending.init();
      final remote = await importRemoteWith(sending, 'Remote');
      final remoteX = await remote.x25519PublicKeyHex;

      await sending.sendText(
        recipientPubKey: remoteX,
        plaintext: 'persisted body',
      );

      final restored = MessengerController(
        processor: processor,
        dao: dao,
        peerDao: PeerDao(db),
        conversationDao: conversationDao,
        prunedRootsDao: rootsDao,
        identity: identity,
        storeOutgoing: () => true,
      );
      addTearDown(restored.dispose);
      await restored.init();

      final single = (await restored.messagesFor(remoteX)).single;
      expect(single.outgoing, isTrue);
      expect(single.body, 'persisted body');
    });

    test('storeOutgoing off keeps own dm plaintext out of storage',
        () async {
      final remote = await importRemote('Remote');
      final remoteX = await remote.x25519PublicKeyHex;

      await controller.sendText(
        recipientPubKey: remoteX,
        plaintext: 'hush',
      );

      final envelope = (await dao.messagesFor(
        remoteX,
        myXPubKey: myXPubKey,
        myEdPubKey: myEdPubKey,
      )).single;
      expect(await dao.bodyFor(envelope.id), isNull);

      final restored = MessengerController(
        processor: processor,
        dao: dao,
        peerDao: PeerDao(db),
        conversationDao: conversationDao,
        prunedRootsDao: rootsDao,
        identity: identity,
        storeOutgoing: () => false,
      );
      addTearDown(restored.dispose);
      await restored.init();
      expect(
        (await restored.messagesFor(remoteX)).single.body,
        '🔒 Encrypted',
      );
    });

    test('storeOutgoing reloads group fan-out containers after a restart',
        () async {
      processor.registerTransport(transport);
      await transport.start(
        myEdPubKey: myEdPubKey,
        myXPubKey: myXPubKey,
        displayName: 'Self',
      );
      final sending = MessengerController(
        processor: processor,
        dao: dao,
        peerDao: PeerDao(db),
        conversationDao: conversationDao,
        prunedRootsDao: rootsDao,
        identity: identity,
        storeOutgoing: () => true,
      );
      addTearDown(sending.dispose);
      await sending.init();
      final a = await importRemoteWith(sending, 'Remote');
      final b = await importRemoteWith(sending, 'Remote');
      final aX = await a.x25519PublicKeyHex;
      final bX = await b.x25519PublicKeyHex;
      final id = await sending.createGroup(
        title: 'Crew',
        memberPeerKeys: [aX, bX],
        ts: 1,
      );

      await sending.sendGroupText(conversationId: id, text: 'fan-out');

      final restored = MessengerController(
        processor: processor,
        dao: dao,
        peerDao: PeerDao(db),
        conversationDao: conversationDao,
        prunedRootsDao: rootsDao,
        identity: identity,
        storeOutgoing: () => true,
      );
      addTearDown(restored.dispose);
      await restored.init();
      final bodies = (await restored.messagesFor(id)).map((m) => m.body);
      expect(bodies, everyElement('fan-out'));
    });
  });

  group('groups', () {
    test('createGroup stores a group conversation with the members', () async {
      final a = await importRemote('A');
      final aX = await a.x25519PublicKeyHex;

      final id = await controller.createGroup(
        title: 'Crew',
        memberPeerKeys: [aX],
        ts: 42,
      );

      expect(controller.isGroup(id), isTrue);
      final view = controller.conversationView(id)!;
      expect(view.title, 'Crew');
      expect(view.memberKeys, containsAll([myXPubKey, aX]));
    });

    test('sendGroupText fans out one envelope per active member, no dm',
        () async {
      processor.registerTransport(transport);
      await transport.start(
        myEdPubKey: myEdPubKey,
        myXPubKey: myXPubKey,
        displayName: 'Self',
      );
      final a = await importRemote('A');
      final b = await importRemote('B');
      final aX = await a.x25519PublicKeyHex;
      final bX = await b.x25519PublicKeyHex;
      final id = await controller.createGroup(
        title: 'Crew',
        memberPeerKeys: [aX, bX],
        ts: 1,
      );
      // Creating a group already broadcasts its roster; measure only the text
      // fan-out below.
      transport.sent.clear();

      await controller.sendGroupText(conversationId: id, text: 'all hands');

      expect(transport.sent, hasLength(2));
      final parsed = <String, GroupMessagePayload>{};
      for (final e in transport.sent) {
        final raw = await decryptFor(
          e,
          recipientX25519KeyPair: (e.recipientPubKey == aX ? a : b).xKeyPair,
        );
        final payload = MessagePayload.parse(raw);
        expect(payload, isA<GroupMessagePayload>());
        parsed[e.recipientPubKey] = payload as GroupMessagePayload;
      }
      expect(parsed.keys, containsAll([aX, bX]));
      for (final payload in parsed.values) {
        expect(payload.conversationId, id);
        expect(payload.senderX, myXPubKey);
        expect(payload.value, 'all hands');
        expect(payload.kind, GroupContainerKind.message);
      }
      expect(parsed[aX]!.corrId, parsed[bX]!.corrId);
      expect(parsed[aX]!.corrId, isNotEmpty);
      expect(controller.isGroup(id), isTrue);
      expect(controller.conversationList.single.title, 'Crew');
    });

    test('createGroup rejects an oversized roster', () async {
      final keys = [
        for (var i = 0; i < 600; i++) i.toString().padLeft(64, '0'),
      ];
      expect(
        () => controller.createGroup(
          title: 'Too big',
          memberPeerKeys: keys,
          ts: 1,
        ),
        throwsArgumentError,
      );
    });

    test('an inbound container from a known peer joins the group', () async {
      controller.startListening();
      final a = await importRemote('A');
      final id = 'a' * 64;
      final container =
          GroupPayload.composeMessage(conversationId: id, text: 'welcome');
      final inbound = await createEnvelopeForPubKey(
        sender: a,
        recipientX25519PubKeyHex: myXPubKey,
        plaintext: container,
      );
      await processor.process(inbound, source: TransportSource.mesh, hops: 0);
      await waitUntil(() => controller.isGroup(id));

      expect(controller.isGroup(id), isTrue);
      final view = controller.conversationView(id)!;
      expect(view.memberKeys, contains(await a.x25519PublicKeyHex));
      final messages = await controller.messagesFor(id);
      expect(messages.single.body, 'welcome');
      expect(messages.single.outgoing, isFalse);
    });

    test('an inbound container from an unknown peer does not join',
        () async {
      controller.startListening();
      final stranger = await DtmKeyPair.generate();
      final id = 'b' * 64;
      final container =
          GroupPayload.composeMessage(conversationId: id, text: 'hello?');
      final inbound = await createEnvelopeForPubKey(
        sender: stranger,
        recipientX25519PubKeyHex: myXPubKey,
        plaintext: container,
      );
      await processor.process(inbound, source: TransportSource.mesh, hops: 0);
      await waitUntil(() => controller.conversationList.isEmpty);

      expect(controller.isGroup(id), isFalse);
      expect(await controller.messagesFor(id), isEmpty);
    });

    test('only an admin title meta renames the group conversation', () async {
      controller.startListening();
      final a = await importRemote('A');
      final aX = await a.x25519PublicKeyHex;
      final id = await controller.createGroup(
        title: 'Old name',
        memberPeerKeys: [aX],
        ts: 1,
      );

      Future<void> sendTitle(String name) async {
        final inbound = await createEnvelopeForPubKey(
          sender: a,
          recipientX25519PubKeyHex: myXPubKey,
          plaintext: GroupPayload.composeTitle(
            conversationId: id,
            title: name,
          ),
        );
        await processor.process(inbound, source: TransportSource.mesh, hops: 0);
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }

      // A plain member cannot rename the group.
      await sendTitle('New name');
      expect(controller.conversationView(id)!.title, 'Old name');

      // After promotion the same meta is accepted.
      await conversationDao.setRole(id, aX, ConversationDao.adminRole);
      await sendTitle('New name');
      expect(controller.conversationView(id)!.title, 'New name');
      expect(await controller.messagesFor(id), isEmpty);
    });

    test('a non-member container never leaks into the group or a dm',
        () async {
      controller.startListening();
      final member = await importRemote('Member');
      final stranger = await importRemote('Stranger');
      final memberX = await member.x25519PublicKeyHex;
      final id = await controller.createGroup(
        title: 'Crew',
        memberPeerKeys: [memberX],
        ts: 1,
      );

      final container =
          GroupPayload.composeMessage(conversationId: id, text: 'prying');
      final hostile = await createEnvelopeForPubKey(
        sender: stranger,
        recipientX25519PubKeyHex: myXPubKey,
        plaintext: container,
      );
      await processor.process(hostile, source: TransportSource.mesh, hops: 0);
      await waitUntil(() => controller.conversationList.length == 1);

      expect(await controller.messagesFor(id), isEmpty);
      expect(controller.isGroup(id), isTrue);
      expect(
        controller.conversationView(id)!.memberKeys,
        containsAll([myXPubKey, memberX]),
      );
    });

    test('group members are excluded from the 1:1 backfill', () async {
      controller.startListening();
      final a = await importRemote('A');
      final aX = await a.x25519PublicKeyHex;
      final id = await controller.createGroup(
        title: 'Crew',
        memberPeerKeys: [aX],
        ts: 1,
      );
      final container =
          GroupPayload.composeMessage(conversationId: id, text: 'copy');
      final inbound = await createEnvelopeForPubKey(
        sender: a,
        recipientX25519PubKeyHex: myXPubKey,
        plaintext: container,
      );
      await processor.process(inbound, source: TransportSource.mesh, hops: 0);
      await waitUntil(
        () => controller.conversationList.any((c) => c.id == id),
      );

      final list = controller.conversationList;
      expect(list.map((c) => c.id), [id]);
      expect(list.map((c) => c.id), isNot(contains(aX)));
    });

    test('the first inbound container is kept and acknowledged', () async {
      controller.startListening();
      processor.registerTransport(transport);
      await transport.start(
        myEdPubKey: myEdPubKey,
        myXPubKey: myXPubKey,
        displayName: 'Self',
      );
      final a = await importRemote('A');
      final aX = await a.x25519PublicKeyHex;
      final id = 'd' * 64;

      final inbound = await createEnvelopeForPubKey(
        sender: a,
        recipientX25519PubKeyHex: myXPubKey,
        plaintext: GroupPayload.composeMessage(
          conversationId: id,
          text: 'первое',
        ),
      );
      await processor.process(inbound, source: TransportSource.mesh, hops: 0);
      await waitUntil(
        () => transport.sent.any((e) => e.recipientPubKey == aX),
      );

      final view = controller.conversationView(id)!;
      expect(view.isGroup, isTrue);
      expect(view.memberKeys, containsAll([myXPubKey, aX]));
      expect(view.lastTs, inbound.timestamp);
      final messages = await controller.messagesFor(id);
      expect(messages.single.body, 'первое');
      final receiptEnvelope = transport.sent.lastWhere(
        (e) => e.recipientPubKey == aX,
      );
      final raw = await decryptFor(
        receiptEnvelope,
        recipientX25519KeyPair: a.xKeyPair,
      );
      final receipt = MessagePayload.parse(raw) as ReceiptPayload;
      expect(receipt.kind, ReceiptKind.delivered);
      expect(receipt.ids, [inbound.id]);
    });

    test('the first container also updates lastTs when it is not the newest',
        () async {
      controller.startListening();
      final a = await importRemote('A');
      final id = 'e' * 64;
      await controller.createGroup(
        title: 'Crew',
        memberPeerKeys: [await a.x25519PublicKeyHex],
        ts: 1,
      );
      final container =
          GroupPayload.composeMessage(conversationId: id, text: 'late');
      final inbound = await createEnvelopeForPubKey(
        sender: a,
        recipientX25519PubKeyHex: myXPubKey,
        plaintext: container,
      );
      await processor.process(inbound, source: TransportSource.mesh, hops: 0);
      await waitUntil(
        () =>
            controller.conversationView(id)?.lastTs == inbound.timestamp,
      );

      expect(controller.isGroup(id), isTrue);
    });

    test('groupTarget resolves a known group and rejects anything else',
        () async {
      final a = await importRemote('A');
      final aX = await a.x25519PublicKeyHex;
      final id = await controller.createGroup(
        title: 'Crew',
        memberPeerKeys: [aX],
        ts: 1,
      );

      expect(controller.groupTarget(id), (id: id, title: 'Crew'));
      expect(controller.groupTarget(aX), isNull);
      expect(controller.groupTarget('f' * 64), isNull);
    });

    test('senderNameFor names a contact and shortens an unknown key',
        () async {
      final a = await importRemote('Ann');
      final aX = await a.x25519PublicKeyHex;

      expect(controller.senderNameFor(aX), 'Ann');
      expect(controller.senderNameFor(myXPubKey), isEmpty);
      expect(controller.senderNameFor('c' * 64), 'cccccccc…cccccc');
    });
  });

  test('a forged envelope is never stored', () async {
    final remote = await importRemote('Remote');
    final remoteX = await remote.x25519PublicKeyHex;
    final envelope = await createEnvelopeForPubKey(
      sender: remote,
      recipientX25519PubKeyHex: myXPubKey,
      plaintext: 'real',
    );
    final forged = Envelope(
      id: envelope.id,
      senderPubKey: envelope.senderPubKey,
      recipientPubKey: envelope.recipientPubKey,
      timestamp: envelope.timestamp,
      ciphertext: envelope.ciphertext,
      ephemeralPubKey: envelope.ephemeralPubKey,
      signature: 'a' * 128,
    );
    await processor.process(forged, source: TransportSource.mesh, hops: 0);
    expect(await controller.messagesFor(remoteX), isEmpty);
  });

  test('prunedRoots passes through the DAO', () async {
    expect(await controller.prunedRoots(), isEmpty);
  });

  group('peer book', () {
    test(
      'imported peers are reloaded from storage by a fresh controller',
      () async {
        final remote = await importRemote('Reloaded');
        final remoteX = await remote.x25519PublicKeyHex;

        final fresh = MessengerController(
          processor: processor,
          dao: dao,
          peerDao: PeerDao(db),
      conversationDao: ConversationDao(db),
          prunedRootsDao: rootsDao,
          identity: identity,
          storeOutgoing: () => false,
        );
        addTearDown(fresh.dispose);
        await fresh.init();

        expect(fresh.peers.containsKey(remoteX), isTrue);
        expect(fresh.peers[remoteX]!.displayName, 'Reloaded');
        expect(
          fresh.peers[remoteX]!.edPubKey,
          await remote.ed25519PublicKeyHex,
        );
      },
    );

    test('a bare presence update keeps name, binding and addresses',
        () async {
      final remote = await importRemote('Present');
      final remoteX = await remote.x25519PublicKeyHex;
      final remoteEd = await remote.ed25519PublicKeyHex;
      final withAddrs = controller.peers[remoteX]!.copyWith(
        peerId: 'QmPeerId',
        addrs: ['/ip4/10.0.0.1/tcp/4010'],
      );
      await controller.importPeer(withAddrs);
      controller.startListening();

      transport.emit(
        DtmPeer(pubKey: remoteX, lastSeen: DateTime.now(), online: true),
      );
      await waitUntil(() => controller.peers[remoteX]!.online);

      final merged = controller.peers[remoteX]!;
      expect(merged.online, isTrue);
      expect(merged.displayName, 'Present');
      expect(merged.edPubKey, remoteEd);
      expect(merged.peerId, 'QmPeerId');
      expect(merged.addrs, ['/ip4/10.0.0.1/tcp/4010']);

      transport.emit(
        DtmPeer(pubKey: remoteX, lastSeen: DateTime.now(), online: false),
      );
      await waitUntil(() => !controller.peers[remoteX]!.online);
      expect(controller.peers[remoteX]!.edPubKey, remoteEd);
      expect(controller.peers[remoteX]!.displayName, 'Present');
    });

    test('a presence update never clears the contact flag', () async {
      final remote = await importRemote('Contact');
      final remoteX = await remote.x25519PublicKeyHex;
      controller.startListening();

      transport.emit(
        DtmPeer(pubKey: remoteX, lastSeen: DateTime.now(), online: true),
      );
      await waitUntil(() => controller.peers[remoteX]!.online);
      expect(controller.peers[remoteX]!.isContact, isTrue);
    });

    test('renamePeer updates the name in memory and on disk', () async {
      final remote = await importRemote('Old');
      final remoteX = await remote.x25519PublicKeyHex;

      await controller.renamePeer(remoteX, 'Updated');
      expect(controller.peers[remoteX]!.displayName, 'Updated');

      final fresh = MessengerController(
        processor: processor,
        dao: dao,
        peerDao: PeerDao(db),
      conversationDao: ConversationDao(db),
        prunedRootsDao: rootsDao,
        identity: identity,
        storeOutgoing: () => false,
      );
      addTearDown(fresh.dispose);
      await fresh.init();
      expect(fresh.peers[remoteX]!.displayName, 'Updated');
    });

    test('renamePeer clamps overlong names and ignores unknown keys', () async {
      final remote = await importRemote('');
      final remoteX = await remote.x25519PublicKeyHex;
      final long = 'x' * 999;
      await controller.renamePeer(remoteX, long);
      expect(controller.peers[remoteX]!.displayName, 'x' * 64);

      await controller.renamePeer('f' * 64, 'Nobody');
      expect(controller.peers.containsKey('f' * 64), isFalse);
    });

    test('renamePeer reaches the transports', () async {
      final remote = await importRemote('Old');
      final remoteX = await remote.x25519PublicKeyHex;
      await controller.renamePeer(remoteX, 'Remote');
      expect(transport.imported.last.displayName, 'Remote');
    });

    test('contacts lists imported peers sorted by name', () async {
      await importRemote('Zeta');
      await importRemote('alpha');

      final names = controller.contacts
          .map((p) => p.displayName)
          .toList(growable: false);
      expect(names, ['alpha', 'Zeta']);
    });

    test('peerByEdPubKey resolves routing key from the binding', () async {
      final remote = await importRemote('Bound');
      final remoteX = await remote.x25519PublicKeyHex;
      final found = controller.peerByEdPubKey(await remote.ed25519PublicKeyHex);
      expect(found?.pubKey, remoteX);
      expect(controller.peerByEdPubKey('f' * 64), isNull);
    });
  });

  test('a transport-learned binding is persisted to the peer book', () async {
    controller.startListening();
    final remote = await DtmKeyPair.generate();
    final remoteX = await remote.x25519PublicKeyHex;
    transport.emit(
      DtmPeer(
        pubKey: remoteX,
        edPubKey: await remote.ed25519PublicKeyHex,
        displayName: 'Learned',
        peerId: '12D3KooWQ28G9aNnKfZr9QRXdebx5GRRKKmcJQ8GUPoEBUKBEZrb',
        lastSeen: DateTime.now(),
      ),
    );
    await waitUntil(() => controller.peers.containsKey(remoteX));
    final stored = await PeerDao(db).find(remoteX);
    expect(stored?.edPubKey, await remote.ed25519PublicKeyHex);
  });

  test('a tracker-learned peer is dialable but not a contact', () async {
    controller.startListening();
    final remote = await DtmKeyPair.generate();
    final remoteX = await remote.x25519PublicKeyHex;
    transport.emit(
      DtmPeer(
        pubKey: remoteX,
        edPubKey: await remote.ed25519PublicKeyHex,
        displayName: 'Learned',
        peerId: '12D3KooWQ28G9aNnKfZr9QRXdebx5GRRKKmcJQ8GUPoEBUKBEZrb',
        lastSeen: DateTime.now(),
      ),
    );
    await waitUntil(() => controller.peers.containsKey(remoteX));

    expect(controller.contacts, isEmpty);
    expect(controller.peerByEdPubKey(await remote.ed25519PublicKeyHex)?.pubKey,
        remoteX);
    final stored = await PeerDao(db).find(remoteX);
    expect(stored?.isContact, isFalse);
  });

  test('importPeer marks the peer as a permanent contact', () async {
    controller.startListening();
    final remote = await DtmKeyPair.generate();
    final remoteX = await remote.x25519PublicKeyHex;
    await controller.importPeer(
      DtmPeer(
        pubKey: remoteX,
        edPubKey: await remote.ed25519PublicKeyHex,
        displayName: 'Alice',
        lastSeen: DateTime.now(),
      ),
    );

    expect(controller.contacts.map((p) => p.pubKey), contains(remoteX));
    final stored = await PeerDao(db).find(remoteX);
    expect(stored?.isContact, isTrue);

    transport.emit(
      DtmPeer(
        pubKey: remoteX,
        edPubKey: await remote.ed25519PublicKeyHex,
        displayName: 'Alice',
        lastSeen: DateTime.now(),
      ),
    );
    expect(controller.contacts.map((p) => p.pubKey), contains(remoteX));
    final after = await PeerDao(db).find(remoteX);
    expect(after?.isContact, isTrue);
  });

  test('a 1:1 chat promotes a learned peer to a contact', () async {
    controller.startListening();
    processor.registerTransport(transport);
    await transport.start(
      myEdPubKey: myEdPubKey,
      myXPubKey: myXPubKey,
      displayName: 'Self',
    );
    final remote = await DtmKeyPair.generate();
    final remoteX = await remote.x25519PublicKeyHex;
    transport.emit(
      DtmPeer(
        pubKey: remoteX,
        edPubKey: await remote.ed25519PublicKeyHex,
        displayName: 'Learned',
        peerId: '12D3KooWQ28G9aNnKfZr9QRXdebx5GRRKKmcJQ8GUPoEBUKBEZrb',
        lastSeen: DateTime.now(),
      ),
    );
    await waitUntil(() => controller.peers.containsKey(remoteX));
    expect(controller.contacts, isEmpty);

    final inbound = await createEnvelopeForPubKey(
      sender: remote,
      recipientX25519PubKeyHex: myXPubKey,
      plaintext: 'hello',
    );
    await processor.process(inbound, source: TransportSource.mesh, hops: 0);
    await waitUntil(
        () => controller.contacts.any((p) => p.pubKey == remoteX));

    final stored = await PeerDao(db).find(remoteX);
    expect(stored?.isContact, isTrue);
  });

  test('an inbound message in a background chat counts as unread',
      () async {
    controller.startListening();
    final remote = await importRemote('Background');
    final remoteX = await remote.x25519PublicKeyHex;

    final inbound = await createEnvelopeForPubKey(
      sender: remote,
      recipientX25519PubKeyHex: myXPubKey,
      plaintext: 'unread one',
    );
    await processor.process(inbound, source: TransportSource.mesh, hops: 0);
    await waitUntil(
      () => (controller.conversationView(remoteX)?.unreadCount ?? 0) == 1,
    );

    expect(controller.visibleConversationId, isNull);
    expect(controller.unreadTotal, 1);
  });

  test('opening a chat marks it read and clears the tab badge', () async {
    controller.startListening();
    final remote = await importRemote('Opened');
    final remoteX = await remote.x25519PublicKeyHex;

    final inbound = await createEnvelopeForPubKey(
      sender: remote,
      recipientX25519PubKeyHex: myXPubKey,
      plaintext: 'read me',
    );
    await processor.process(inbound, source: TransportSource.mesh, hops: 0);
    await waitUntil(
      () => (controller.conversationView(remoteX)?.unreadCount ?? 0) == 1,
    );

    await controller.markConversationRead(remoteX);

    expect(controller.visibleConversationId, remoteX);
    expect(controller.conversationView(remoteX)?.unreadCount, 0);
    expect(controller.unreadTotal, 0);

    controller.clearVisibleConversation(remoteX);
    expect(controller.visibleConversationId, isNull);
  });

  test('marking a chat read tells the notification layer to drop it',
      () async {
    final seen = <String>[];
    controller.onConversationRead = seen.add;
    controller.startListening();
    final remote = await importRemote('Dismissed');
    final remoteX = await remote.x25519PublicKeyHex;
    final inbound = await createEnvelopeForPubKey(
      sender: remote,
      recipientX25519PubKeyHex: myXPubKey,
      plaintext: 'ding',
    );
    await processor.process(inbound, source: TransportSource.mesh, hops: 0);
    await waitUntil(
      () => (controller.conversationView(remoteX)?.unreadCount ?? 0) == 1,
    );

    await controller.markConversationRead(remoteX);
    expect(seen, [remoteX]);

    // Reopening an already-read chat still clears a banner left behind.
    await controller.markConversationRead(remoteX);
    expect(seen, [remoteX, remoteX]);
  });

  test('a backgrounded app treats the open chat as unread', () async {
    final seen = <String>[];
    controller.onConversationRead = seen.add;
    controller.startListening();
    final remote = await importRemote('Backgrounded');
    final remoteX = await remote.x25519PublicKeyHex;
    await controller.markConversationRead(remoteX);
    await controller.setForeground(false);
    seen.clear();

    final inbound = await createEnvelopeForPubKey(
      sender: remote,
      recipientX25519PubKeyHex: myXPubKey,
      plaintext: 'into the void',
    );
    await processor.process(inbound, source: TransportSource.mesh, hops: 0);
    await waitUntil(
      () => (controller.conversationView(remoteX)?.unreadCount ?? 0) == 1,
    );

    expect(controller.visibleConversationId, isNull);
    expect(controller.unreadTotal, 1);
    expect(seen, isEmpty);

    // Coming back to that same chat reads what arrived meanwhile and drops
    // the banner the backgrounded arrival raised.
    await controller.setForeground(true);
    await waitUntil(() => controller.unreadTotal == 0);
    expect(seen, [remoteX]);
  });

  test('returning to the foreground re-exposes the open chat', () async {
    controller.startListening();
    final remote = await importRemote('Resumed');
    final remoteX = await remote.x25519PublicKeyHex;
    await controller.markConversationRead(remoteX);
    await controller.setForeground(false);

    expect(controller.visibleConversationId, isNull);

    await controller.setForeground(true);

    expect(controller.visibleConversationId, remoteX);
    expect(controller.unreadTotal, 0);
  });

  test('a message arriving in the open chat is read on arrival', () async {
    controller.startListening();
    final remote = await importRemote('OnScreen');
    final remoteX = await remote.x25519PublicKeyHex;
    await controller.markConversationRead(remoteX);

    final inbound = await createEnvelopeForPubKey(
      sender: remote,
      recipientX25519PubKeyHex: myXPubKey,
      plaintext: 'while looking',
    );
    await processor.process(inbound, source: TransportSource.mesh, hops: 0);
    await waitUntil(() => controller.conversationList.isNotEmpty);

    expect(controller.conversationView(remoteX)?.unreadCount, 0);
    expect(controller.unreadTotal, 0);
  });

  test('unreadTotal adds up chats and skips the visible one', () async {
    controller.startListening();
    final first = await importRemote('One');
    final second = await importRemote('Two');

    for (final remote in [first, second]) {
      final inbound = await createEnvelopeForPubKey(
        sender: remote,
        recipientX25519PubKeyHex: myXPubKey,
        plaintext: 'hi',
      );
      await processor.process(inbound, source: TransportSource.mesh, hops: 0);
    }
    await waitUntil(
      () => controller.unreadTotal == 2,
    );

    await controller.markConversationRead(await first.x25519PublicKeyHex);
    expect(controller.unreadTotal, 1);
  });

  test('the read mark persists across a restart', () async {
    controller.startListening();
    final remote = await importRemote('Persisted');
    final remoteX = await remote.x25519PublicKeyHex;
    final inbound = await createEnvelopeForPubKey(
      sender: remote,
      recipientX25519PubKeyHex: myXPubKey,
      plaintext: 'persisted read',
    );
    await processor.process(inbound, source: TransportSource.mesh, hops: 0);
    await waitUntil(
      () => (controller.conversationView(remoteX)?.unreadCount ?? 0) == 1,
    );
    await controller.markConversationRead(remoteX);

    final restarted = MessengerController(
      processor: processor,
      dao: dao,
      peerDao: PeerDao(db),
      conversationDao: conversationDao,
      prunedRootsDao: rootsDao,
      identity: identity,
      transports: [transport],
      storeOutgoing: () => false,
    );
    await restarted.init();

    expect(restarted.conversationView(remoteX)?.unreadCount, 0);
    expect(restarted.unreadTotal, 0);
  });

  test('contacts survive a restart via the peer book', () async {
    controller.startListening();
    final remote = await DtmKeyPair.generate();
    final remoteX = await remote.x25519PublicKeyHex;
    await controller.importPeer(
      DtmPeer(
        pubKey: remoteX,
        edPubKey: await remote.ed25519PublicKeyHex,
        displayName: 'Alice',
        lastSeen: DateTime.now(),
      ),
    );
    await waitUntil(() => controller.contacts.isNotEmpty);

    final restarted = MessengerController(
      processor: processor,
      dao: dao,
      peerDao: PeerDao(db),
      conversationDao: conversationDao,
      prunedRootsDao: rootsDao,
      identity: identity,
      transports: const [],
      storeOutgoing: () => false,
    );
    await restarted.init();
    addTearDown(restarted.dispose);

    expect(restarted.contacts.map((p) => p.pubKey), contains(remoteX));
  });

  test(
      'an inbound from a learned-Ed peer folds into the X conversation '
      'and a reply encrypts to the X key', () async {
    controller.startListening();
    processor.registerTransport(transport);
    await transport.start(
      myEdPubKey: myEdPubKey,
      myXPubKey: myXPubKey,
      displayName: 'Self',
    );
    final remote = await DtmKeyPair.generate();
    final remoteX = await remote.x25519PublicKeyHex;
    transport.emit(
      DtmPeer(
        pubKey: remoteX,
        edPubKey: await remote.ed25519PublicKeyHex,
        displayName: 'Learned',
        peerId: '12D3KooWQ28G9aNnKfZr9QRXdebx5GRRKKmcJQ8GUPoEBUKBEZrb',
        addrs: const ['/ip4/10.0.2.2/tcp/5010'],
        lastSeen: DateTime.now(),
      ),
    );
    await waitUntil(() => controller.peers.containsKey(remoteX));

    final inbound = await createEnvelopeForPubKey(
      sender: remote,
      recipientX25519PubKeyHex: myXPubKey,
      plaintext: 'hello',
    );
    await processor.process(inbound, source: TransportSource.mesh, hops: 0);
    await waitUntil(() => controller.conversationList.isNotEmpty);

    final list = controller.conversationList;
    expect(list, hasLength(1));
    expect(list.single.id, remoteX);

    await controller.sendText(
      recipientPubKey: remoteX,
      plaintext: 'reply',
    );
    final outbound = transport.sent.last;
    expect(outbound.recipientPubKey, remoteX);
    final messages = await controller.messagesFor(remoteX);
    expect(messages, hasLength(2));
  });

  test(
      'sendToConversation on a stale Ed-keyed DM routes to the X key',
      () async {
    controller.startListening();
    processor.registerTransport(transport);
    await transport.start(
      myEdPubKey: myEdPubKey,
      myXPubKey: myXPubKey,
      displayName: 'Self',
    );
    final remote = await DtmKeyPair.generate();
    final remoteX = await remote.x25519PublicKeyHex;
    final remoteEd = await remote.ed25519PublicKeyHex;
    transport.emit(
      DtmPeer(
        pubKey: remoteX,
        edPubKey: remoteEd,
        displayName: 'Learned',
        lastSeen: DateTime.now(),
      ),
    );
    await waitUntil(() => controller.peers.containsKey(remoteX));
    await conversationDao.ensureOneOnOne(remoteEd, ts: 1);
    await controller.sendToConversation(
      conversationId: remoteEd,
      text: 'offsender',
    );
    await waitUntil(() => transport.sent.isNotEmpty);
    expect(transport.sent.single.recipientPubKey, remoteX);
  });

  test('canSendTo admits only attributable 1:1 chats', () async {
    final remote = await DtmKeyPair.generate();
    final remoteX = await remote.x25519PublicKeyHex;
    final remoteEd = await remote.ed25519PublicKeyHex;

    await conversationDao.ensureOneOnOne(remoteEd, ts: 1);
    expect(controller.canSendTo(remoteEd), isFalse);

    final unknownX = List.filled(64, 'a').join();
    await conversationDao.ensureOneOnOne(unknownX, ts: 1);
    expect(controller.canSendTo(unknownX), isFalse);

    await controller.importPeer(
      DtmPeer(
        pubKey: remoteX,
        edPubKey: remoteEd,
        displayName: 'Remote',
        lastSeen: DateTime.now(),
      ),
    );
    expect(controller.canSendTo(remoteX), isTrue);
    expect(controller.canSendTo(remoteEd), isTrue);

    final groupId = await controller.createGroup(
      title: 'g',
      memberPeerKeys: const [],
      ts: 1,
    );
    expect(controller.canSendTo(groupId), isTrue);
  });

  test('sendToConversation refuses an unbound chat and composes nothing',
      () async {
    final remote = await DtmKeyPair.generate();
    final remoteX = await remote.x25519PublicKeyHex;
    final remoteEd = await remote.ed25519PublicKeyHex;
    await conversationDao.ensureOneOnOne(remoteEd, ts: 1);

    final refused = await controller.sendToConversation(
      conversationId: remoteEd,
      text: 'must not fly',
    );
    expect(refused, isFalse);
    expect(transport.sent, isEmpty);
    expect(await controller.messagesFor(remoteEd), isEmpty);

    await controller.importPeer(
      DtmPeer(
        pubKey: remoteX,
        edPubKey: remoteEd,
        displayName: 'Remote',
        lastSeen: DateTime.now(),
      ),
    );
    controller.startListening();
    processor.registerTransport(transport);
    await transport.start(
      myEdPubKey: myEdPubKey,
      myXPubKey: myXPubKey,
      displayName: 'Self',
    );

    final delivered = await controller.sendToConversation(
      conversationId: remoteEd,
      text: 'now it flies',
    );
    expect(delivered, isTrue);
    await waitUntil(() => transport.sent.isNotEmpty);
    expect(transport.sent.single.recipientPubKey, remoteX);
  });

  group('delivery status', () {
    test('an offline send stays queued and retry advances it', () async {
      final remote = await importRemote('Remote');
      final remoteX = await remote.x25519PublicKeyHex;

      await controller.sendText(recipientPubKey: remoteX, plaintext: 'hold');
      expect(
        (await controller.messagesFor(remoteX)).single.status,
        MessageStatus.queued,
      );

      processor.registerTransport(transport);
      await transport.start(
        myEdPubKey: myEdPubKey,
        myXPubKey: myXPubKey,
        displayName: 'Self',
      );
      await controller.retryPending();

      expect(
        (await controller.messagesFor(remoteX)).single.status,
        MessageStatus.sent,
      );
    });

    test('a delivered then read receipt advances our own message', () async {
      controller.startListening();
      final remote = await importRemote('Remote');
      final remoteX = await remote.x25519PublicKeyHex;
      await controller.sendText(recipientPubKey: remoteX, plaintext: 'ping');
      final sentId = (await controller.messagesFor(remoteX)).single.id;

      await processor.process(
        await createEnvelopeForPubKey(
          sender: remote,
          recipientX25519PubKeyHex: myXPubKey,
          plaintext: MessagePayload.composeReceipt(
            kind: ReceiptKind.delivered,
            ids: [sentId],
          ),
        ),
        source: TransportSource.mesh,
        hops: 0,
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(
        (await controller.messagesFor(remoteX)).single.status,
        MessageStatus.delivered,
      );

      await processor.process(
        await createEnvelopeForPubKey(
          sender: remote,
          recipientX25519PubKeyHex: myXPubKey,
          plaintext: MessagePayload.composeReceipt(
            kind: ReceiptKind.read,
            ids: [sentId],
          ),
        ),
        source: TransportSource.mesh,
        hops: 0,
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(
        (await controller.messagesFor(remoteX)).single.status,
        MessageStatus.read,
      );
    });

    test('a receipt from a third party is ignored', () async {
      controller.startListening();
      final recipient = await importRemote('B');
      final stranger = await importRemote('C');
      final recipientX = await recipient.x25519PublicKeyHex;
      await controller.sendText(
        recipientPubKey: recipientX,
        plaintext: 'to B',
      );
      final sentId = (await controller.messagesFor(recipientX)).single.id;

      await processor.process(
        await createEnvelopeForPubKey(
          sender: stranger,
          recipientX25519PubKeyHex: myXPubKey,
          plaintext: MessagePayload.composeReceipt(
            kind: ReceiptKind.read,
            ids: [sentId],
          ),
        ),
        source: TransportSource.mesh,
        hops: 0,
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(
        (await controller.messagesFor(recipientX)).single.status,
        isNot(MessageStatus.read),
      );
    });

    test('an inbound message is acknowledged with a delivered receipt',
        () async {
      controller.startListening();
      processor.registerTransport(transport);
      await transport.start(
        myEdPubKey: myEdPubKey,
        myXPubKey: myXPubKey,
        displayName: 'Self',
      );
      final remote = await importRemote('Remote');
      final remoteX = await remote.x25519PublicKeyHex;

      final inbound = await createEnvelopeForPubKey(
        sender: remote,
        recipientX25519PubKeyHex: myXPubKey,
        plaintext: 'yo',
      );
      await processor.process(inbound, source: TransportSource.mesh, hops: 0);
      await waitUntil(
        () => transport.sent.any((e) => e.recipientPubKey == remoteX),
      );

      final receiptEnvelope =
          transport.sent.lastWhere((e) => e.recipientPubKey == remoteX);
      final raw = await decryptFor(
        receiptEnvelope,
        recipientX25519KeyPair: remote.xKeyPair,
      );
      final receipt = MessagePayload.parse(raw) as ReceiptPayload;
      expect(receipt.kind, ReceiptKind.delivered);
      expect(receipt.ids, [inbound.id]);
    });

    test('an unknown sender cannot choose the receipt address', () async {
      controller.startListening();
      processor.registerTransport(transport);
      await transport.start(
        myEdPubKey: myEdPubKey,
        myXPubKey: myXPubKey,
        displayName: 'Self',
      );
      final stranger = await DtmKeyPair.generate();
      final victim = await DtmKeyPair.generate();
      final victimX = await victim.x25519PublicKeyHex;

      final inbound = await createEnvelopeForPubKey(
        sender: stranger,
        recipientX25519PubKeyHex: myXPubKey,
        plaintext: MessagePayload.composeDirect(
          senderX: victimX,
          text: 'reflected',
        ),
      );
      await processor.process(inbound, source: TransportSource.mesh, hops: 0);
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(
        transport.sent.where((e) => e.recipientPubKey == victimX),
        isEmpty,
      );
    });

    test('opening a chat sends a read receipt for unread inbound', () async {
      controller.startListening();
      processor.registerTransport(transport);
      await transport.start(
        myEdPubKey: myEdPubKey,
        myXPubKey: myXPubKey,
        displayName: 'Self',
      );
      final remote = await importRemote('Remote');
      final remoteX = await remote.x25519PublicKeyHex;

      final inbound = await createEnvelopeForPubKey(
        sender: remote,
        recipientX25519PubKeyHex: myXPubKey,
        plaintext: 'read me',
      );
      await processor.process(inbound, source: TransportSource.mesh, hops: 0);
      await waitUntil(() => transport.sent.isNotEmpty);

      await controller.markConversationRead(remoteX);
      await waitUntil(
        () =>
            transport.sent.where((e) => e.recipientPubKey == remoteX).length ==
            2,
      );

      final receipts = <ReceiptPayload>[];
      for (final envelope in transport.sent) {
        if (envelope.recipientPubKey != remoteX) continue;
        final raw = await decryptFor(
          envelope,
          recipientX25519KeyPair: remote.xKeyPair,
        );
        receipts.add(MessagePayload.parse(raw) as ReceiptPayload);
      }
      expect(
        receipts.map((r) => r.kind),
        containsAll([ReceiptKind.delivered, ReceiptKind.read]),
      );
      final read = receipts.lastWhere((r) => r.kind == ReceiptKind.read);
      expect(read.ids, [inbound.id]);
    });

    test('a group fan-out collapses and aggregates its copies', () async {
      controller.startListening();
      processor.registerTransport(transport);
      await transport.start(
        myEdPubKey: myEdPubKey,
        myXPubKey: myXPubKey,
        displayName: 'Self',
      );
      final a = await importRemote('A');
      final b = await importRemote('B');
      final aX = await a.x25519PublicKeyHex;
      final bX = await b.x25519PublicKeyHex;
      final id = await controller.createGroup(
        title: 'Crew',
        memberPeerKeys: [aX, bX],
        ts: 1,
      );
      // Creating a group already broadcasts its roster; measure only the text
      // fan-out below.
      transport.sent.clear();

      await controller.sendGroupText(conversationId: id, text: 'all hands');
      final messages = await controller.messagesFor(id);
      expect(messages, hasLength(1));
      expect(messages.single.body, 'all hands');
      expect(messages.single.outgoing, isTrue);
      expect(messages.single.status, MessageStatus.sent);

      final copyA = transport.sent.firstWhere((e) => e.recipientPubKey == aX);
      await processor.process(
        await createEnvelopeForPubKey(
          sender: a,
          recipientX25519PubKeyHex: myXPubKey,
          plaintext: MessagePayload.composeReceipt(
            kind: ReceiptKind.delivered,
            ids: [copyA.id],
          ),
        ),
        source: TransportSource.mesh,
        hops: 0,
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(
        (await controller.messagesFor(id)).single.status,
        MessageStatus.sent,
        reason: 'one member outstanding keeps the bubble at sent',
      );

      final copyB = transport.sent.firstWhere((e) => e.recipientPubKey == bX);
      await processor.process(
        await createEnvelopeForPubKey(
          sender: b,
          recipientX25519PubKeyHex: myXPubKey,
          plaintext: MessagePayload.composeReceipt(
            kind: ReceiptKind.delivered,
            ids: [copyB.id],
          ),
        ),
        source: TransportSource.mesh,
        hops: 0,
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(
        (await controller.messagesFor(id)).single.status,
        MessageStatus.delivered,
      );
    });

    test('a receipt envelope never renders as a chat bubble', () async {
      controller.startListening();
      final remote = await importRemote('Remote');
      final remoteX = await remote.x25519PublicKeyHex;
      await controller.sendText(recipientPubKey: remoteX, plaintext: 'ping');
      final sentId = (await controller.messagesFor(remoteX)).single.id;

      await processor.process(
        await createEnvelopeForPubKey(
          sender: remote,
          recipientX25519PubKeyHex: myXPubKey,
          plaintext: MessagePayload.composeReceipt(
            kind: ReceiptKind.delivered,
            ids: [sentId],
          ),
        ),
        source: TransportSource.mesh,
        hops: 0,
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final messages = await controller.messagesFor(remoteX);
      expect(messages, hasLength(1));
      expect(messages.single.id, sentId);
      expect(messages.single.status, MessageStatus.delivered);
    });

    test('with disabled read receipts only delivery is acknowledged',
        () async {
      receiptsEnabled = false;
      controller.startListening();
      processor.registerTransport(transport);
      await transport.start(
        myEdPubKey: myEdPubKey,
        myXPubKey: myXPubKey,
        displayName: 'Self',
      );
      final remote = await importRemote('Remote');
      final remoteX = await remote.x25519PublicKeyHex;

      final inbound = await createEnvelopeForPubKey(
        sender: remote,
        recipientX25519PubKeyHex: myXPubKey,
        plaintext: 'noted',
      );
      await processor.process(inbound, source: TransportSource.mesh, hops: 0);
      await waitUntil(() => transport.sent.isNotEmpty);
      await controller.markConversationRead(remoteX);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final receipts = <ReceiptPayload>[];
      for (final envelope in transport.sent) {
        if (envelope.recipientPubKey != remoteX) continue;
        final raw = await decryptFor(
          envelope,
          recipientX25519KeyPair: remote.xKeyPair,
        );
        receipts.add(MessagePayload.parse(raw) as ReceiptPayload);
      }
      expect(receipts, hasLength(1));
      expect(receipts.single.kind, ReceiptKind.delivered);
      expect(receipts.single.ids, [inbound.id]);
    });
  });

  group('media transport', () {
    Future<void> enableOutbound() async {
      controller.startListening();
      processor.registerTransport(transport);
      await transport.start(
        myEdPubKey: myEdPubKey,
        myXPubKey: myXPubKey,
        displayName: 'Self',
      );
    }

    test('a sent voice note renders as a media bubble and caches the blob',
        () async {
      final remote = await importRemote('Voice pal');
      final remoteX = await remote.x25519PublicKeyHex;
      final data = mediaBytes(400);

      await controller.sendMediaToConversation(
        conversationId: remoteX,
        kind: MediaKind.voice,
        mime: 'audio/mp4',
        dataBase64: data,
        durationMs: 4200,
      );

      final messages = await controller.messagesFor(remoteX);
      expect(messages, hasLength(1));
      final media = messages.single.media;
      expect(media, isNotNull);
      expect(media!.kind, MediaKind.voice);
      expect(media.mime, 'audio/mp4');
      expect(media.durationMs, 4200);
      expect(media.byteCount, 400);
      expect(media.dataBase64, data);

      // The content address is a deterministic hash of the bytes, and the
      // blob is cached under it.
      expect(media.blobId, hasLength(64));
      expect(await controller.mediaBlob(media.blobId), isNotNull);
    });

    test('the outbound envelope carries the exact bytes', () async {
      await enableOutbound();
      final remote = await importRemote('Photo pal');
      final remoteX = await remote.x25519PublicKeyHex;
      final data = mediaBytes(256);

      await controller.sendMediaToConversation(
        conversationId: remoteX,
        kind: MediaKind.photo,
        mime: 'image/jpeg',
        dataBase64: data,
        durationMs: 0,
      );
      await waitUntil(() => transport.sent.isNotEmpty);

      expect(transport.sent, isNotEmpty);
      final envelope = transport.sent.last;
      final raw = await decryptFor(
        envelope,
        recipientX25519KeyPair: remote.xKeyPair,
      );
      final parsed = MessagePayload.parse(raw);
      expect(parsed, isA<MediaPayload>());
      expect((parsed as MediaPayload).dataBase64, data);
      expect(parsed.kind, MediaKind.photo);
    });

    test('an inbound voice note renders and caches its blob', () async {
      final remote = await importRemote('Sender');
      final remoteX = await remote.x25519PublicKeyHex;
      final remoteEd = await remote.ed25519PublicKeyHex;
      controller.startListening();
      final data = mediaBytes(512);
      final container = MessagePayload.composeMediaDirect(
        senderX: remoteX,
        blobId: 'a' * 64,
        kind: MediaKind.voice,
        mime: 'audio/mp4',
        byteCount: 512,
        durationMs: 3000,
        dataBase64: data,
      );
      final inbound = await createEnvelopeForPubKey(
        sender: remote,
        recipientX25519PubKeyHex: myXPubKey,
        plaintext: container,
      );
      await processor.process(inbound, source: TransportSource.mesh, hops: 0);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final messages = await controller.messagesFor(remoteEd);
      final withMedia = messages.firstWhere((m) => m.media != null);
      expect(withMedia.media!.kind, MediaKind.voice);
      expect(withMedia.media!.dataBase64, data);
      expect(withMedia.outgoing, isFalse);
    });

    test('group media collapses into one bubble by correlation id', () async {
      final a = await importRemote('Member A');
      final b = await importRemote('Member B');
      final ax = await a.x25519PublicKeyHex;
      final bx = await b.x25519PublicKeyHex;
      final groupId = await controller.createGroup(
        title: 'Media group',
        memberPeerKeys: [ax, bx],
        ts: DateTime.now().millisecondsSinceEpoch,
      );

      await controller.sendMediaToConversation(
        conversationId: groupId,
        kind: MediaKind.photo,
        mime: 'image/png',
        dataBase64: mediaBytes(128),
        durationMs: 0,
      );

      final messages = await controller.messagesFor(groupId);
      expect(messages, hasLength(1));
      expect(messages.single.media, isNotNull);
      // Every member's copy shares the correlation id.
      expect(messages.single.corrId, isNotEmpty);
    });

    test('an oversized photo is refused before any envelope is built',
        () async {
      final remote = await importRemote('Too big');
      final remoteX = await remote.x25519PublicKeyHex;
      final before = transport.sent.length;

      expect(
        () => controller.sendMediaToConversation(
          conversationId: remoteX,
          kind: MediaKind.photo,
          mime: 'image/jpeg',
          dataBase64: mediaBytes(maxMediaBlobBytes + 1),
          durationMs: 0,
        ),
        throwsArgumentError,
      );
      expect(transport.sent.length, before);
    });

    test('retention pruning drops media blobs with the same age policy',
        () async {
      final remote = await importRemote('Aged');
      final remoteX = await remote.x25519PublicKeyHex;
      await controller.sendMediaToConversation(
        conversationId: remoteX,
        kind: MediaKind.photo,
        mime: 'image/jpeg',
        dataBase64: mediaBytes(64),
        durationMs: 0,
      );
      final media = (await controller.messagesFor(remoteX)).single.media!;
      expect(await controller.mediaBlob(media.blobId), isNotNull);

      // Backdate the blob, then apply a one-day retention: only the aged row
      // goes, proving the policy reaches media and not just envelopes.
      await (db.update(db.mediaBlobs)
            ..where((b) => b.blobId.equals(media.blobId)))
          .write(const MediaBlobsCompanion(timestamp: Value(1)));
      await controller.reapplyRetention(retentionDays: 1);

      expect(await controller.mediaBlob(media.blobId), isNull);
    });
  });

  group('chunked file transport', () {
    Uint8List fileBytes(int len) =>
        Uint8List.fromList(List<int>.generate(len, (i) => (i * 31) % 251));

    Future<({ChunkManifest manifest, List<FileChunk> chunks})> parts(
      int len, {
      String transferId = 'aa',
      String sha256 = '',
    }) async {
      final split = await splitFile(
        bytes: fileBytes(len),
        transferId: transferId * 32,
        blobId: 'bb' * 32,
        kind: 'video',
        mime: 'video/mp4',
        durationMs: 5000,
      );
      if (sha256.isEmpty) return split;
      return (
        manifest: ChunkManifest(
          transferId: split.manifest.transferId,
          blobId: split.manifest.blobId,
          kind: split.manifest.kind,
          mime: split.manifest.mime,
          byteCount: split.manifest.byteCount,
          chunkSize: split.manifest.chunkSize,
          chunkCount: split.manifest.chunkCount,
          sha256: sha256,
          durationMs: split.manifest.durationMs,
        ),
        chunks: split.chunks,
      );
    }

    Future<void> deliverManifest(
      DtmKeyPair remote,
      ChunkManifest manifest,
    ) async {
      final raw = MessagePayload.composeFileManifestDirect(
        senderX: await remote.x25519PublicKeyHex,
        manifest: manifest,
      );
      await processor.process(
        await createEnvelopeForPubKey(
          sender: remote,
          recipientX25519PubKeyHex: myXPubKey,
          plaintext: raw,
        ),
        source: TransportSource.mesh,
        hops: 0,
      );
    }

    Future<void> deliverChunk(DtmKeyPair remote, FileChunk chunk) async {
      final raw = MessagePayload.composeFileChunkDirect(
        senderX: await remote.x25519PublicKeyHex,
        chunk: chunk,
      );
      await processor.process(
        await createEnvelopeForPubKey(
          sender: remote,
          recipientX25519PubKeyHex: myXPubKey,
          plaintext: raw,
        ),
        source: TransportSource.mesh,
        hops: 0,
      );
    }

    Future<void> until(Future<bool> Function() check) async {
      final deadline = DateTime.now().add(const Duration(seconds: 5));
      while (DateTime.now().isBefore(deadline)) {
        if (await check()) return;
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
    }

    test('a file assembles from out-of-order and duplicated slices',
        () async {
      controller.startListening();
      final remote = await importRemote('File pal');
      final remoteX = await remote.x25519PublicKeyHex;
      final file = await parts(200 * 1024);
      await deliverManifest(remote, file.manifest);

      final order = <FileChunk>[
        ...file.chunks.reversed,
        file.chunks.first,
      ];
      for (final chunk in order) {
        await deliverChunk(remote, chunk);
      }

      await until(() async {
        final messages = await controller.messagesFor(remoteX);
        return messages.isNotEmpty && messages.single.media != null;
      });
      final messages = await controller.messagesFor(remoteX);
      expect(messages, hasLength(1));
      final media = messages.single.media!;
      expect(media.kind, MediaKind.video);
      expect(media.mime, 'video/mp4');
      expect(media.byteCount, 200 * 1024);
      final stored = await controller.mediaBlob(media.blobId);
      expect(stored, isNotNull);
      expect(await stored!.readBytes(), fileBytes(200 * 1024));
    });

    test('a small started transfer pulls slices that never arrived',
        () async {
      controller.startListening();
      processor.registerTransport(transport);
      await transport.start(
        myEdPubKey: myEdPubKey,
        myXPubKey: myXPubKey,
        displayName: 'Me',
      );
      final remote = await importRemote('Pull pal');
      final file = await parts(64 * 1024);
      await deliverManifest(remote, file.manifest);

      // The sender would normally push it; simulate a lost push. After the
      // grace window the receiver must request the missing slice itself.
      // One delivered receipt is expected; any further frame is a slice
      // request.
      await Future<void>.delayed(const Duration(milliseconds: 2300));
      expect(transport.sent.length, greaterThan(1));
    });

    test('a tampered slice is refused and the correct retry completes',
        () async {
      controller.startListening();
      final remote = await importRemote('Tamper pal');
      final remoteX = await remote.x25519PublicKeyHex;
      final file = await parts(150 * 1024);
      await deliverManifest(remote, file.manifest);

      final tampered = FileChunk(
        transferId: file.chunks.first.transferId,
        index: file.chunks.first.index,
        dataBase64: base64Encode(fileBytes(64)),
        sha256: file.chunks.first.sha256,
      );
      await deliverChunk(remote, tampered);
      for (final chunk in file.chunks.skip(1)) {
        await deliverChunk(remote, chunk);
      }
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect((await controller.messagesFor(remoteX)).single.media, isNull);

      await deliverChunk(remote, file.chunks.first);
      await until(() async {
        final messages = await controller.messagesFor(remoteX);
        return messages.isNotEmpty && messages.single.media != null;
      });
      final media = (await controller.messagesFor(remoteX)).single.media!;
      final stored = await controller.mediaBlob(media.blobId);
      expect(stored, isNotNull);
      expect(await stored!.readBytes(), fileBytes(150 * 1024));
    });

    test('a complete set that fails the file digest is dropped', () async {
      controller.startListening();
      final remote = await importRemote('Corrupt pal');
      final remoteX = await remote.x25519PublicKeyHex;
      final file = await parts(100 * 1024, sha256: 'ff' * 32);
      await deliverManifest(remote, file.manifest);
      for (final chunk in file.chunks) {
        await deliverChunk(remote, chunk);
      }
      await until(
        () => controller.transferDao.count().then((c) => c == 0),
      );
      // The staging area is dropped, and the corrupt file never becomes a
      // bubble with bytes the user could open.
      expect(await controller.messagesFor(remoteX), isEmpty);
      expect(await controller.transferDao.count(), 0);
    });

    test('a slice without a manifest is ignored', () async {
      controller.startListening();
      final remote = await importRemote('Orphan pal');
      final remoteX = await remote.x25519PublicKeyHex;
      final file = await parts(80 * 1024);
      await deliverChunk(remote, file.chunks.first);
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(await controller.messagesFor(remoteX), isEmpty);
      expect(await controller.transferDao.count(), 0);
    });

    test('sending reports progress and caches the file locally', () async {
      final remote = await importRemote('Outgoing file');
      final remoteX = await remote.x25519PublicKeyHex;
      final progress = <int>[];
      var totals = <int>[];
      await controller.sendFileToConversation(
        conversationId: remoteX,
        kind: MediaKind.video,
        mime: 'video/mp4',
        bytes: fileBytes(200 * 1024),
        durationMs: 1000,
        onProgress: (sent, total) {
          progress.add(sent);
          totals = [total];
        },
      );
      expect(progress, isNotEmpty);
      expect(progress.last, totals.single);
      final messages = await controller.messagesFor(remoteX);
      expect(messages, hasLength(1));
      final media = messages.single.media!;
      expect(media.kind, MediaKind.video);
      expect(media.byteCount, 200 * 1024);
      final stored = await controller.mediaBlob(media.blobId);
      expect(stored, isNotNull);
      // No raw slice renders as its own bubble; the sender keeps the file.
      expect(await stored!.readBytes(), fileBytes(200 * 1024));
      expect(await controller.transferDao.count(), 0,
          reason: 'the sender manifest is complete, not an active download');
    });

    test('a file can be sent from a path without reading it first', () async {
      final remote = await importRemote('Path pal');
      final remoteX = await remote.x25519PublicKeyHex;
      final source = File('${mediaDir.path}/source.bin');
      final data = fileBytes(300 * 1024);
      await source.writeAsBytes(data);

      await controller.sendFileToConversation(
        conversationId: remoteX,
        kind: MediaKind.file,
        mime: 'application/pdf',
        path: source.path,
        durationMs: 0,
      );

      final messages = await controller.messagesFor(remoteX);
      final media = messages.single.media!;
      final stored = await controller.mediaBlob(media.blobId);
      expect(stored, isNotNull);
      expect(stored!.hasFile, isTrue);
      expect(await stored.readBytes(), data);
    });

    test('cancelling stops before the next slice is queued', () async {
      final remote = await importRemote('Cancel pal');
      final remoteX = await remote.x25519PublicKeyHex;
      final cancel = TransferCancel();
      var queued = 0;
      await expectLater(
        controller.sendFileToConversation(
          conversationId: remoteX,
          kind: MediaKind.video,
          mime: 'video/mp4',
          bytes: fileBytes(300 * 1024),
          durationMs: 1000,
          cancel: cancel,
          onProgress: (sent, _) {
            queued = sent;
            cancel.cancel();
          },
        ),
        throwsA(isA<TransferCancelled>()),
      );
      expect(queued, 1);
      // The sender keeps its own copy, so the bubble is still readable; the
      // cancel banner is the notice that the recipient may not get it.
      final messages = await controller.messagesFor(remoteX);
      expect(messages, hasLength(1));
      expect(messages.single.media, isNotNull);
    });

    test('a group file fans out and collapses into one bubble', () async {
      final a = await importRemote('File A');
      final b = await importRemote('File B');
      final groupId = await controller.createGroup(
        title: 'Files',
        memberPeerKeys: [
          await a.x25519PublicKeyHex,
          await b.x25519PublicKeyHex,
        ],
        ts: DateTime.now().millisecondsSinceEpoch,
      );
      await controller.sendFileToConversation(
        conversationId: groupId,
        kind: MediaKind.video,
        mime: 'video/mp4',
        bytes: fileBytes(140 * 1024),
        durationMs: 2000,
      );
      final messages = await controller.messagesFor(groupId);
      expect(messages, hasLength(1));
      expect(messages.single.media, isNotNull);
      expect(messages.single.corrId, isNotEmpty);
      expect(messages.single.media!.byteCount, 140 * 1024);
    });

    test('media slices prefer a direct p2p stream over the live relay',
        () async {
      final host = SpyTransport('host');
      final direct = SpyTransport('p2p');
      processor.registerTransport(host);
      processor.registerTransport(direct);
      await host.start(
        myEdPubKey: myEdPubKey,
        myXPubKey: myXPubKey,
        displayName: 'Relay',
      );
      await direct.start(
        myEdPubKey: myEdPubKey,
        myXPubKey: myXPubKey,
        displayName: 'Self',
      );
      final remote = await importRemote('Direct only');
      final remoteX = await remote.x25519PublicKeyHex;
      await controller.sendFileToConversation(
        conversationId: remoteX,
        kind: MediaKind.video,
        mime: 'video/mp4',
        bytes: fileBytes(160 * 1024),
        durationMs: 1000,
      );
      final deadline = DateTime.now().add(const Duration(seconds: 3));
      while (direct.sent.length < 4 &&
          DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      // One manifest (3 slices + 1) went direct; the relay saw the manifest
      // only and was never asked for a slice.
      expect(host.sent, hasLength(1));
      expect(direct.sent, hasLength(4));
      expect(host.directOnly.values, everyElement(isFalse));
      expect(
        direct.directOnly.values.where((flag) => flag).length,
        3,
      );
    });


    test('a relay-only connection carries slices over the live channel',
        () async {
      final host = SpyTransport('host');
      processor.registerTransport(host);
      await host.start(
        myEdPubKey: myEdPubKey,
        myXPubKey: myXPubKey,
        displayName: 'Relay',
      );
      final remote = await importRemote('Relay live');
      final remoteX = await remote.x25519PublicKeyHex;
      await controller.sendFileToConversation(
        conversationId: remoteX,
        kind: MediaKind.video,
        mime: 'video/mp4',
        bytes: fileBytes(160 * 1024),
        durationMs: 1000,
      );
      final deadline = DateTime.now().add(const Duration(seconds: 3));
      while (host.sent.length < 4 && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      // No p2p and no mesh: the manifest plus all three slices must reach the
      // relay, and the slices are flagged direct-only so it never stores them.
      expect(host.sent, hasLength(4));
      expect(
        host.directOnly.values.where((flag) => flag).length,
        3,
      );
    });


    Future<List<FileRequestPayload>> requestsToRemote(
      DtmKeyPair remote,
    ) async {
      final out = <FileRequestPayload>[];
      for (final envelope in transport.sent) {
        if (envelope.recipientPubKey !=
            await remote.x25519PublicKeyHex) {
          continue;
        }
        final raw = await decryptFor(
          envelope,
          recipientX25519KeyPair: remote.xKeyPair,
        );
        final payload = MessagePayload.parse(raw);
        if (payload is FileRequestPayload) out.add(payload);
      }
      return out;
    }

    test('a file above the push threshold is only announced', () async {
      processor.registerTransport(transport);
      await transport.start(
        myEdPubKey: myEdPubKey,
        myXPubKey: myXPubKey,
        displayName: 'Self',
      );
      final remote = await importRemote('Pull only');
      final remoteX = await remote.x25519PublicKeyHex;
      await controller.sendFileToConversation(
        conversationId: remoteX,
        kind: MediaKind.file,
        mime: 'application/pdf',
        bytes: fileBytes(senderPushBytes + 1),
        durationMs: 0,
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // The recipient pulls the slices; the sender must not upload the file
      // itself, or every slice is sent twice and the composer banner rebuilds
      // the chat hundreds of times.
      expect(transport.sent, hasLength(1));
      final raw = await decryptFor(
        transport.sent.single,
        recipientX25519KeyPair: remote.xKeyPair,
      );
      final payload = MessagePayload.parse(raw);
      expect(payload, isA<FileManifestPayload>());
      final manifest = (payload as FileManifestPayload).manifest;
      final stored = await controller.transferDao.get(manifest.transferId);
      expect(stored, isNotNull);
      expect(stored!.completed, isTrue,
          reason: 'a completed sender row serves later slice requests');
    });

    test('a file over 100 MB waits for an explicit tap, then pulls slices',
        () async {
      processor.registerTransport(transport);
      await transport.start(
        myEdPubKey: myEdPubKey,
        myXPubKey: myXPubKey,
        displayName: 'Self',
      );
      controller.startListening();
      final remote = await importRemote('Big file');
      final remoteX = await remote.x25519PublicKeyHex;
      final byteCount = autoDownloadBytes + 1;
      final chunkCount =
          (byteCount + transferChunkBytes - 1) ~/ transferChunkBytes;
      final manifest = ChunkManifest(
        transferId: 'ab' * 32,
        blobId: 'bc' * 32,
        kind: 'video',
        mime: 'video/mp4',
        byteCount: byteCount,
        chunkSize: transferChunkBytes,
        chunkCount: chunkCount,
        sha256: 'cd' * 32,
        durationMs: 0,
      );
      await deliverManifest(remote, manifest);
      await until(() async {
        final messages = await controller.messagesFor(remoteX);
        return messages.isNotEmpty;
      });
      final message = (await controller.messagesFor(remoteX)).single;
      final transfer = message.transfer!;
      expect(transfer.canStart, isTrue);
      expect(transfer.transferId, manifest.transferId);
      expect(transfer.progress, 0);
      expect(transfer.byteCount, byteCount);
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(await requestsToRemote(remote), isEmpty);

      await controller.startTransferDownload(manifest.transferId);
      await until(() async => (await requestsToRemote(remote)).isNotEmpty);
      final requests = await requestsToRemote(remote);
      expect(requests, isNotEmpty);
      expect(
        requests.length,
        lessThanOrEqualTo(maxOutstandingChunkRequests),
      );
      // Different holders get different slices, so a swarm can fill the file.
      expect(requests.map((r) => r.index).toSet(), hasLength(requests.length));
      expect(requests.first.transferId, manifest.transferId);
      expect(requests.first.blobId, manifest.blobId);
      final envelope = transport.sent.last;
      expect(await dao.isControl(envelope.id), isTrue);
      expect(await dao.isDirectOnly(envelope.id), isTrue);
    });

    test('a holder answers a slice request with the exact bytes', () async {
      processor.registerTransport(transport);
      await transport.start(
        myEdPubKey: myEdPubKey,
        myXPubKey: myXPubKey,
        displayName: 'Self',
      );
      controller.startListening();
      final remote = await importRemote('Requester');
      final remoteX = await remote.x25519PublicKeyHex;
      final file = await parts(150 * 1024);
      await deliverManifest(remote, file.manifest);
      for (final chunk in file.chunks) {
        await deliverChunk(remote, chunk);
      }
      await until(() async {
        final messages = await controller.messagesFor(remoteX);
        return messages.isNotEmpty && messages.single.media != null;
      });
      transport.sent.clear();

      final request = MessagePayload.composeFileRequestDirect(
        senderX: remoteX,
        transferId: file.manifest.transferId,
        blobId: file.manifest.blobId,
        index: 0,
      );
      await processor.process(
        await createEnvelopeForPubKey(
          sender: remote,
          recipientX25519PubKeyHex: myXPubKey,
          plaintext: request,
        ),
        source: TransportSource.mesh,
        hops: 0,
      );
      Future<FileChunkPayload?> served() async {
        for (final envelope in transport.sent) {
          final raw = await decryptPayload(
            envelope: envelope,
            recipientX25519KeyPair: remote.xKeyPair,
            senderEd25519PubKeyHex: envelope.senderPubKey,
          );
          if (raw == null) continue;
          final payload = MessagePayload.parse(raw);
          if (payload is FileChunkPayload) return payload;
        }
        return null;
      }

      await until(() async => (await served()) != null);
      final chunk = (await served())!.chunk;
      expect(chunk.index, 0);
      expect(chunk.dataBase64, file.chunks.first.dataBase64);
    });

    test('a third party cannot pull a direct file by guessing its ids',
        () async {
      processor.registerTransport(transport);
      await transport.start(
        myEdPubKey: myEdPubKey,
        myXPubKey: myXPubKey,
        displayName: 'Self',
      );
      controller.startListening();
      final sender = await importRemote('File sender');
      final attacker = await importRemote('Not the recipient');
      final attackerX = await attacker.x25519PublicKeyHex;
      final file = await parts(150 * 1024);
      await deliverManifest(sender, file.manifest);
      for (final chunk in file.chunks) {
        await deliverChunk(sender, chunk);
      }
      await until(() async {
        final messages = await controller.messagesFor(
          await sender.x25519PublicKeyHex,
        );
        return messages.isNotEmpty && messages.single.media != null;
      });
      transport.sent.clear();

      final request = MessagePayload.composeFileRequestDirect(
        senderX: attackerX,
        transferId: file.manifest.transferId,
        blobId: file.manifest.blobId,
        index: 0,
      );
      await processor.process(
        await createEnvelopeForPubKey(
          sender: attacker,
          recipientX25519PubKeyHex: myXPubKey,
          plaintext: request,
        ),
        source: TransportSource.mesh,
        hops: 0,
      );
      await Future<void>.delayed(const Duration(milliseconds: 200));
      for (final envelope in transport.sent) {
        if (envelope.recipientPubKey != attackerX) continue;
        final raw = await decryptFor(
          envelope,
          recipientX25519KeyPair: attacker.xKeyPair,
        );
        expect(MessagePayload.parse(raw), isNot(isA<FileChunkPayload>()));
      }
    });

    test('a file over the configured limit is refused before any envelope',
        () async {
      final remote = await importRemote('Too big');
      final remoteX = await remote.x25519PublicKeyHex;
      final before = transport.sent.length;
      await expectLater(
        controller.sendFileToConversation(
          conversationId: remoteX,
          kind: MediaKind.video,
          mime: 'video/mp4',
          bytes: Uint8List(2048),
          durationMs: 0,
          maxBytes: 1024,
        ),
        throwsArgumentError,
      );
      expect(transport.sent.length, before);
      expect(await controller.messagesFor(remoteX), isEmpty);
    });

    test('retention drops an incomplete transfer', () async {
      controller.startListening();
      final remote = await importRemote('Aged transfer');
      final file = await parts(100 * 1024);
      await deliverManifest(remote, file.manifest);
      await deliverChunk(remote, file.chunks.first);
      await until(
        () => controller.transferDao.count().then((c) => c == 1),
      );
      expect(await controller.transferDao.count(), 1);

      await (db.update(db.transfers)
            ..where((t) => t.transferId.equals(file.manifest.transferId)))
          .write(const TransfersCompanion(timestamp: Value(1)));
      await controller.reapplyRetention(retentionDays: 1);
      expect(await controller.transferDao.count(), 0);
    });
  });


  test('blocking a peer drops its envelopes before decryption', () async {
    final sender = await DtmKeyPair.generate();
    final senderX = await sender.x25519PublicKeyHex;
    final senderEd = await sender.ed25519PublicKeyHex;
    await controller.importPeer(
      DtmPeer(
        pubKey: senderX,
        edPubKey: senderEd,
        displayName: 'Spam',
        lastSeen: DateTime.now(),
      ),
    );

    await controller.setPeerBlocked(senderX, true);
    expect(controller.isPeerBlocked(senderX), isTrue);

    final envelope = await createEnvelopeForPubKey(
      sender: sender,
      recipientX25519PubKeyHex: myXPubKey,
      plaintext: 'blocked hello',
    );
    await processor.process(envelope, source: TransportSource.mesh, hops: 0);
    await Future<void>.delayed(Duration.zero);

    expect(await db.select(db.messages).get(), isEmpty);
    expect(
      controller.conversationList.where((c) => c.id == senderX),
      isEmpty,
    );

    await controller.setPeerBlocked(senderX, false);
    expect(controller.isPeerBlocked(senderX), isFalse);
  });
}

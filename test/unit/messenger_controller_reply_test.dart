import 'package:dtm_app/core/crypto/envelope_crypto.dart';
import 'package:dtm_app/core/crypto/keypair.dart';
import 'package:dtm_app/core/storage/conversation_dao.dart';
import 'package:dtm_app/core/storage/database.dart';
import 'package:dtm_app/core/storage/message_dao.dart';
import 'package:dtm_app/core/storage/peer_dao.dart';
import 'package:dtm_app/core/storage/pruned_roots_dao.dart';
import 'package:dtm_app/core/sync/envelope_processor.dart';
import 'package:dtm_app/core/transport/transport.dart';
import 'package:dtm_app/features/messenger/messenger_controller.dart';
import 'package:dtm_app/models/message_payload.dart';
import 'package:dtm_app/models/peer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late MessageDao dao;
  late ConversationDao conversationDao;
  late PrunedRootsDao rootsDao;
  late DtmKeyPair identity;
  late EnvelopeProcessor processor;
  late MessengerController controller;
  late String myXPubKey;

  setUp(() async {
    db = AppDatabase.inMemory();
    dao = MessageDao(db);
    conversationDao = ConversationDao(db);
    rootsDao = PrunedRootsDao(db);
    identity = await DtmKeyPair.generate();
    processor = EnvelopeProcessor(identity: identity, dao: dao);
    controller = MessengerController(
      processor: processor,
      dao: dao,
      peerDao: PeerDao(db),
      conversationDao: conversationDao,
      prunedRootsDao: rootsDao,
      identity: identity,
      transports: const <Transport>[],
      storeOutgoing: () => false,
    );
    await controller.init();
    myXPubKey = controller.myXPubKey;
  });

  tearDown(() async {
    await controller.dispose();
    await processor.dispose();
    await db.close();
  });

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

  test('sendText with quote stores the x2 wire form', () async {
    final remote = await importRemote('Remote');
    final remoteX = await remote.x25519PublicKeyHex;
    final ref = '1' * 64;
    final quoteX = '2' * 64;
    await controller.sendText(
      recipientPubKey: remoteX,
      plaintext: 'ok',
      quote: QuoteRef(refId: ref, authorX: quoteX, preview: 'q'),
    );
    final messages = await controller.messagesFor(remoteX);
    expect(messages.single.quote?.refId, ref);
    expect(messages.single.quote?.authorX, quoteX);
  });

  test('incoming x2 renders reply fields', () async {
    final remote = await importRemote('Remote');
    final remoteX = await remote.x25519PublicKeyHex;
    final ref = 'a' * 64;
    final quoteX = 'b' * 64;
    final envelope = await createEnvelopeForPubKey(
      sender: remote,
      recipientX25519PubKeyHex: myXPubKey,
      plaintext: 'x2 $remoteX $ref $quoteX\nquoted\nbody',
    );
    await processor.process(envelope, source: TransportSource.mesh, hops: 0);
    final messages = await controller.messagesFor(remoteX);
    expect(messages.single.quote?.refId, ref);
    expect(messages.single.quote?.preview, 'quoted');
  });

  test('group message with g3 preserves reply', () async {
    final a = await importRemote('A');
    final b = await importRemote('B');
    final aX = await a.x25519PublicKeyHex;
    final bX = await b.x25519PublicKeyHex;
    final id = await controller.createGroup(
      title: 'G',
      memberPeerKeys: [aX, bX],
      ts: 1,
    );
    final ref = 'c' * 64;
    final quoteX = 'd' * 64;
    await controller.sendGroupText(
      conversationId: id,
      text: 'text',
      quote: QuoteRef(refId: ref, authorX: quoteX, preview: 'p'),
    );
    final messages = await controller.messagesFor(id);
    expect(messages, isNotEmpty);
    expect(messages.first.quote?.refId, ref);
  });

  test('sendToConversation routes quote to group', () async {
    final a = await importRemote('A');
    final aX = await a.x25519PublicKeyHex;
    final id = await controller.createGroup(
      title: 'G',
      memberPeerKeys: [aX],
      ts: 1,
    );
    final ref = 'e' * 64;
    final quoteX = 'f' * 64;
    final ok = await controller.sendToConversation(
      conversationId: id,
      text: 'text',
      quote: QuoteRef(refId: ref, authorX: quoteX, preview: 'p'),
    );
    expect(ok, isTrue);
    final messages = await controller.messagesFor(id);
    expect(messages.first.quote?.refId, ref);
  });

  test('a spoofed senderX cannot forge attribution in a 1:1', () async {
    final remote = await importRemote('Remote');
    final remoteX = await remote.x25519PublicKeyHex;
    final forged = 'e' * 64;
    final envelope = await createEnvelopeForPubKey(
      sender: remote,
      recipientX25519PubKeyHex: myXPubKey,
      plaintext: 'x1 $forged\nimpersonating someone',
    );
    await processor.process(envelope, source: TransportSource.mesh, hops: 0);
    final message = (await controller.messagesFor(remoteX)).single;
    expect(message.body, 'impersonating someone');
    expect(message.senderX, remoteX);
    expect(message.senderX, isNot(forged));
  });

  test('a member cannot forge senderX inside a group', () async {
    final a = await importRemote('A');
    final b = await importRemote('B');
    final aX = await a.x25519PublicKeyHex;
    final bX = await b.x25519PublicKeyHex;
    final id = await controller.createGroup(
      title: 'G',
      memberPeerKeys: [aX, bX],
      ts: 1,
    );
    final forged = 'e' * 64;
    final envelope = await createEnvelopeForPubKey(
      sender: a,
      recipientX25519PubKeyHex: myXPubKey,
      plaintext: 'g2 $id ${'d' * 64} $forged\nimpersonating B',
    );
    await processor.process(envelope, source: TransportSource.mesh, hops: 0);
    final message = (await controller.messagesFor(id)).single;
    expect(message.body, 'impersonating B');
    expect(message.senderX, aX);
    expect(message.senderX, isNot(forged));
  });
}

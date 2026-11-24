import 'package:dtm_app/core/crypto/keypair.dart';
import 'package:dtm_app/core/storage/conversation_dao.dart';
import 'package:dtm_app/core/storage/database.dart';
import 'package:dtm_app/core/storage/message_dao.dart';
import 'package:dtm_app/core/storage/peer_dao.dart';
import 'package:dtm_app/core/storage/pruned_roots_dao.dart';
import 'package:dtm_app/core/sync/envelope_processor.dart';
import 'package:dtm_app/core/transport/transport.dart';
import 'package:dtm_app/features/messenger/messenger_controller.dart';
import 'package:dtm_app/models/peer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late PeerDao peerDao;
  late DtmKeyPair identity;
  late EnvelopeProcessor processor;
  late MessengerController controller;

  setUp(() async {
    db = AppDatabase.inMemory();
    final dao = MessageDao(db);
    peerDao = PeerDao(db);
    identity = await DtmKeyPair.generate();
    processor = EnvelopeProcessor(identity: identity, dao: dao);
    controller = MessengerController(
      processor: processor,
      dao: dao,
      peerDao: peerDao,
      conversationDao: ConversationDao(db),
      prunedRootsDao: PrunedRootsDao(db),
      identity: identity,
      transports: const <Transport>[],
      storeOutgoing: () => false,
    );
    await controller.init();
  });

  tearDown(() async {
    await controller.dispose();
    await processor.dispose();
    await db.close();
  });

  Future<(String, String, String)> importedPeer({String name = 'Anna'}) async {
    final remote = await DtmKeyPair.generate();
    final x = await remote.x25519PublicKeyHex;
    final ed = await remote.ed25519PublicKeyHex;
    final ok = await controller.importPeer(
      DtmPeer(
        pubKey: x,
        edPubKey: ed,
        displayName: name,
        lastSeen: DateTime.now(),
      ),
    );
    expect(ok, isTrue);
    return (x, ed, name);
  }

  test('a verified peer is reported as verified in memory and on disk',
      () async {
    final (x, ed, _) = await importedPeer();
    expect(controller.peers[x]!.isVerified, isFalse);

    expect(await controller.markPeerVerified(x), isTrue);

    final memory = controller.peers[x]!;
    expect(memory.isVerified, isTrue);
    expect(memory.verifiedEdPubKey, ed);
    expect(memory.keyChanged, isFalse);

    final stored = (await peerDao.find(x))!;
    expect(stored.verifiedEdPubKey, ed);
  });

  test('a new Ed25519 key for a verified contact raises the warning',
      () async {
    final (x, ed, _) = await importedPeer();
    await controller.markPeerVerified(x);

    final replacement = await DtmKeyPair.generate();
    final ok = await controller.importPeer(
      DtmPeer(
        pubKey: x,
        edPubKey: await replacement.ed25519PublicKeyHex,
        displayName: 'Anna',
        lastSeen: DateTime.now(),
      ),
    );
    expect(ok, isTrue);

    final memory = controller.peers[x]!;
    expect(memory.isVerified, isFalse);
    expect(memory.keyChanged, isTrue);
    expect(memory.verifiedEdPubKey, ed);

    final stored = (await peerDao.find(x))!;
    expect(stored.keyChanged, isTrue);
  });

  test('verifying again after the change clears the warning', () async {
    final (x, _, _) = await importedPeer();
    await controller.markPeerVerified(x);
    final replacement = await DtmKeyPair.generate();
    await controller.importPeer(
      DtmPeer(
        pubKey: x,
        edPubKey: await replacement.ed25519PublicKeyHex,
        lastSeen: DateTime.now(),
      ),
    );

    expect(await controller.markPeerVerified(x), isTrue);
    expect(controller.peers[x]!.isVerified, isTrue);
    expect(controller.peers[x]!.keyChanged, isFalse);
  });

  test('verification refuses unknown keys and missing bindings', () async {
    expect(await controller.markPeerVerified('nope'), isFalse);
    expect(await controller.markPeerVerified('a' * 64), isFalse);

    final remote = await DtmKeyPair.generate();
    final x = await remote.x25519PublicKeyHex;
    await controller.importPeer(
      DtmPeer(pubKey: x, displayName: 'No binding', lastSeen: DateTime.now()),
    );
    expect(await controller.markPeerVerified(x), isFalse);
  });
}

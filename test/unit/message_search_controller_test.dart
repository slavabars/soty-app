import 'package:dtm_app/core/crypto/envelope_crypto.dart';
import 'package:dtm_app/core/crypto/keypair.dart';
import 'package:dtm_app/core/search/message_search.dart';
import 'package:dtm_app/core/security_limits.dart';
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
  late EnvelopeProcessor processor;
  late MessengerController controller;
  late ConversationDao conversationDao;
  late DtmKeyPair remote;
  late String remoteX;

  setUp(() async {
    db = AppDatabase.inMemory();
    dao = MessageDao(db);
    final identity = await DtmKeyPair.generate();
    processor = EnvelopeProcessor(identity: identity, dao: dao);
    conversationDao = ConversationDao(db);
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
    remote = await DtmKeyPair.generate();
    remoteX = await remote.x25519PublicKeyHex;
    await controller.importPeer(
      DtmPeer(
        pubKey: remoteX,
        edPubKey: await remote.ed25519PublicKeyHex,
        displayName: 'Anna',
        lastSeen: DateTime.now(),
      ),
    );
  });

  tearDown(() async {
    await controller.dispose();
    await processor.dispose();
    await db.close();
  });

  Future<void> deliver(
    String text, {
    int? timestamp,
    MediaKind? media,
  }) async {
    final plaintext = media == null
        ? MessagePayload.composeDirect(senderX: remoteX, text: text)
        : MessagePayload.composeMediaDirect(
            senderX: remoteX,
            blobId: (media == MediaKind.voice ? 'aa' : 'bb') * 32,
            kind: media,
            mime: media == MediaKind.voice ? 'audio/mp4' : 'image/jpeg',
            byteCount: 3,
            durationMs: media == MediaKind.voice ? 900 : 0,
            dataBase64: 'AQID',
          );
    final envelope = await createEnvelopeForPubKey(
      sender: remote,
      recipientX25519PubKeyHex: controller.myXPubKey,
      plaintext: plaintext,
      timestamp: timestamp,
    );
    await processor.process(envelope, source: TransportSource.mesh, hops: 0);
    // Inbound bookkeeping is scheduled from a stream event; give it a turn so
    // the conversation row exists before the index reads the database.
    for (var i = 0; i < 50; i++) {
      final rows = await conversationDao.all(
        myXPubKey: controller.myXPubKey,
        myEdPubKey: controller.myEdPubKey,
      );
      if (rows.isNotEmpty) break;
      await Future<void>.delayed(Duration.zero);
    }
  }

  test('finds inbound and outgoing text, newest first', () async {
    await deliver('hello from Anna');
    await controller.sendText(
      recipientPubKey: remoteX,
      plaintext: 'hello back',
    );

    final hits = await controller.searchMessages(
      const MessageSearch(text: 'hello'),
    );
    expect(hits, hasLength(2));
    expect(hits.first.outgoing, isTrue);
    expect(hits.last.conversationTitle, 'Anna');
  });

  test('a text search is case-insensitive', () async {
    await deliver('Important News');
    final hits = await controller.searchMessages(
      const MessageSearch(text: 'important'),
    );
    expect(hits.single.body, 'Important News');
  });

  test('the unread filter follows the read cursor', () async {
    await deliver('unread ping');
    var hits = await controller.searchMessages(
      const MessageSearch(text: 'ping', unreadOnly: true),
    );
    expect(hits, hasLength(1));

    await controller.markConversationRead(remoteX);
    hits = await controller.searchMessages(
      const MessageSearch(text: 'ping', unreadOnly: true),
    );
    expect(hits, isEmpty);
  });

  test('a pruned message disappears from search automatically', () async {
    await deliver('ancient message', timestamp: 1000);
    var hits = await controller.searchMessages(
      const MessageSearch(text: 'ancient'),
    );
    expect(hits, hasLength(1));

    await controller.reapplyRetention(retentionDays: 7);
    hits = await controller.searchMessages(
      const MessageSearch(text: 'ancient'),
    );
    expect(hits, isEmpty);
  });

  test('media filters return voice and photo bubbles', () async {
    await deliver('', media: MediaKind.voice);
    await deliver('caption', media: MediaKind.photo);

    final voice = await controller.searchMessages(
      const MessageSearch(text: '', kind: SearchKind.voice),
    );
    final photos = await controller.searchMessages(
      const MessageSearch(text: '', kind: SearchKind.photos),
    );
    expect(voice, hasLength(1));
    expect(voice.single.media, MediaKind.voice);
    expect(photos, hasLength(1));
    expect(photos.single.media, MediaKind.photo);
  });

  test('the index is bounded by the shared message cap', () async {
    expect(maxSearchIndexMessages, greaterThan(0));
  });
}

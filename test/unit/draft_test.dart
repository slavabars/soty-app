import 'dart:convert';

import 'package:dtm_app/core/crypto/keypair.dart';
import 'package:dtm_app/core/security_limits.dart';
import 'package:dtm_app/core/storage/conversation_dao.dart';
import 'package:dtm_app/core/storage/database.dart';
import 'package:dtm_app/core/storage/message_dao.dart';
import 'package:dtm_app/core/storage/peer_dao.dart';
import 'package:dtm_app/core/storage/pruned_roots_dao.dart';
import 'package:dtm_app/core/sync/envelope_processor.dart';
import 'package:dtm_app/core/transport/transport.dart';
import 'package:dtm_app/features/messenger/messenger_controller.dart';
import 'package:dtm_app/models/message_status.dart';
import 'package:dtm_app/models/peer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late MessageDao dao;
  late DtmKeyPair identity;
  late EnvelopeProcessor processor;
  late MessengerController controller;
  late String remoteX;

  setUp(() async {
    db = AppDatabase.inMemory();
    dao = MessageDao(db);
    identity = await DtmKeyPair.generate();
    processor = EnvelopeProcessor(identity: identity, dao: dao);
    controller = MessengerController(
      processor: processor,
      dao: dao,
      peerDao: PeerDao(db),
      conversationDao: ConversationDao(db),
      prunedRootsDao: PrunedRootsDao(db),
      identity: identity,
      transports: const <Transport>[],
      storeOutgoing: () => true,
    );
    await controller.init();
    final remote = await DtmKeyPair.generate();
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

  test('a draft round-trips and clears', () async {
    await controller.saveDraft(remoteX, 'half a thought');
    expect(await controller.draftFor(remoteX), 'half a thought');

    await controller.clearDraft(remoteX);
    expect(await controller.draftFor(remoteX), isNull);
  });

  test('drafts are per chat and whitespace does not create one', () async {
    await controller.saveDraft('a' * 64, 'for A');
    await controller.saveDraft('b' * 64, 'for B');
    expect(await controller.draftFor('a' * 64), 'for A');
    expect(await controller.draftFor('b' * 64), 'for B');

    await controller.saveDraft('a' * 64, '   ');
    expect(await controller.draftFor('a' * 64), isNull);
  });

  test('an overlong draft is clamped to the plaintext limit', () async {
    final huge = 'ё' * 5000;
    await controller.saveDraft(remoteX, huge);
    final stored = (await controller.draftFor(remoteX))!;
    expect(utf8.encode(stored).length, lessThanOrEqualTo(maxPlaintextBytes));
    expect(stored, isNotEmpty);
  });

  test('a draft survives a controller restart', () async {
    await controller.saveDraft(remoteX, 'unsent after restart');
    await controller.dispose();
    await processor.dispose();

    final nextProcessor = EnvelopeProcessor(identity: identity, dao: dao);
    final next = MessengerController(
      processor: nextProcessor,
      dao: dao,
      peerDao: PeerDao(db),
      conversationDao: ConversationDao(db),
      prunedRootsDao: PrunedRootsDao(db),
      identity: identity,
      transports: const <Transport>[],
      storeOutgoing: () => true,
    );
    await next.init();
    expect(await next.draftFor(remoteX), 'unsent after restart');
    await next.dispose();
    await nextProcessor.dispose();

    // Leave tearDown a live controller to dispose.
    processor = EnvelopeProcessor(identity: identity, dao: dao);
    controller = MessengerController(
      processor: processor,
      dao: dao,
      peerDao: PeerDao(db),
      conversationDao: ConversationDao(db),
      prunedRootsDao: PrunedRootsDao(db),
      identity: identity,
      transports: const <Transport>[],
      storeOutgoing: () => true,
    );
    await controller.init();
  });

  test('a send without a transport stays queued and is retried later',
      () async {
    await controller.sendText(
      recipientPubKey: remoteX,
      plaintext: 'into the void',
    );

    expect(
      await controller.pendingOutgoing(remoteX),
      isEmpty,
      reason: 'a message still in flight must not flash the red banner',
    );
    final later = DateTime.now().add(
      const Duration(milliseconds: pendingBannerGraceMs + 1000),
    );
    final pending = await controller.pendingOutgoing(remoteX, now: later);
    expect(pending, hasLength(1));
    expect(
      await dao.statusFor(pending.single),
      MessageStatus.queued,
      reason: 'a failed dispatch must never look sent',
    );

    await controller.retryPending();
    expect(
      await dao.statusFor(pending.single),
      MessageStatus.queued,
      reason: 'still no transport, so still queued',
    );

    expect(await controller.pendingOutgoing('b' * 64, now: later), isEmpty);
  });

  test('a queued control slice never raises the delivery banner', () async {
    // Slice and request frames are stored like messages but are not chat
    // messages: the recipient's read receipt can be on screen while a control
    // envelope is still queued, and the banner must not contradict the ticks.
    final envelope = await processor.sendMedia(
      recipientXPubKey: remoteX,
      plaintext: 'c1 control frame',
      directOnly: true,
      control: true,
    );
    expect(await dao.statusFor(envelope.id), MessageStatus.queued);

    final later = DateTime.now().add(
      const Duration(milliseconds: pendingBannerGraceMs + 1000),
    );
    expect(await controller.pendingOutgoing(remoteX, now: later), isEmpty);
  });
}

import 'package:dtm_app/core/crypto/envelope_crypto.dart';
import 'package:dtm_app/core/crypto/keypair.dart';
import 'package:dtm_app/core/i18n/app_prefs.dart';
import 'package:dtm_app/core/i18n/soty_l10n.dart';
import 'package:dtm_app/core/media/media_capture.dart';
import 'package:dtm_app/core/storage/conversation_dao.dart';
import 'package:dtm_app/core/storage/database.dart';
import 'package:dtm_app/core/storage/message_dao.dart';
import 'package:dtm_app/core/storage/peer_dao.dart';
import 'package:dtm_app/core/storage/pruned_roots_dao.dart';
import 'package:dtm_app/core/sync/envelope_processor.dart';
import 'package:dtm_app/core/transport/transport.dart';
import 'package:dtm_app/features/messenger/chat_screen.dart';
import 'package:dtm_app/features/messenger/messenger_controller.dart';
import 'package:dtm_app/models/group_payload.dart';
import 'package:dtm_app/models/message_payload.dart';
import 'package:dtm_app/models/peer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class Fixture {
  Fixture(this.controller, this.processor, this.remote, this.peerX, this.db);

  final MessengerController controller;
  final EnvelopeProcessor processor;
  final DtmKeyPair remote;
  final String peerX;

  /// Direct handle for seeding rows an older build could have written, such as
  /// a group roster whose member key is not valid hex — which the current
  /// [ConversationDao.createGroup] would refuse.
  final AppDatabase db;
}

/// Imports a second contact and opens a 1:1 conversation with them by
/// delivering one inbound message, so a forward has somewhere to go.
Future<String> makeSecondConversation(Fixture f) async {
  final other = await DtmKeyPair.generate();
  final otherX = await other.x25519PublicKeyHex;
  await f.controller.importPeer(
    DtmPeer(
      pubKey: otherX,
      edPubKey: await other.ed25519PublicKeyHex,
      displayName: 'Second',
      lastSeen: DateTime.now(),
    ),
  );
  final envelope = await createEnvelopeForPubKey(
    sender: other,
    recipientX25519PubKeyHex: f.controller.myXPubKey,
    plaintext: MessagePayload.composeDirect(
      senderX: otherX,
      text: 'hello from second',
    ),
  );
  await f.processor.process(envelope, source: TransportSource.mesh, hops: 0);
  return otherX;
}

Future<Fixture> makeFixture() async {
  final db = AppDatabase.inMemory();
  final dao = MessageDao(db);
  final keyPair = await DtmKeyPair.generate();
  final processor = EnvelopeProcessor(identity: keyPair, dao: dao);
  final controller = MessengerController(
    processor: processor,
    dao: dao,
    peerDao: PeerDao(db),
    conversationDao: ConversationDao(db),
    prunedRootsDao: PrunedRootsDao(db),
    identity: keyPair,
    transports: const <Transport>[],
    storeOutgoing: () => true,
  );
  addTearDown(() async {
    await controller.dispose();
    await processor.dispose();
    await db.close();
  });
  await controller.init();
  controller.startListening();

  final remote = await DtmKeyPair.generate();
  final peerX = await remote.x25519PublicKeyHex;
  await controller.importPeer(
    DtmPeer(
      pubKey: peerX,
      edPubKey: await remote.ed25519PublicKeyHex,
      displayName: 'Zora',
      lastSeen: DateTime.now(),
    ),
  );
  return Fixture(controller, processor, remote, peerX, db);
}

Future<void> sendInbound(Fixture f, String text, {int? timestamp}) async {
  final envelope = await createEnvelopeForPubKey(
    sender: f.remote,
    recipientX25519PubKeyHex: f.controller.myXPubKey,
    plaintext: MessagePayload.composeDirect(
      senderX: await f.remote.x25519PublicKeyHex,
      text: text,
    ),
    timestamp: timestamp,
  );
  await f.processor.process(envelope, source: TransportSource.mesh, hops: 0);
}

/// Delivers a bare plaintext with no container header, as a legacy sender —
/// or a hostile one probing the parser — could. It must parse to a plain-text
/// payload and still render, never vanish.
Future<void> sendInboundRaw(Fixture f, String text, {int? timestamp}) async {
  final envelope = await createEnvelopeForPubKey(
    sender: f.remote,
    recipientX25519PubKeyHex: f.controller.myXPubKey,
    plaintext: text,
    timestamp: timestamp,
  );
  await f.processor.process(envelope, source: TransportSource.mesh, hops: 0);
}

/// Imports a contact and opens a small group with them, returning the group
/// id and the member's key material so a test can deliver member messages.
Future<({String groupId, DtmKeyPair member, String memberX})> makeGroup(
  Fixture f, {
  String title = 'Team',
}) async {
  final member = await DtmKeyPair.generate();
  final memberX = await member.x25519PublicKeyHex;
  await f.controller.importPeer(
    DtmPeer(
      pubKey: memberX,
      edPubKey: await member.ed25519PublicKeyHex,
      displayName: 'Member',
      lastSeen: DateTime.now(),
    ),
  );
  final groupId = await f.controller.createGroup(
    title: title,
    memberPeerKeys: [memberX],
    ts: 1,
  );
  return (groupId: groupId, member: member, memberX: memberX);
}

/// Delivers a legacy `g1` group container from [member] into [groupId]. Legacy
/// group messages carry no correlation id, so they cannot be quoted.
Future<void> sendLegacyGroupInbound(
  Fixture f,
  String groupId,
  String text, {
  required DtmKeyPair member,
}) async {
  final envelope = await createEnvelopeForPubKey(
    sender: member,
    recipientX25519PubKeyHex: f.controller.myXPubKey,
    plaintext: GroupPayload.composeMessage(
      conversationId: groupId,
      text: text,
    ),
  );
  await f.processor.process(envelope, source: TransportSource.mesh, hops: 0);
}

/// Delivers a current `g2` group container from the group's member.
Future<void> sendGroupMemberMessage(
  Fixture f,
  ({String groupId, DtmKeyPair member, String memberX}) group,
  String text,
) async {
  final envelope = await createEnvelopeForPubKey(
    sender: group.member,
    recipientX25519PubKeyHex: f.controller.myXPubKey,
    plaintext: MessagePayload.composeGroupMessage(
      conversationId: group.groupId,
      corrId: 'c' * 64,
      senderX: group.memberX,
      text: text,
    ),
  );
  await f.processor.process(envelope, source: TransportSource.mesh, hops: 0);
}

Widget wrap(Widget child) {
  return MaterialApp(
    builder: (context, w) =>
        SotyL10n(locale: const Locale('en'), child: w ?? const SizedBox()),
    home: child,
  );
}

Widget chat(
  Fixture f, {
  AppPrefs? prefs,
  String? conversationId,
  Future<void> Function(String route)? onSotyLink,
  MediaServices? media,
}) =>
    ChatScreen(
      messenger: f.controller,
      conversationId: conversationId ?? f.peerX,
      prefs: prefs ?? AppPrefs(),
      onSotyLink: onSotyLink,
      media: media,
    );

/// The message list viewport, as opposed to the composer text field, which
/// brings its own [Scrollable] along. The list is reversed: row 0 is the
/// newest message at the bottom (offset 0); `maxScrollExtent` is the oldest.
ScrollPosition listPosition(WidgetTester tester) {
  final finder = find.descendant(
    of: find.byType(ListView),
    matching: find.byType(Scrollable),
  );
  return tester.state<ScrollableState>(finder).position;
}

double offset(WidgetTester tester) => listPosition(tester).pixels;

double maxOffset(WidgetTester tester) => listPosition(tester).maxScrollExtent;

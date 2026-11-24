import 'dart:async';

import 'package:dtm_app/core/crypto/envelope_crypto.dart';
import 'package:dtm_app/core/crypto/keypair.dart';
import 'package:dtm_app/core/security_limits.dart';
import 'package:dtm_app/core/storage/conversation_dao.dart';
import 'package:dtm_app/core/storage/database.dart';
import 'package:dtm_app/core/storage/message_dao.dart';
import 'package:dtm_app/core/storage/peer_dao.dart';
import 'package:dtm_app/core/storage/pruned_roots_dao.dart';
import 'package:dtm_app/core/sync/envelope_processor.dart'
    show EnvelopeProcessor, maxRelayHops;
import 'package:dtm_app/core/transport/mesh/mesh_transport.dart';
import 'package:dtm_app/features/messenger/messenger_controller.dart';
import 'package:dtm_app/models/envelope.dart';
import 'package:dtm_app/models/peer.dart';
import 'package:flutter_mesh_network/flutter_mesh_network.dart';
import 'package:flutter_test/flutter_test.dart';

/// A broadcast bus that mimics `flutter_mesh_network` flooding: a published
/// payload reaches every connected node, and each node carries a hop count
/// equal to its distance from the origin.
class VirtualMeshBus {
  final Map<String, BusSession> _sessions = {};
  final Map<String, Set<String>> _edges = {};

  void register(String id, BusSession session) {
    _sessions[id] = session;
    _edges.putIfAbsent(id, () => <String>{});
  }

  void connect(String a, String b) {
    _edges[a]!.add(b);
    _edges[b]!.add(a);
  }

  void publish(String origin, String payload) {
    final visited = <String>{origin};
    var frontier = <String>[origin];
    var hop = 0;
    while (frontier.isNotEmpty) {
      hop++;
      final next = <String>[];
      for (final node in frontier) {
        for (final neighbour in _edges[node]!) {
          if (!visited.add(neighbour)) continue;
          _sessions[neighbour]?.deliver(
            MeshMessage(
              id: 'mesh-$origin-$neighbour-$hop',
              senderId: origin,
              senderName: origin,
              type: MessageType.text,
              priority: MessagePriority.normal,
              payload: payload,
              hopCount: hop,
              createdAt: DateTime.now(),
              expiresAt: DateTime.now().add(const Duration(hours: 1)),
            ),
          );
          next.add(neighbour);
        }
      }
      frontier = next;
    }
  }
}

class BusSession implements MeshSession {
  final VirtualMeshBus bus;
  final String id;
  final _messages = StreamController<MeshMessage>.broadcast();
  final _nodes = StreamController<MeshNode>.broadcast();
  final List<String> sent = [];

  BusSession(this.bus, this.id);

  @override
  Stream<MeshMessage> get onMessage => _messages.stream;

  @override
  Stream<MeshNode> get onNodeChanged => _nodes.stream;

  @override
  Future<void> start({
    required String userId,
    required String userName,
  }) async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> sendText(String message) async {
    sent.add(message);
    bus.publish(id, message);
  }

  void deliver(MeshMessage message) => _messages.add(message);

  Future<void> dispose() async {
    await _messages.close();
    await _nodes.close();
  }
}

class Device {
  final String label;
  final AppDatabase db;
  final MessageDao dao;
  final DtmKeyPair keys;
  final EnvelopeProcessor processor;
  final MessengerController controller;
  final MeshTransport transport;
  final BusSession session;
  late String x;
  late String ed;

  Device({
    required this.label,
    required this.db,
    required this.dao,
    required this.keys,
    required this.processor,
    required this.controller,
    required this.transport,
    required this.session,
  });
}

Future<Device> makeDevice(String label, VirtualMeshBus bus) async {
  final db = AppDatabase.inMemory();
  final dao = MessageDao(db);
  final keys = await DtmKeyPair.generate();
  final session = BusSession(bus, label);
  bus.register(label, session);
  final transport = MeshTransport(session: session);
  final processor = EnvelopeProcessor(identity: keys, dao: dao);
  processor.registerTransport(transport);
  final controller = MessengerController(
    processor: processor,
    dao: dao,
    peerDao: PeerDao(db),
        conversationDao: ConversationDao(db),
    prunedRootsDao: PrunedRootsDao(db),
    identity: keys,
    transports: [transport],
    storeOutgoing: () => false,
  );
  await controller.init();
  controller.startListening();
  await transport.start(
    myEdPubKey: controller.myEdPubKey,
    myXPubKey: controller.myXPubKey,
    displayName: label,
  );
  final device = Device(
    label: label,
    db: db,
    dao: dao,
    keys: keys,
    processor: processor,
    controller: controller,
    transport: transport,
    session: session,
  );
  device.x = controller.myXPubKey;
  device.ed = controller.myEdPubKey;
  return device;
}

Future<void> importPeer(Device self, Device other) async {
  expect(
    await self.controller.importPeer(
      DtmPeer(
        pubKey: other.x,
        edPubKey: other.ed,
        displayName: other.label,
        lastSeen: DateTime.now(),
      ),
    ),
    isTrue,
  );
}

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));

Future<void> disposeDevice(Device device) async {
  await device.controller.dispose();
  await device.processor.dispose();
  await device.transport.dispose();
  await device.session.dispose();
  await device.db.close();
}

void main() {
  late VirtualMeshBus bus;
  final devices = <Device>[];

  setUp(() {
    bus = VirtualMeshBus();
  });

  tearDown(() async {
    for (final device in devices) {
      await disposeDevice(device);
    }
    devices.clear();
  });

  Future<Device> device(String label) async {
    final d = await makeDevice(label, bus);
    devices.add(d);
    return d;
  }

  test('a relay node forwards a message without surfacing it', () async {
    final a = await device('A');
    final b = await device('B');
    final c = await device('C');
    bus
      ..connect('A', 'B')
      ..connect('B', 'C');
    for (final pair in [
      [a, b],
      [a, c],
      [b, c],
    ]) {
      await importPeer(pair[0], pair[1]);
      await importPeer(pair[1], pair[0]);
    }

    await a.controller.sendText(recipientPubKey: c.x, plaintext: 'for C only');
    await settle();

    // C receives and decrypts.
    final atC = await c.controller.messagesFor(a.x);
    expect(atC, hasLength(1));
    expect(atC.single.outgoing, isFalse);
    expect(atC.single.body, 'for C only');

    // B relays (stores the envelope) but it must never look like B's own chat.
    final envelopeId = atC.single.id;
    expect(await b.dao.has(envelopeId), isTrue);
    expect(await b.controller.messagesFor(c.x), isEmpty);
    expect(await b.controller.messagesFor(a.x), isEmpty);
    expect(await b.controller.conversations(), isEmpty);
  });

  test('the hop ladder drops frames beyond maxRelayHops', () async {
    final line = <Device>[];
    for (var i = 0; i <= maxRelayHops + 1; i++) {
      line.add(await device('N$i'));
    }
    for (var i = 0; i < line.length - 1; i++) {
      bus.connect('N$i', 'N${i + 1}');
    }
    final origin = line.first;
    final recipient = line.last; // distance maxRelayHops + 1 → dropped
    final lastInRange = line[line.length - 2]; // distance maxRelayHops → kept
    await importPeer(origin, recipient);
    await importPeer(recipient, origin);

    await origin.controller.sendText(
      recipientPubKey: recipient.x,
      plaintext: 'too far',
    );
    await settle();

    expect(await recipient.controller.messagesFor(origin.x), isEmpty);
    final envelope = await origin.dao.envelopeById(
      (await origin.controller.messagesFor(recipient.x)).single.id,
    );
    expect(envelope, isNotNull);
    expect(await lastInRange.dao.has(envelope!.id), isTrue);
  });

  test('a tampered envelope carried by the mesh is rejected', () async {
    final a = await device('A');
    final c = await device('C');
    bus.connect('A', 'C');
    await importPeer(c, a);

    final envelope = await createEnvelopeForPubKey(
      sender: a.keys,
      recipientX25519PubKeyHex: c.x,
      plaintext: 'tamper me',
    );
    final forged = Envelope(
      id: envelope.id,
      senderPubKey: envelope.senderPubKey,
      recipientPubKey: envelope.recipientPubKey,
      timestamp: envelope.timestamp,
      ciphertext: envelope.ciphertext,
      ephemeralPubKey: envelope.ephemeralPubKey,
      signature: 'b' * 128,
    );
    c.session.deliver(
      MeshMessage(
        id: 'forged',
        senderId: 'A',
        senderName: 'A',
        type: MessageType.text,
        priority: MessagePriority.normal,
        payload: forged.encode(),
        hopCount: 1,
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      ),
    );
    await settle();

    expect(await c.dao.has(envelope.id), isFalse);
    expect(await c.controller.messagesFor(a.x), isEmpty);
  });

  test('duplicate and oversized frames are dropped', () async {
    final a = await device('A');
    final c = await device('C');
    bus.connect('A', 'C');
    await importPeer(c, a);

    final envelope = await createEnvelopeForPubKey(
      sender: a.keys,
      recipientX25519PubKeyHex: c.x,
      plaintext: 'once',
    );
    MeshMessage frame(String payload, String id) => MeshMessage(
      id: id,
      senderId: 'A',
      senderName: 'A',
      type: MessageType.text,
      priority: MessagePriority.normal,
      payload: payload,
      hopCount: 1,
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
    );

    c.session.deliver(frame(envelope.encode(), 'd1'));
    c.session.deliver(frame(envelope.encode(), 'd2'));
    c.session.deliver(frame('x' * (maxFrameBytes + 1), 'big'));
    await settle();

    expect(await c.controller.messagesFor(a.x), hasLength(1));
  });
}

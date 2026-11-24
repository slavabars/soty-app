import 'dart:async';

import 'package:dtm_app/core/crypto/envelope_crypto.dart';
import 'package:dtm_app/core/crypto/keypair.dart';
import 'package:dtm_app/core/security_limits.dart';
import 'package:dtm_app/core/sync/envelope_processor.dart' show maxRelayHops;
import 'package:dtm_app/core/transport/mesh/mesh_transport.dart';
import 'package:dtm_app/core/transport/transport.dart';
import 'package:dtm_app/models/envelope.dart';
import 'package:dtm_app/models/peer.dart';
import 'package:flutter_mesh_network/flutter_mesh_network.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeMeshSession implements MeshSession {
  final _messages = StreamController<MeshMessage>.broadcast();
  final _nodes = StreamController<MeshNode>.broadcast();
  final List<String> sent = [];
  bool started = false;
  bool failSend = false;

  @override
  Stream<MeshMessage> get onMessage => _messages.stream;

  @override
  Stream<MeshNode> get onNodeChanged => _nodes.stream;

  @override
  Future<void> start({required String userId, required String userName}) async {
    started = true;
  }

  @override
  Future<void> stop() async {
    started = false;
  }

  @override
  Future<void> sendText(String message) async {
    if (failSend) throw StateError('mesh is down');
    sent.add(message);
  }

  void deliver(MeshMessage message) => _messages.add(message);

  void changeNode(MeshNode node) => _nodes.add(node);

  Future<void> dispose() async {
    await _messages.close();
    await _nodes.close();
  }
}

class RecordingSink implements EnvelopeSink {
  final List<Envelope> envelopes = [];
  final List<int> hopCounts = [];

  @override
  Future<void> process(
    Envelope envelope, {
    required TransportSource source,
    required int hops,
  }) async {
    envelopes.add(envelope);
    hopCounts.add(hops);
  }
}

MeshMessage messageFor(String payload, {int hopCount = 0}) => MeshMessage(
  id: 'mesh-$payload',
  senderId: 'sender',
  senderName: 'Sender',
  type: MessageType.text,
  priority: MessagePriority.normal,
  payload: payload,
  hopCount: hopCount,
  createdAt: DateTime.now(),
  expiresAt: DateTime.now().add(const Duration(hours: 1)),
);

void main() {
  late FakeMeshSession session;
  late MeshTransport transport;
  late RecordingSink sink;
  late Envelope envelope;

  setUp(() async {
    session = FakeMeshSession();
    transport = MeshTransport(session: session);
    sink = RecordingSink();
    transport.setEnvelopeSink(sink);
    final sender = await DtmKeyPair.generate();
    final recipient = await DtmKeyPair.generate();
    envelope = await createEnvelopeForPubKey(
      sender: sender,
      recipientX25519PubKeyHex: await recipient.x25519PublicKeyHex,
      plaintext: 'hello',
    );
  });

  tearDown(() async {
    await transport.dispose();
    await session.dispose();
  });

  Future<void> start() =>
      transport.start(myEdPubKey: 'ed', myXPubKey: 'x', displayName: 'Me');

  group('send', () {
    test('is a no-op before start', () async {
      expect(await transport.send(envelope), isFalse);
      expect(session.sent, isEmpty);
    });

    test('wraps the envelope in the mesh payload once', () async {
      await start();
      expect(await transport.send(envelope), isTrue);
      expect(session.sent, hasLength(1));
      expect(Envelope.decode(session.sent.single).id, envelope.id);

      expect(await transport.send(envelope), isTrue);
      expect(session.sent, hasLength(1), reason: 'dedup by envelope id');
    });

    test('a failed send clears dedup so a retry can succeed', () async {
      await start();
      session.failSend = true;
      expect(await transport.send(envelope), isFalse);

      session.failSend = false;
      expect(await transport.send(envelope), isTrue);
      expect(session.sent, hasLength(1));
    });

    test('a direct-only slice is refused when the recipient is not in the mesh',
        () async {
      await start();
      expect(await transport.send(envelope, directOnly: true), isFalse);
      expect(
        session.sent,
        isEmpty,
        reason: 'a slice broadcast to strangers cannot be delivered',
      );
    });

    test('a direct-only slice goes to a known recipient node', () async {
      await start();
      session.changeNode(
        MeshNode(
          id: envelope.recipientPubKey,
          name: 'Recipient',
          lastSeen: DateTime.now(),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(await transport.send(envelope, directOnly: true), isTrue);
      expect(session.sent, hasLength(1));
    });
  });

  group('receive', () {
    test('forwards a valid frame with its hop count', () async {
      await start();
      session.deliver(messageFor(envelope.encode(), hopCount: 2));
      await Future<void>.delayed(Duration.zero);

      expect(sink.envelopes, hasLength(1));
      expect(sink.envelopes.single.id, envelope.id);
      expect(sink.hopCounts.single, 2);
    });

    test('drops frames beyond the hop ladder', () async {
      await start();
      session.deliver(
        messageFor(envelope.encode(), hopCount: maxRelayHops + 1),
      );
      await Future<void>.delayed(Duration.zero);
      expect(sink.envelopes, isEmpty);
    });

    test('drops oversized payloads before parsing', () async {
      await start();
      session.deliver(messageFor('x' * (maxFrameBytes + 1)));
      await Future<void>.delayed(Duration.zero);
      expect(sink.envelopes, isEmpty);
    });

    test('drops payloads that are not DTM envelopes', () async {
      await start();
      session.deliver(messageFor('{"hello":"mesh"}'));
      await Future<void>.delayed(Duration.zero);
      expect(sink.envelopes, isEmpty);
    });

    test('does not deliver a duplicate frame twice', () async {
      await start();
      session.deliver(messageFor(envelope.encode()));
      await Future<void>.delayed(Duration.zero);
      session.deliver(messageFor(envelope.encode()));
      await Future<void>.delayed(Duration.zero);
      expect(sink.envelopes, hasLength(1));
    });

    test('stops delivering after stop()', () async {
      await start();
      await transport.stop();
      session.deliver(messageFor(envelope.encode()));
      await Future<void>.delayed(Duration.zero);
      expect(sink.envelopes, isEmpty);
    });
  });

  group('node changes', () {
    late FakeMeshSession nodeSession;
    late MeshTransport nodeTransport;
    late List<DtmPeer> seen;

    Future<void> runWith(
      Future<bool> Function(String id)? isKnownPeer,
    ) async {
      nodeSession = FakeMeshSession();
      nodeTransport = MeshTransport(
        session: nodeSession,
        isKnownPeer: isKnownPeer,
      );
      nodeTransport.setEnvelopeSink(sink);
      seen = <DtmPeer>[];
      final sub = nodeTransport.peers.listen(seen.add);
      addTearDown(sub.cancel);
      await nodeTransport.start(
        myEdPubKey: 'ed',
        myXPubKey: 'x',
        displayName: 'Me',
      );
      nodeSession.changeNode(
        MeshNode(id: 'node-1', name: 'Nina', lastSeen: DateTime.now()),
      );
      await Future<void>.delayed(Duration.zero);
    }

    tearDown(() async {
      await nodeTransport.dispose();
      await nodeSession.dispose();
    });

    test('a node the peer book knows surfaces as a peer', () async {
      await runWith((id) async => id == 'node-1');

      expect(seen, hasLength(1));
      expect(seen.single.pubKey, 'node-1');
      expect(seen.single.displayName, 'Nina');
      expect(seen.single.online, isTrue);
      expect(nodeTransport.status.nodeCount, 1);
    });

    test('an unknown node id stays out of the peer book', () async {
      await runWith((id) async => false);

      expect(seen, isEmpty);
      expect(nodeTransport.status.nodeCount, 1,
          reason: 'the radio still heard the node');
    });

    test('a failing peer lookup swallows the node instead of crashing',
        () async {
      await runWith((id) async => throw StateError('db closed'));

      expect(seen, isEmpty);
      expect(nodeTransport.status.nodeCount, 1);
    });

    test('without a filter every node surfaces, as before', () async {
      await runWith(null);

      expect(seen, hasLength(1));
      expect(seen.single.pubKey, 'node-1');
    });
  });
}

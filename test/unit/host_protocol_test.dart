import 'package:dtm_app/core/security_limits.dart' as limits;
import 'package:dtm_app/core/sync/gossip_message.dart';
import 'package:dtm_app/models/envelope.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final hex32 = List.filled(64, 'a').join();
  final sig64 = List.filled(128, 'b').join();

  Envelope fakeEnvelope({String? id}) => Envelope(
    id: id ?? hex32,
    senderPubKey: hex32,
    recipientPubKey: hex32,
    timestamp: 1700000000000,
    ciphertext: 'Y2lwaGVy',
    ephemeralPubKey: hex32,
    signature: sig64,
  );

  group('host wire messages on GossipMessage.fromJson', () {
    test('round-trips WELCOME with identity and ENVELOPES with hops', () {
      final welcome = WelcomeMessage(
        serverTime: 1234,
        retentionSeconds: 2592000,
        maxEnvelopeSize: limits.maxFrameBytes,
        identity: hex32,
      );
      final welcomeBack = GossipMessage.fromJson(welcome.toJson());
      expect(welcomeBack, isA<WelcomeMessage>());
      expect((welcomeBack as WelcomeMessage).identity, hex32);

      final envelopes = EnvelopesMessage(
        envelopes: [fakeEnvelope()],
        done: false,
        hops: 2,
      );
      final envelopesBack = GossipMessage.fromJson(envelopes.toJson());
      expect(envelopesBack, isA<EnvelopesMessage>());
      expect(
        (envelopesBack as EnvelopesMessage).envelopes.single.id,
        hex32,
      );
      expect(envelopesBack.hops, 2);
      expect(envelopesBack.done, isFalse);
    });

    test('a missing WELCOME identity parses as null', () {
      final parsed = GossipMessage.fromJson(const {
        'type': 'WELCOME',
        'serverTime': 1,
        'retentionSeconds': 2,
        'maxEnvelopeSize': 1024,
      });
      expect((parsed as WelcomeMessage).identity, isNull);
    });

    test('clamps hostile hops values into range', () {
      final clamped = GossipMessage.fromJson(const {
        'type': 'ENVELOPES',
        'envelopes': <dynamic>[],
        'hops': 99,
      });
      expect((clamped as EnvelopesMessage).hops, limits.hostGossipMaxHops);

      final negative = GossipMessage.fromJson(const {
        'type': 'ENVELOPES',
        'envelopes': <dynamic>[],
        'hops': -7,
      });
      expect((negative as EnvelopesMessage).hops, 0);
    });

    test('rejects an oversized envelopes list', () {
      final envelopes = <Envelope>[
        for (var i = 0; i <= limits.maxGossipItems; i++) fakeEnvelope(),
      ];
      expect(
        () => GossipMessage.fromJson({
          'type': 'ENVELOPES',
          'envelopes': envelopes.map((e) => e.toJson()).toList(),
        }),
        throwsFormatException,
      );
    });

    test('rejects WELCOME without its bounded int fields', () {
      expect(
        () => GossipMessage.fromJson(const {'type': 'WELCOME'}),
        throwsFormatException,
      );
    });

    test('rejects a malformed PUBLISH and PUBLISHED', () {
      expect(
        () => GossipMessage.fromJson(const {'type': 'PUBLISH'}),
        throwsFormatException,
      );
      expect(
        () => GossipMessage.fromJson(const {'type': 'PUBLISHED'}),
        throwsFormatException,
      );
    });

    test('rejects an unknown type and a bad envelope inside PUBLISH', () {
      expect(
        () => GossipMessage.fromJson(const {'type': 'EVIL'}),
        throwsFormatException,
      );
      expect(
        () =>
            GossipMessage.fromJson(const {'type': 'PUBLISH', 'envelope': 1}),
        throwsFormatException,
      );
    });
  });

  group('tracker messages on GossipMessage.fromJson', () {
    test('round-trips HELLO with myAddrs and WELCOME with capabilities', () {
      const hello = HelloMessage(
        myPeerId: '12D3KooWRcrAhaBpAPkhKtLdFmZxnxu2zhDcbVgK9MnFvW2hw5UL',
        myAddrs: ['/ip4/10.0.2.2/tcp/5011'],
      );
      final helloBack =
          GossipMessage.fromJson(hello.toJson()) as HelloMessage;
      expect(helloBack.myAddrs, ['/ip4/10.0.2.2/tcp/5011']);

      final welcome = WelcomeMessage(
        serverTime: 0,
        retentionSeconds: 3600,
        maxEnvelopeSize: limits.maxFrameBytes,
        identity: hex32,
        capabilities: const ['dtm-tracker'],
      );
      final welcomeBack =
          GossipMessage.fromJson(welcome.toJson()) as WelcomeMessage;
      expect(welcomeBack.capabilities, ['dtm-tracker']);

      final absent = GossipMessage.fromJson({
        'type': 'HELLO',
        'myPeerId': hex32,
      }) as HelloMessage;
      expect(absent.myAddrs, isEmpty);
    });

    test('HELLO rejects an oversized or malformed myAddrs list', () {
      expect(
        () => GossipMessage.fromJson({
          'type': 'HELLO',
          'myPeerId': hex32,
          'myAddrs': [
            for (var i = 0; i <= limits.maxPeerAddrsOnWire; i++)
              '/ip4/1.2.3.4/tcp/9'
          ],
        }),
        throwsFormatException,
      );
      expect(
        () => GossipMessage.fromJson({
          'type': 'HELLO',
          'myPeerId': hex32,
          'myAddrs': ['not-a-multiaddr'],
        }),
        throwsFormatException,
      );
    });

    test('PeerRef is strict about each field', () {
      final good = PeerRef(
        xPubKey: hex32,
        peerId: '12D3KooWOTHER',
        addrs: const ['/ip4/1.2.3.4/tcp/9'],
      );
      expect(PeerRef.fromJson(good.toJson()).xPubKey, hex32);
      expect(PeerRef.fromJson(good.toJson()).addrs, ['/ip4/1.2.3.4/tcp/9']);

      final timed = PeerRef(
        xPubKey: hex32,
        peerId: '12D3KooWOTHER',
        lastSeen: 1700000000000,
      );
      expect(PeerRef.fromJson(timed.toJson()).lastSeen, 1700000000000);
      expect(
        () => PeerRef.fromJson({
          'xPubKey': hex32,
          'peerId': '12D3KooWOTHER',
          'lastSeen': 'yesterday',
        }),
        throwsFormatException,
      );
      expect(
        () => PeerRef.fromJson({
          'xPubKey': hex32,
          'peerId': '12D3KooWOTHER',
          'lastSeen': -5,
        }),
        throwsFormatException,
      );

      expect(
        () => PeerRef.fromJson(const <String, dynamic>{
          'peerId': 'x',
          'addrs': <dynamic>[],
        }),
        throwsFormatException,
      );
      expect(
        () => PeerRef.fromJson(const <String, dynamic>{
          'xPubKey': 'zz',
          'peerId': 'x',
          'addrs': <dynamic>[],
        }),
        throwsFormatException,
      );
      expect(
        () => PeerRef.fromJson(<String, dynamic>{
          'xPubKey': hex32,
          'peerId': '',
          'addrs': <dynamic>[],
        }),
        throwsFormatException,
      );
      expect(
        () => PeerRef.fromJson({
          'xPubKey': hex32,
          'peerId': 'x',
          'addrs': ['nope'],
        }),
        throwsFormatException,
      );
    });

    test('PEER_LIST drops corrupt refs but rejects an oversized list', () {
      final decoded = GossipMessage.fromJson({
        'type': 'PEER_LIST',
        'peers': [
          {'xPubKey': hex32, 'peerId': 'ok'},
          {'xPubKey': 'junk'},
          'nonsense',
        ],
        'hosts': <dynamic>[],
      }) as PeerListMessage;
      expect(decoded.peers.single.xPubKey, hex32);

      expect(
        () => GossipMessage.fromJson({
          'type': 'PEER_LIST',
          'peers': [
            for (var i = 0; i <= limits.maxTrackerPeers; i++)
              {'xPubKey': hex32, 'peerId': 'x'}
          ],
          'hosts': <dynamic>[],
        }),
        throwsFormatException,
      );
    });

    test('PEER_LIST hosts reuse the invite-dropping policy', () {
      final decoded = GossipMessage.fromJson({
        'type': 'PEER_LIST',
        'peers': <dynamic>[],
        'hosts': [
          {'addr': 'ws://example.com/ws', 'edPubKey': ''},
          {'addr': 'ftp://not-ws', 'edPubKey': ''},
          'junk',
        ],
      }) as PeerListMessage;
      expect(decoded.hosts.single.addr, 'ws://example.com/ws');
    });

    test('PRESENCE round-trips its online keys and timestamp', () {
      final hexB = List.filled(64, 'b').join();
      final restored = GossipMessage.fromJson(
        PresenceMessage(online: [hex32, hexB], at: 1700000000000).toJson(),
      ) as PresenceMessage;
      expect(restored.online, [hex32, hexB]);
      expect(restored.at, 1700000000000);
      expect(restored.toJson()['type'], 'PRESENCE');
    });

    test('PRESENCE drops non-key entries but rejects an oversized feed', () {
      final hexB = List.filled(64, 'b').join();
      final decoded = GossipMessage.fromJson({
        'type': 'PRESENCE',
        'online': [hex32, 'short', 42, null, hexB],
        'at': 1,
      }) as PresenceMessage;
      expect(decoded.online, [hex32, hexB]);

      expect(
        () => GossipMessage.fromJson({
          'type': 'PRESENCE',
          'online': [
            for (var i = 0; i <= limits.maxPresenceKeys; i++) hex32,
          ],
          'at': 1,
        }),
        throwsFormatException,
      );
    });

    test('PRESENCE rejects a missing or mistyped timestamp', () {
      expect(
        () => GossipMessage.fromJson({
          'type': 'PRESENCE',
          'online': <dynamic>[],
        }),
        throwsFormatException,
      );
      expect(
        () => GossipMessage.fromJson({
          'type': 'PRESENCE',
          'online': <dynamic>[],
          'at': 'now',
        }),
        throwsFormatException,
      );
    });
  });
}
import 'package:dtm_app/core/security_limits.dart' show maxPeerAddrs;
import 'package:dtm_app/core/transport/p2p/p2p_transport.dart';
import 'package:dtm_app/models/peer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final t0 = DateTime.utc(2026, 1, 1);

  DtmPeer peer(int i) => DtmPeer(
    pubKey: i.toString().padLeft(64, '0'),
    peerId: 'peer-$i',
    addrs: const [],
    lastSeen: t0.add(Duration(minutes: i)),
  );

  String pub(int i) => i.toString().padLeft(64, '0');

  test('the peer book is trimmed to maxActivePeers, oldest offline first',
      () {
    final transport = P2PTransport(
      ed25519SeedHex: '00' * 32,
      maxActivePeers: 2,
    );

    for (var i = 0; i < 5; i++) {
      transport.importPeer(peer(i));
    }

    expect(transport.knownPeers.map((p) => p.pubKey), [
      pub(3),
      pub(4),
    ]);
    expect(transport.findPeerByPubKey(pub(0)), isNull);
    expect(transport.findPeerByPubKey(pub(4))?.peerId, 'peer-4');
  });

  test('lowering the cap trims immediately and clamps to the ceiling', () {
    final transport = P2PTransport(
      ed25519SeedHex: '00' * 32,
      maxActivePeers: 4,
    );
    for (var i = 0; i < 4; i++) {
      transport.importPeer(peer(i));
    }

    transport.maxActivePeers = 1;
    expect(transport.knownPeers.map((p) => p.pubKey), [pub(3)]);

    transport.maxActivePeers = 5;
    expect(transport.maxActivePeers, 5);

    transport.maxActivePeers = 5000;
    expect(transport.maxActivePeers, 50);

    transport.maxActivePeers = 0;
    expect(transport.maxActivePeers, 1);
  });

  test('a re-import of a live peer neither duplicates nor evicts itself', () {
    final transport = P2PTransport(
      ed25519SeedHex: '00' * 32,
      maxActivePeers: 2,
    );
    transport.importPeer(peer(0));
    transport.importPeer(peer(1));
    transport.importPeer(peer(0));

    expect(transport.knownPeers.map((p) => p.pubKey), [pub(0), pub(1)]);
  });

  test('the default cap is a sane 25', () {
    final transport = P2PTransport(ed25519SeedHex: '00' * 32);
    expect(transport.maxActivePeers, 25);
  });

  test('a partial re-import merges, never erasing known routing', () {
    final transport = P2PTransport(
      ed25519SeedHex: '00' * 32,
      maxActivePeers: 4,
    );
    transport.importPeer(peer(0));

    final partial = DtmPeer(
      pubKey: pub(0),
      addrs: const ['/ip4/10.0.2.2/tcp/5011'],
      lastSeen: t0.add(const Duration(minutes: 9)),
    );
    transport.importPeer(partial);

    final merged = transport.findPeerByPubKey(pub(0));
    expect(merged?.peerId, 'peer-0');
    expect(merged?.addrs, ['/ip4/10.0.2.2/tcp/5011']);
  });

  test('a peer that changes its peer id drops the stale index entry', () {
    final transport = P2PTransport(ed25519SeedHex: '00' * 32);
    transport.importPeer(peer(0));
    expect(transport.findPeerByPeerId('peer-0')?.pubKey, pub(0));

    transport.importPeer(
      DtmPeer(
        pubKey: pub(0),
        peerId: 'peer-9',
        addrs: const [],
        lastSeen: t0,
      ),
    );

    expect(transport.findPeerByPeerId('peer-9')?.pubKey, pub(0));
    expect(transport.findPeerByPeerId('peer-0'), isNull);
    expect(transport.knownPeers, hasLength(1));
  });

  test('known addrs are unioned across imports, deduped and bounded', () {
    final transport = P2PTransport(ed25519SeedHex: '00' * 32);
    transport.importPeer(peer(0));
    for (var i = 0; i < maxPeerAddrs; i++) {
      final a = DtmPeer(
        pubKey: pub(0),
        addrs: ['/ip4/10.0.2.2/tcp/${4000 + i}'],
        lastSeen: t0,
      );
      transport.importPeer(a);
    }

    final merged = transport.findPeerByPubKey(pub(0));
    expect(merged?.peerId, 'peer-0');
    expect(merged?.addrs.length, maxPeerAddrs);
    expect(merged?.addrs.toSet().length, maxPeerAddrs);
  });

  group('dialTargets', () {
    test('drops addresses we advertise ourselves', () {
      final out = dialTargets(
        const [
          '/ip4/10.0.2.15/tcp/4010',
          '/ip4/10.0.2.2/tcp/5010',
          '/ip4/10.0.2.16/tcp/4010',
        ],
        {'/ip4/10.0.2.15/tcp/4010', '/ip4/10.0.2.16/tcp/4010'},
      );
      expect(out, ['/ip4/10.0.2.2/tcp/5010']);
    });

    test('returns nothing when every address is our own', () {
      final out = dialTargets(
        const ['/ip4/10.0.2.15/tcp/4010'],
        {'/ip4/10.0.2.15/tcp/4010'},
      );
      expect(out, isEmpty);
    });

    test('drops empty entries and honors the cap', () {
      final out = dialTargets(
        ['', '/ip4/10.0.0.1/tcp/4010', '/ip4/10.0.0.2/tcp/4010'],
        const {},
        max: 1,
      );
      expect(out, ['/ip4/10.0.0.1/tcp/4010']);
    });
  });
}
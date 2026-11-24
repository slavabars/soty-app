import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dart_libp2p/config/config.dart' as p2p;
import 'package:dart_libp2p/core/crypto/ed25519.dart' as lp_ed;
import 'package:dart_libp2p/core/multiaddr.dart';
import 'package:dart_libp2p/core/peer/peer_id.dart';
import 'package:dart_libp2p/dart_libp2p.dart' show Host;
import 'package:dart_libp2p/p2p/host/resource_manager/limiter.dart';
import 'package:dart_libp2p/p2p/host/resource_manager/resource_manager_impl.dart';
import 'package:dart_libp2p/p2p/transport/connection_manager.dart';
import 'package:dart_libp2p/p2p/transport/tcp_transport.dart';
import 'package:dtm_app/core/crypto/envelope_crypto.dart';
import 'package:dtm_app/core/crypto/identity_claim.dart';
import 'package:dtm_app/core/crypto/keypair.dart';
import 'package:dtm_app/core/transport/p2p/p2p_transport.dart';
import 'package:dtm_app/core/transport/transport.dart';
import 'package:dtm_app/models/envelope.dart';
import 'package:dtm_app/models/peer.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingSink implements EnvelopeSink {
  final List<Envelope> captured = [];
  final Completer<void> _first = Completer<void>();

  @override
  Future<void> process(
    Envelope envelope, {
    required TransportSource source,
    required int hops,
  }) async {
    captured.add(envelope);
    if (!_first.isCompleted) _first.complete();
  }

  Future<void> waitFirst(Duration timeout) => _first.future.timeout(timeout);
}

/// dart_libp2p's default address factory drops loopback, so the test needs a
/// routable local interface. Returns `null` when the host has none.
Future<String?> _nonLoopbackIPv4() async {
  final interfaces = await NetworkInterface.list(
    type: InternetAddressType.IPv4,
    includeLoopback: false,
  );
  for (final interface in interfaces) {
    for (final address in interface.addresses) {
      if (!address.isLoopback && address.address != '0.0.0.0') {
        return address.address;
      }
    }
  }
  return null;
}

/// A libp2p host that answers connections but never replies to the DTM
/// identify stream, modelling a hostile or broken peer.
class _SilentHost {
  _SilentHost(this.host, this.peerId);

  final Host host;
  final PeerId peerId;
}

Future<_SilentHost> _startSilentIdentifyHost(String ip, int port) async {
  final kp = await lp_ed.generateEd25519KeyPairFromSeed(
    Uint8List.fromList(List<int>.generate(32, (i) => i + 1)),
  );
  final connMgr = ConnectionManager();
  final resourceManager = ResourceManagerImpl(limiter: FixedLimiter());
  final tcp = TCPTransport(
    resourceManager: resourceManager,
    connManager: connMgr,
  );
  final host = await p2p.Libp2p.new_([
    p2p.Libp2p.identity(kp),
    p2p.Libp2p.connManager(connMgr),
    p2p.Libp2p.transport(tcp),
    p2p.Libp2p.listenAddrs([MultiAddr('/ip4/$ip/tcp/$port')]),
    p2p.Libp2p.userAgent('silent/1.0.0'),
    p2p.Libp2p.protocolVersion('dtm/1.0.0'),
  ]);
  host.setStreamHandler(identifyProtocolId, (stream, remote) async {});
  await host.start();
  return _SilentHost(host, host.id);
}

void main() {
  test(
    'outbound send delivers and both sides learn the Ed25519 binding',
    () async {
      final host = await _nonLoopbackIPv4();
      if (host == null) return;

      final kpA = await DtmKeyPair.generate();
      final kpB = await DtmKeyPair.generate();
      final claimA = await IdentityClaim.forIdentity(
        identity: kpA,
        displayName: 'A',
      );
      final claimB = await IdentityClaim.forIdentity(
        identity: kpB,
        displayName: 'B',
      );
      final edA = claimA.edPubKey;
      final xA = claimA.xPubKey;
      final edB = claimB.edPubKey;
      final xB = claimB.xPubKey;

      final a = P2PTransport(
        ed25519SeedHex: await kpA.ed25519SeedHex,
        myClaim: claimA,
        listenAddr: '/ip4/$host/tcp/45101',
      );
      final b = P2PTransport(
        ed25519SeedHex: await kpB.ed25519SeedHex,
        myClaim: claimB,
        listenAddr: '/ip4/$host/tcp/45102',
      );
      final sink = _RecordingSink();
      b.setEnvelopeSink(sink);
      addTearDown(a.dispose);
      addTearDown(b.dispose);

      await a.start(myEdPubKey: edA, myXPubKey: xA, displayName: 'A');
      await b.start(myEdPubKey: edB, myXPubKey: xB, displayName: 'B');

      a.importPeer(
        DtmPeer(
          pubKey: xB,
          peerId: b.localPeerId,
          addrs: ['/ip4/$host/tcp/45102'],
          lastSeen: DateTime.now(),
          online: true,
        ),
      );

      final env = await createEnvelopeForPubKey(
        sender: kpA,
        recipientX25519PubKeyHex: xB,
        plaintext: 'hello over p2p',
      );
      expect(await a.send(env), isTrue);

      // A delivered direct send must leave a live connection on both ends:
      // the settings screen's "active connections" counter reads this, so 0
      // here would mean "the metric, not the network, is broken".
      expect(a.activeConnections, greaterThanOrEqualTo(1));
      expect(b.activeConnections, greaterThanOrEqualTo(1));

      await sink.waitFirst(const Duration(seconds: 20));
      final received = sink.captured.single;
      expect(received.id, env.id);

      expect(
        await decryptPayload(
          envelope: received,
          recipientX25519KeyPair: kpB.xKeyPair,
          senderEd25519PubKeyHex: edA,
        ),
        'hello over p2p',
      );

      // The identify exchange must map Ed25519<->X25519 on both ends.
      expect(
        a.knownPeers.any((p) => p.pubKey == xB && p.edPubKey == edB),
        isTrue,
      );
      expect(
        b.knownPeers.any((p) => p.pubKey == xA && p.edPubKey == edA),
        isTrue,
      );
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );

  test(
    'a peer that accepts identify but never replies cannot stall send',
    () async {
      final host = await _nonLoopbackIPv4();
      if (host == null) return;

      final silent = await _startSilentIdentifyHost(host, 45103);
      addTearDown(() => silent.host.close());

      final kpA = await DtmKeyPair.generate();
      final claimA = await IdentityClaim.forIdentity(
        identity: kpA,
        displayName: 'A',
      );
      final a = P2PTransport(
        ed25519SeedHex: await kpA.ed25519SeedHex,
        myClaim: claimA,
        listenAddr: '/ip4/$host/tcp/45104',
      );
      addTearDown(a.dispose);
      await a.start(
        myEdPubKey: claimA.edPubKey,
        myXPubKey: claimA.xPubKey,
        displayName: 'A',
      );

      final kpSilent = await DtmKeyPair.generate();
      final xSilent = await kpSilent.x25519PublicKeyHex;
      a.importPeer(
        DtmPeer(
          pubKey: xSilent,
          peerId: silent.peerId.toString(),
          addrs: ['/ip4/$host/tcp/45103'],
          lastSeen: DateTime.now(),
          online: true,
        ),
      );

      final env = await createEnvelopeForPubKey(
        sender: kpA,
        recipientX25519PubKeyHex: xSilent,
        plaintext: 'stalled',
      );
      final stopwatch = Stopwatch()..start();
      expect(await a.send(env), isFalse);
      stopwatch.stop();
      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 40)));
    },
    timeout: const Timeout(Duration(seconds: 90)),
  );

  test('a failed dial and a stop take the peer offline again', () async {
    final host = await _nonLoopbackIPv4();
    if (host == null) return;

    final kpA = await DtmKeyPair.generate();
    final kpB = await DtmKeyPair.generate();
    final claimA = await IdentityClaim.forIdentity(
      identity: kpA,
      displayName: 'A',
    );
    final a = P2PTransport(
      ed25519SeedHex: await kpA.ed25519SeedHex,
      myClaim: claimA,
      listenAddr: '/ip4/$host/tcp/45111',
    );
    final seen = <DtmPeer>[];
    final sub = a.peers.listen(seen.add);
    addTearDown(sub.cancel);
    addTearDown(a.dispose);

    await a.start(
      myEdPubKey: claimA.edPubKey,
      myXPubKey: claimA.xPubKey,
      displayName: 'A',
    );

    const deadPeerId = 'QmDeadPeerDeadPeerDeadPeerDeadPeerDeadPeerDead';
    a.importPeer(
      DtmPeer(
        pubKey: await kpB.x25519PublicKeyHex,
        peerId: deadPeerId,
        addrs: ['/ip4/$host/tcp/45199'],
        lastSeen: DateTime.now(),
        online: true,
      ),
    );
    final xB = await kpB.x25519PublicKeyHex;
    expect(
      a.knownPeers.firstWhere((p) => p.pubKey == xB).online,
      isTrue,
    );

    final env = await createEnvelopeForPubKey(
      sender: kpA,
      recipientX25519PubKeyHex: xB,
      plaintext: 'nobody home',
    );
    expect(await a.send(env), isFalse);
    await _until(() => seen.any((p) => p.pubKey == xB && !p.online));
    expect(
      a.knownPeers.firstWhere((p) => p.pubKey == xB).online,
      isFalse,
      reason: 'a dial failure must not leave a peer pinned online',
    );

    a.importPeer(
      DtmPeer(
        pubKey: xB,
        peerId: deadPeerId,
        addrs: ['/ip4/$host/tcp/45199'],
        lastSeen: DateTime.now(),
        online: true,
      ),
    );
    await a.stop();
    expect(
      a.knownPeers.firstWhere((p) => p.pubKey == xB).online,
      isFalse,
      reason: 'stopping the transport invalidates every online claim',
    );
  }, timeout: const Timeout(Duration(seconds: 90)));
}

Future<void> _until(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException('condition not met within $timeout');
    }
    await Future<void>.delayed(const Duration(milliseconds: 25));
  }
}

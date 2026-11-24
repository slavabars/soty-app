import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_libp2p/config/config.dart' as p2p;
import 'package:dart_libp2p/core/crypto/ed25519.dart' as lp_ed;
import 'package:dart_libp2p/core/multiaddr.dart';
import 'package:dart_libp2p/core/network/context.dart';
import 'package:dart_libp2p/core/network/stream.dart';
import 'package:dart_libp2p/core/peer/addr_info.dart';
import 'package:dart_libp2p/core/peer/peer_id.dart';
import 'package:dart_libp2p/dart_libp2p.dart' show Host;
import 'package:dart_libp2p/p2p/host/resource_manager/limiter.dart';
import 'package:dart_libp2p/p2p/host/resource_manager/resource_manager_impl.dart';
import 'package:dart_libp2p/p2p/transport/connection_manager.dart';
import 'package:dart_libp2p/p2p/transport/tcp_transport.dart';
import 'package:flutter/foundation.dart';

import '../../../models/envelope.dart';
import '../../../models/peer.dart';
import '../../crypto/hex.dart' show hexToBytes;
import '../../crypto/identity_claim.dart';
import '../../security_limits.dart' as limits;
import '../../util/capped_set.dart';
import '../length_prefixed.dart';
import '../send_ledger.dart';
import '../transport.dart'
    show EnvelopeSink, PeerImportable, Transport, TransportSource;

/// libp2p protocol id for direct envelope delivery.
const String envelopeProtocolId = '/dtm/envelope/2.0.0';

/// Listen multiaddr. A fixed port (not /tcp/0) so the bound address is
/// knowable out-of-band; the Noise handshake still authenticates every
/// connection, so the fixed port leaks nothing beyond server presence.
/// Fixed TCP port the p2p transport listens on; advertised as
/// `/ip4/<lan-ip>/tcp/[p2pListenPort]` so LAN peers know where to dial.
const int p2pListenPort = 4010;

/// libp2p listen multiaddr: all interfaces so LAN peers can reach us.
const String p2pListenAddr = '/ip4/0.0.0.0/tcp/$p2pListenPort';

/// libp2p protocol id for the signed identity-claim exchange (v3).
const String identifyProtocolId = '/dtm/identify/3.0.0';

/// DHT lookup depth cap (p2p-sync skill). dart_libp2p ships no kad-dht yet, so
/// discovery currently uses import + direct identify; a DHT provider may plug
/// in here later but must never exceed this depth.
const int maxDhtLookupDepth = 3;

const Duration _rpcTimeout = Duration(seconds: 20);

/// Bound on the outbound identify reply. A peer that opens the stream but
/// never answers must not be able to stall delivery.
const Duration _identifyTimeout = Duration(seconds: 5);

/// Bound on one presence probe (dial + identify), so refreshing a dozen peers
/// cannot stall a foreground resume.
const Duration _presenceTimeout = Duration(seconds: 5);

/// Addresses of [peerAddrs] worth dialing: our own advertised addresses are
/// dropped, because connecting to ourselves succeeds at the transport level
/// and then fails when the stream opens, aborting the dial before a
/// forwarded/relay address is ever tried. Empty entries are skipped and the
/// result is bounded by [max].
List<String> dialTargets(
  List<String> peerAddrs,
  Set<String> selfAddrs, {
  int max = limits.maxPeerAddrs,
}) {
  final out = <String>[];
  for (final a in peerAddrs) {
    if (a.isEmpty || selfAddrs.contains(a)) continue;
    if (out.length >= max) break;
    out.add(a);
  }
  return out;
}

/// Online transport over libp2p: direct (Noise-authenticated,
/// Yamux-multiplexed) streams. Envelopes are opaque here — this layer never
/// decrypts.
class P2PTransport implements Transport, PeerImportable {
  final String _ed25519SeedHex;
  final String _listenAddr;
  final List<String> Function() _selfAddrs;
  final Map<String, DtmPeer> _peersByPubKey = {};
  final Map<String, DtmPeer> _peersByPeerId = {};
  final CappedSet<String> _seenIds = CappedSet();
  final CappedSet<String> _identified = CappedSet();
  final SendLedger _ledger = SendLedger();
  int _maxActivePeers;

  final _peers = StreamController<DtmPeer>.broadcast();

  EnvelopeSink? _sink;
  Host? _host;
  ConnectionManager? _connMgr;
  PeerId? _localPeerId;
  final IdentityClaim? _myClaim;
  bool _running = false;

  P2PTransport({
    required String ed25519SeedHex,
    IdentityClaim? myClaim,
    String listenAddr = p2pListenAddr,
    List<String> Function()? selfAddrs,
    int maxActivePeers = limits.maxActivePeersDefault,
  }) : _ed25519SeedHex = ed25519SeedHex,
       _myClaim = myClaim,
       _listenAddr = listenAddr,
       _selfAddrs = selfAddrs ?? _noSelfAddrs,
       _maxActivePeers =
           maxActivePeers.clamp(1, limits.maxActivePeersCeiling);

  static List<String> _noSelfAddrs() => const <String>[];

  /// Cap on the peer book; raising or dropping it re-trims immediately.
  /// Default / ceiling live in [limits.maxActivePeersDefault] and
  /// [limits.maxActivePeersCeiling].
  int get maxActivePeers => _maxActivePeers;

  set maxActivePeers(int value) {
    _maxActivePeers = value.clamp(1, limits.maxActivePeersCeiling);
    _enforceCap();
  }

  /// Live direct connections currently held open, i.e. how much of the
  /// [maxActivePeers] budget is actually in use right now. Counted by libp2p
  /// itself rather than by the peer book, so a peer that dropped its socket
  /// stops being counted without waiting for a book rewrite.
  int get activeConnections => _connMgr?.activeConnections ?? 0;

  @override
  String get name => 'p2p';

  @override
  bool get isRunning => _running;

  bool get _hostReady => _host != null && _localPeerId != null;

  @override
  Stream<DtmPeer> get peers => _peers.stream;

  /// Our libp2p peer id (for the UI status indicator).
  String? get localPeerId => _localPeerId?.toString();

  @override
  void setEnvelopeSink(EnvelopeSink sink) {
    _sink = sink;
  }

  /// Registers a peer whose public key and libp2p multiaddr are known
  /// (e.g. from a QR handshake or past contact). Partial records merge with
  /// an existing entry: a manual import with no peer id / addrs never erases
  /// the tracker-learned routing, and known addrs are unioned.
  @override
  void importPeer(DtmPeer peer) {
    if (peer.pubKey.length != 64) return;
    final prev = _peersByPubKey[peer.pubKey];
    final peerId = peer.peerId ?? prev?.peerId;
    final cleaned = peer.copyWith(
      peerId: peerId,
      addrs: _mergeAddrs(prev?.addrs ?? const [], peer.addrs),
      lastSeen: peer.lastSeen,
      online: peer.online,
    );
    _indexPeer(cleaned);
    _peers.add(cleaned);
    debugPrint(
      '[p2p] import peer=${cleaned.pubKey.substring(0, 8)} '
      'id=$peerId addrs=${cleaned.addrs}',
    );
    _enforceCap();
  }

  /// Publishes an offline record for a peer we can no longer reach. Online is
  /// live state, not history: keeping the last `true` would pin a peer as
  /// online forever after its connection went away.
  void _markOffline(String pubKey) {
    final known = _peersByPubKey[pubKey];
    if (known == null || !known.online) return;
    final updated = known.copyWith(online: false);
    _indexPeer(updated);
    _peers.add(updated);
    debugPrint('[p2p] peer offline ${updated.pubKey.substring(0, 8)}');
  }

  static List<String> _mergeAddrs(List<String> existing, List<String> added) {
    final out = <String>[];
    for (final a in [...existing, ...added]) {
      if (a.isNotEmpty && !out.contains(a)) out.add(a);
      if (out.length >= limits.maxPeerAddrs) break;
    }
    return out;
  }

  /// All peers this transport currently knows how to reach.
  List<DtmPeer> get knownPeers => _peersByPubKey.values.toList(growable: false);

  /// The peer behind [peerId], or `null` when that libp2p id is not current.
  DtmPeer? findPeerByPeerId(String peerId) => _peersByPeerId[peerId];

  /// Writes [peer] into both indexes, dropping the entry under its *previous*
  /// libp2p id. A peer that reappears with a new peer id must not stay
  /// resolvable — and thus dialable — under the old one.
  void _indexPeer(DtmPeer peer) {
    final previousId = _peersByPubKey[peer.pubKey]?.peerId;
    _peersByPubKey[peer.pubKey] = peer;
    final peerId = peer.peerId;
    if (previousId != null && previousId != peerId) {
      _peersByPeerId.remove(previousId);
    }
    if (peerId != null) _peersByPeerId[peerId] = peer;
  }

  /// Trims the book back to [maxActivePeers], evicting offline peers oldest
  /// first, then the longest-idle online ones. Ever-bounded: a flood of
  /// imports can never grow memory without bound.
  void _enforceCap() {
    while (_peersByPubKey.length > _maxActivePeers) {
      final candidates = _peersByPubKey.values.toList(growable: false)
        ..sort((a, b) {
          final aOnline = a.online ? 1 : 0;
          final bOnline = b.online ? 1 : 0;
          if (aOnline != bOnline) return aOnline - bOnline;
          return a.lastSeen.compareTo(b.lastSeen);
        });
      final victim = candidates.first;
      _peersByPubKey.remove(victim.pubKey);
      final peerId = victim.peerId;
      if (peerId != null) _peersByPeerId.remove(peerId);
    }
  }

  /// Locates a peer by its X25519 public key. DHT resolution would plug in
  /// here (capped at [maxDhtLookupDepth] hops).
  DtmPeer? findPeerByPubKey(String xPubKey) => _peersByPubKey[xPubKey];

  @override
  Future<void> start({
    required String myEdPubKey,
    required String myXPubKey,
    required String displayName,
  }) async {
    if (_host != null) {
      _running = true;
      return;
    }

    final kp = await lp_ed.generateEd25519KeyPairFromSeed(
      Uint8List.fromList(hexToBytes(_ed25519SeedHex)),
    );

    final connMgr = ConnectionManager();
    _connMgr = connMgr;
    final resourceManager = ResourceManagerImpl(limiter: FixedLimiter());
    final tcp = TCPTransport(
      resourceManager: resourceManager,
      connManager: connMgr,
    );

    final host = await p2p.Libp2p.new_([
      p2p.Libp2p.identity(kp),
      p2p.Libp2p.connManager(connMgr),
      p2p.Libp2p.transport(tcp),
      p2p.Libp2p.listenAddrs([MultiAddr(_listenAddr)]),
      p2p.Libp2p.userAgent('dtm/$displayName'),
      p2p.Libp2p.protocolVersion('dtm/3.0.0'),
      p2p.Libp2p.ping(true),
    ]);

    host.setStreamHandler(envelopeProtocolId, _handleEnvelopeStream);
    host.setStreamHandler(identifyProtocolId, _handleIdentifyStream);

    await host.start();
    _host = host;
    _localPeerId = host.id;
    _running = true;
  }

  @override
  Future<void> stop() async {
    _running = false;
    for (final pubKey in _peersByPubKey.keys.toList(growable: false)) {
      _markOffline(pubKey);
    }
    final host = _host;
    _host = null;
    _connMgr = null;
    _localPeerId = null;
    if (host != null) {
      try {
        await host.close();
      } catch (_) {
        // Already closed.
      }
    }
  }

  // -------------------------------------------------------------------------
  // Inbound streams
  // -------------------------------------------------------------------------

  Future<void> _handleEnvelopeStream(
    P2PStream<dynamic> stream,
    PeerId remotePeer,
  ) async {
    final sink = _sink;
    if (sink == null) return;

    try {
      while (true) {
        final frame = await _readFrame(stream);
        if (frame == null) break;
        Envelope? envelope;
        try {
          envelope = Envelope.decode(utf8.decode(frame));
        } catch (_) {
          continue;
        }
        if (_seenIds.add(envelope.id)) {
          final to = envelope.recipientPubKey;
          final toShort = to.isNotEmpty ? to.substring(0, 8) : '';
          debugPrint('[p2p] inbound env=${envelope.id} from=$remotePeer '
              'to=$toShort');
          await sink.process(envelope, source: TransportSource.p2p, hops: 0);
        }
      }
    } catch (_) {
      // Stream tore down mid-read.
    }
  }

  /// Reads the peer's signed [IdentityClaim] and replies with our own. A peer
  /// whose claim does not verify is never remembered (mitigates H1 in the
  /// audit: an Ed25519 identity and the X25519 key it advertises are bound).
  Future<void> _handleIdentifyStream(
    P2PStream<dynamic> stream,
    PeerId remotePeer,
  ) async {
    try {
      final frame = await _readFrame(stream);
      if (frame == null) return;
      final claim = IdentityClaim.decode(utf8.decode(frame));
      if (await claim.check() != ClaimStatus.valid) {
        unawaited(stream.closeWrite());
        unawaited(stream.reset());
        return;
      }
      final myClaim = _myClaim;
      await stream.write(framePayload(utf8.encode(myClaim?.encode() ?? '')));
      await stream.closeWrite();
      if (myClaim != null) {
        _rememberClaimedPeer(remotePeer, claim);
      }
    } catch (_) {
      try {
        await stream.reset();
      } catch (_) {}
    }
  }

  /// Reads one length-prefixed frame
  /// (`uint32BE(len) || payload`) from [stream]. Returns `null` on EOF and on
  /// any frame declared longer than [limits.maxFrameBytes].
  Future<Uint8List?> _readFrame(P2PStream<dynamic> stream) async {
    final header = await _readExactly(stream, 4);
    if (header == null || header.length < 4) return null;
    final length = frameLengthFromHeader(
      header,
      maxBytes: limits.maxFrameBytes,
    );
    if (length == null) return null;
    return _readExactly(stream, length);
  }

  /// Accumulates exactly [count] bytes from [stream]; `null` on EOF/teardown.
  Future<Uint8List?> _readExactly(P2PStream<dynamic> stream, int count) async {
    final out = BytesBuilder();
    while (out.length < count) {
      final chunk = await stream.read(count - out.length);
      if (chunk.isEmpty) return null;
      out.add(chunk);
    }
    return out.toBytes();
  }

  void _rememberClaimedPeer(
    PeerId remoteId,
    IdentityClaim claim, {
    List<String> addrs = const [],
  }) {
    final mine = _myClaim;
    if (mine != null && claim.xPubKey == mine.xPubKey) {
      debugPrint('[p2p] ignoring self claim ${claim.xPubKey.substring(0, 8)}');
      return;
    }
    final key = remoteId.toString();
    final known = _peersByPeerId[key];
    final peer = DtmPeer(
      pubKey: claim.xPubKey,
      edPubKey: claim.edPubKey,
      displayName: claim.displayName,
      peerId: key,
      addrs: addrs.isEmpty ? (known?.addrs ?? const []) : addrs,
      lastSeen: DateTime.now(),
      online: true,
    );
    _indexPeer(peer);
    _peers.add(peer);
    debugPrint(
      '[p2p] identity bound ed=${claim.edPubKey.substring(0, 8)} '
      'x=${claim.xPubKey.substring(0, 8)} id=$key',
    );
    _enforceCap();
  }

  // -------------------------------------------------------------------------
  // Outbound delivery
  // -------------------------------------------------------------------------

  @override
  Future<bool> send(Envelope envelope, {bool directOnly = false}) async {
    if (!_hostReady) return false;
    if (_ledger.isDelivered(envelope.id)) return true;

    final direct = findPeerByPubKey(envelope.recipientPubKey);
    if (direct != null) {
      final ok = await _sendToPeer(direct, envelope);
      debugPrint(
        '[p2p] direct to ${envelope.recipientPubKey.substring(0, 8)} ok=$ok',
      );
      if (ok) {
        _rememberDelivered(envelope.id);
        return true;
      }
    } else {
      debugPrint(
        '[p2p] no dialable peer for '
        '${envelope.recipientPubKey.substring(0, 8)} '
        '(book=${_peersByPubKey.length})',
      );
    }

    // A media slice is never handed to an uninvolved peer: it would be stored
    // on a device that is not part of the transfer and could leak the file.
    if (directOnly) return false;

    // Relay best-effort to every reachable online peer.
    for (final peer in _peersByPubKey.values) {
      if (peer.peerId == null) continue;
      if (peer.pubKey == envelope.senderPubKey) continue;
      if (await _sendToPeer(peer, envelope)) {
        _rememberDelivered(envelope.id);
        return true;
      }
    }
    return false;
  }

  /// Marks a hand-off as delivered and suppresses the echo of our own frame on
  /// the inbound path.
  void _rememberDelivered(String id) {
    _ledger.markDelivered(id);
    _seenIds.add(id);
  }

  Future<bool> _sendToPeer(DtmPeer peer, Envelope envelope) async {
    final peerIdStr = peer.peerId;
    final host = _host;
    if (peerIdStr == null || host == null) return false;

    try {
      final remoteId = PeerId.fromString(peerIdStr);
      // Never dial our own advertised addresses: when two hosts share a LAN
      // address (both emulators sit behind 10.0.2.15) a self-connect succeeds
      // to ourselves and the stream open then fails, aborting the dial before
      // the relay/forwarded address is ever tried.
      final self = _selfAddrs();
      final targets = dialTargets(peer.addrs, self.toSet());
      if (targets.isEmpty) {
        debugPrint('[p2p] skip dial id=$peerIdStr: only own addrs');
        return false;
      }
      final info = AddrInfo(remoteId, [
        for (final a in targets) MultiAddr(a),
      ]);

      debugPrint(
        '[p2p] dial id=$peerIdStr addrs=$targets env=${envelope.id}',
      );
      await host.connect(info, context: Context(timeout: _rpcTimeout));

      final idKey = remoteId.toString();
      if (!_identified.contains(idKey)) {
        try {
          if (await _exchangeIdentity(remoteId, peer.addrs)) {
            _identified.add(idKey);
          }
        } catch (_) {
          // Best-effort: an older peer may not speak identify yet.
        }
      }

      final stream = await host.newStream(remoteId, [
        envelopeProtocolId,
      ], Context(timeout: _rpcTimeout));
      await stream.write(framePayload(utf8.encode(envelope.encode())));
      await stream.closeWrite();

      _peers.add(peer.copyWith(lastSeen: DateTime.now(), online: true));
      debugPrint('[p2p] delivered env=${envelope.id} to $peerIdStr');
      return true;
    } catch (e) {
      debugPrint('[p2p] dial failed env=${envelope.id} to $peerIdStr: $e');
      _markOffline(peer.pubKey);
      return false;
    }
  }

  /// Dials the known peers (bounded) and exchanges identity, without sending a
  /// message, so online state and `lastSeen` refresh on launch, on resume and
  /// periodically instead of only when a message happens to be sent.
  Future<void> refreshPresence({
    int limit = limits.maxActivePeersCeiling,
  }) async {
    final host = _host;
    if (!_running || host == null) return;
    final candidates = _peersByPubKey.values
        .where((p) => p.peerId != null && p.addrs.isNotEmpty)
        .take(limit)
        .toList(growable: false);
    await Future.wait(
      candidates.map((peer) async {
        final idStr = peer.peerId;
        if (idStr == null) return;
        try {
          final remoteId = PeerId.fromString(idStr);
          final targets = dialTargets(peer.addrs, _selfAddrs().toSet());
          if (targets.isEmpty) return;
          await host.connect(
            AddrInfo(remoteId, [for (final a in targets) MultiAddr(a)]),
            context: Context(timeout: _presenceTimeout),
          );
          if (await _exchangeIdentity(remoteId, peer.addrs)) {
            _identified.add(remoteId.toString());
          }
          final updated = peer.copyWith(
            lastSeen: DateTime.now(),
            online: true,
          );
          _indexPeer(updated);
          _peers.add(updated);
        } catch (_) {
          _markOffline(peer.pubKey);
        }
      }),
    );
  }

  /// Opens an outbound identify exchange so both sides learn the Ed25519↔X25519
  /// binding even when the peer was added manually with only its X key.
  /// Returns `true` once the remote's signed claim verified and was remembered.
  Future<bool> _exchangeIdentity(PeerId remoteId, List<String> addrs) async {
    final host = _host;
    final myClaim = _myClaim;
    if (host == null || myClaim == null) return false;

    final stream = await host.newStream(remoteId, [
      identifyProtocolId,
    ], Context(timeout: _rpcTimeout));
    try {
      await stream.write(framePayload(utf8.encode(myClaim.encode())));
      await stream.closeWrite();
      final pendingRead = _readFrame(stream);
      final frame = await pendingRead.timeout(
        _identifyTimeout,
        onTimeout: () => null,
      );
      unawaited(pendingRead.catchError((Object _) => null));
      if (frame == null) return false;
      final claim = IdentityClaim.decode(utf8.decode(frame));
      if (await claim.check() != ClaimStatus.valid) return false;
      _rememberClaimedPeer(remoteId, claim, addrs: addrs);
      return true;
    } finally {
      try {
        await stream.reset();
      } catch (_) {}
    }
  }

  Future<void> dispose() async {
    await stop();
    await _peers.close();
  }
}

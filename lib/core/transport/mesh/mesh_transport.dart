import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_mesh_network/flutter_mesh_network.dart';

import '../../../models/envelope.dart';
import '../../../models/peer.dart';
import '../../security_limits.dart' as limits;
import '../../sync/envelope_processor.dart' show maxRelayHops;
import '../../util/capped_set.dart';
import '../transport.dart';
import 'mesh_permissions.dart';

/// Backend of [MeshTransport] — the real plugin or a test fake. Keeping this
/// behind an interface makes every mesh rule (dedup, hop ladder, size caps)
/// unit-testable without Bluetooth hardware.
abstract class MeshSession {
  Stream<MeshMessage> get onMessage;

  Stream<MeshNode> get onNodeChanged;

  Future<void> start({required String userId, required String userName});

  Future<void> stop();

  Future<void> sendText(String message);
}

/// Default [MeshSession] wrapping `flutter_mesh_network`'s [MeshNetwork].
class RealMeshSession implements MeshSession {
  final MeshNetwork _mesh;

  RealMeshSession({MeshConfig? config})
    : _mesh = MeshNetwork(
        config:
            config ??
            const MeshConfig(
              serviceName: 'dtm-mesh',
              maxHops: maxRelayHops + 1,
              messageTtl: Duration(hours: 6),
              enableLogging: kDebugMode,
            ),
      );

  @override
  Stream<MeshMessage> get onMessage => _mesh.onMessage;

  @override
  Stream<MeshNode> get onNodeChanged => _mesh.onNodeChanged;

  @override
  Future<void> start({required String userId, required String userName}) async {
    // The X25519 public key doubles as the stable mesh node id so peers can
    // address us by our transport key.
    await _mesh.start(userId: userId, userName: userName);
  }

  @override
  Future<void> stop() async {
    await _mesh.stop();
  }

  @override
  Future<void> sendText(String message) => _mesh.sendText(message);
}

/// Offline transport over BLE / Wi-Fi Direct via `flutter_mesh_network`.
///
/// Relay-only: envelopes are carried inside the mesh payload verbatim and are
/// never decrypted here. Dedup + hop-limit follow the mesh-transport skill.
class MeshTransport implements Transport {
  final MeshSession _session;
  final CappedSet<String> _seenIds = CappedSet();
  final _peers = StreamController<DtmPeer>.broadcast();

  EnvelopeSink? _sink;
  bool _running = false;
  StreamSubscription<MeshMessage>? _msgSub;
  StreamSubscription<MeshNode>? _nodeSub;
  final MeshPermissions _permissions;
  final Future<bool> Function(String id)? _isKnownPeer;

  /// Transport addresses seen on the mesh, newest last. Bounded: a hostile or
  /// busy environment must not grow this without limit.
  final CappedSet<String> _nodeIds = CappedSet();

  MeshPermissionStatus? _permissionStatus;
  String? _lastError;

  MeshTransport({
    MeshSession? session,
    MeshConfig? config,
    MeshPermissions? permissions,
    Future<bool> Function(String id)? isKnownPeer,
  }) : _session = session ?? RealMeshSession(config: config),
       _permissions = permissions ?? MeshPermissions(),
       _isKnownPeer = isKnownPeer;

  @override
  String get name => 'mesh';

  @override
  bool get isRunning => _running;

  @override
  Stream<DtmPeer> get peers => _peers.stream;

  /// What the offline transport is actually doing, for the settings screen
  /// and for log diagnostics. Nothing here is secret: transport addresses and
  /// platform permission names only.
  MeshStatus get status => MeshStatus(
    running: _running,
    permissions: _permissionStatus,
    nodeCount: _nodeIds.length,
    lastError: _lastError,
  );

  @override
  void setEnvelopeSink(EnvelopeSink sink) {
    _sink = sink;
    _msgSub = _session.onMessage.listen(_onMessage);
    _nodeSub = _session.onNodeChanged.listen(_onNodeChanged);
  }

  @override
  Future<void> start({
    required String myEdPubKey,
    required String myXPubKey,
    required String displayName,
  }) async {
    // Permissions first: without them the plugin starts happily and then
    // swallows every SecurityException, which reads as a working mesh that
    // simply never sees anybody.
    try {
      final status = await _permissions.request();
      _permissionStatus = status;
      debugPrint('Soty mesh permissions ok=${status.ok} $status');
    } catch (e) {
      _permissionStatus = null;
      debugPrint('Soty mesh permissions unavailable: $e');
    }
    try {
      await _session.start(userId: myXPubKey, userName: displayName);
      _running = true;
      _lastError = null;
      debugPrint('Soty mesh ready: nodes=${_nodeIds.length}');
    } catch (e) {
      _running = false;
      _lastError = e.toString();
      rethrow;
    }
  }

  @override
  Future<void> stop() async {
    _running = false;
    await _msgSub?.cancel();
    await _nodeSub?.cancel();
    await _session.stop();
  }

  @override
  Future<bool> send(Envelope envelope, {bool directOnly = false}) async {
    if (!_running) return false;
    if (directOnly && !_nodeIds.contains(envelope.recipientPubKey)) {
      // Mesh is a broadcast medium: sendText succeeds even when nobody in
      // radio range holds the file. Claiming a direct-only slice was delivered
      // would stop the caller before it tries the relay's live channel, so
      // only a recipient that actually announced itself over the mesh counts.
      return false;
    }
    if (_seenIds.contains(envelope.id)) {
      // Already relayed through the mesh — do not flood the network.
      return true;
    }
    _seenIds.add(envelope.id);
    final payload = envelope.encode();
    try {
      // A bulk slice is base64-heavy and takes much longer over BLE than a
      // text frame; the processor gives it a matching budget.
      final timeout = payload.length > 4096
          ? const Duration(seconds: 120)
          : const Duration(seconds: 15);
      await _session.sendText(payload).timeout(timeout);
      debugPrint(
        '[mesh] send dispatched id=${envelope.id} bytes=${payload.length}',
      );
      return true;
    } catch (e) {
      debugPrint('[mesh] send FAILED id=${envelope.id} err=$e');
      _seenIds.remove(envelope.id);
      return false;
    }
  }

  Future<void> _onMessage(MeshMessage msg) async {
    // Mesh library may auto-forward; enforce the hop ladder explicitly.
    if (msg.hopCount > maxRelayHops) return;

    // Reject oversized payloads before JSON parsing (H2/H4 in the audit).
    if (msg.payload.length > limits.maxFrameBytes) return;

    Envelope? envelope;
    try {
      envelope = Envelope.decode(msg.payload);
    } catch (_) {
      // Not a DTM envelope (e.g. plugin beacon) — ignore.
      return;
    }
    if (!_seenIds.add(envelope.id)) return;

    debugPrint(
      '[mesh] recv id=${envelope.id} hops=${msg.hopCount} '
      'from=${msg.senderId}',
    );

    final sink = _sink;
    if (sink != null && _running) {
      await sink.process(
        envelope,
        source: TransportSource.mesh,
        hops: msg.hopCount,
      );
    }
  }

  void _onNodeChanged(MeshNode node) {
    _nodeIds.add(node.id);
    unawaited(_publishNode(node));
  }

  /// A mesh node id is a transport address — a MAC on some radios — and only
  /// identities already imported count as peers, so a stranger's handset must
  /// not show up in the peer list just because it was heard over the mesh.
  Future<void> _publishNode(MeshNode node) async {
    final isKnown = _isKnownPeer;
    if (isKnown != null) {
      try {
        if (!await isKnown(node.id)) return;
      } catch (_) {
        return;
      }
    }
    _peers.add(
      DtmPeer(
        pubKey: node.id,
        displayName: node.name,
        lastSeen: node.lastSeen,
        online: node.isOnline(),
      ),
    );
  }

  Future<void> dispose() async {
    await stop();
    await _peers.close();
  }
}

/// Snapshot of the offline transport, so the UI can tell "mesh is off" from
/// "mesh is on but nobody is in range" without guessing from a peer count.
class MeshStatus {
  final bool running;
  final MeshPermissionStatus? permissions;
  final int nodeCount;
  final String? lastError;

  const MeshStatus({
    required this.running,
    required this.permissions,
    required this.nodeCount,
    required this.lastError,
  });

  /// True when the radio is live and allowed to use it.
  bool get usable => running && (permissions?.ok ?? true);

  @override
  String toString() =>
      'MeshStatus(running: $running, nodes: $nodeCount, '
      'permissions: $permissions, lastError: $lastError)';
}

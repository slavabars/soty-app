import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;

import '../../../models/envelope.dart';
import '../../../models/peer.dart';
import '../../host/host_link.dart';
import '../../security_limits.dart';
import '../../storage/settings_dao.dart';
import '../../sync/gossip_message.dart';
import '../../util/capped_set.dart';
import '../send_ledger.dart';
import '../transport.dart';

const Duration _connectTimeout = Duration(seconds: 8);
const Duration _ackTimeout = Duration(seconds: 5);
const Duration _reconnectBase = Duration(seconds: 2);
const Duration _reconnectMax = Duration(seconds: 60);

/// Protocol-level WebSocket ping interval. Keeps NAT/midbox sockets from going
/// idle-stale and turns silent relay drop into an exception the reconnect
/// backoff can act on within one interval.
const Duration keepAliveInterval = Duration(seconds: 25);
const String _settingsKey = 'soty.hosts';
const String _learnedKey = 'soty.learnedHosts';

/// Settings key holding the relay failover mode.
const String relayModeSettingsKey = 'soty.relayMode';

/// How the device treats relays it learned from tracker-capable hosts.
enum RelayMode {
  /// Only relays the user configured are dialed; tracker hosts are ignored.
  manual,
  /// Tracker-advertised relays join the pool, so an unreachable configured
  /// relay is replaced by whatever is still reachable.
  auto,
}

/// Tracks peers over operator-run hosts used as tracker+redundant-relay.
///
/// A host that advertises the `dtm-tracker` capability is asked for a
/// PEER_LIST; discovered peers are folded into the device-to-device transport
/// so direct connections make the host unnecessary for delivery. The host is
/// treated as untrusted storage: everything it hands back is verified by the
/// envelope pipeline (skew → signature → id) before it is stored, and the
/// client never shares more than its X25519 identity, which is public anyway.
class HostTransport implements Transport {
  final SettingsDao settings;
  final Future<int?> Function() lastTimestamp;

  /// Resolves the libp2p PeerId to advertise (HELLO myPeerId). Falls back to
  /// the Ed25519 pubkey when the p2p transport is absent.
  final String Function()? peerIdProvider;

  /// Multiaddrs the device believes it is reachable at (HELLO myAddrs).
  final List<String> Function()? advertiseAddrs;

  /// Sink for peers discovered via the tracker.
  final PeerImportable? peerImport;

  /// Current known-peer count; at or above [stopTrackerPeers] the tracker is
  /// no longer polled for peers (hosts are still kept in the pool).
  final int Function()? peerCount;
  final int stopTrackerPeers;

  /// Baked-in default host (dart-define SOTY_BOOTSTRAP_HOST): seeded into the
  /// pool when nothing else is known.
  final HostEndpoint? bootstrapHost;

  /// Relay addresses that must never be dialed again. A relay that moved to a
  /// new IP is retired here so an updated client drops the dead endpoint
  /// instead of retrying it forever; the baked-in [bootstrapHost] replaces it.
  final Set<String> retiredHosts;

  /// Consecutive failed connects before a learned host is evicted from the
  /// pool.
  final int maxHostFailures;
  final Duration reconnectBase;
  final Duration reconnectMax;

  /// Test-only: allow loopback endpoints learned from a tracker. Production
  /// clients reject them so a hostile PEER_LIST cannot probe local services.
  final bool allowLoopbackHosts;

  /// Test seam: how a host websocket is opened. The default keeps the socket
  /// alive with [keepAliveInterval] protocol pings; tests inject a stub and
  /// assert the interval is passed through.
  final Future<WebSocket> Function(String url, Duration keepAliveInterval)?
      webSocketConnector;

  final Map<String, HostEndpoint> _hosts = <String, HostEndpoint>{};
  final Map<String, _HostConnection> _conns = <String, _HostConnection>{};
  final Set<String> _learnedAddrs = <String>{};
  final SendLedger _ledger = SendLedger();
  /// Tracker peers already imported, so the import counter counts each device
  /// once. Addresses are re-imported on every peer list: a peer that had only
  /// an unreachable address when first seen would otherwise stay undialable
  /// after it joins the reachable network.
  final CappedSet<String> _discoveredPeerKeys = CappedSet<String>();

  /// Full peer state mirrored from the hosts' PRESENCE feeds, keyed by X25519
  /// pubkey. The book is kept whole because the controller replaces a peer
  /// record with whatever a transport emits: a presence update has to carry
  /// the name, peer id and addresses learned earlier, or it would wipe them.
  final Map<String, DtmPeer> _presenceBook = <String, DtmPeer>{};
  final Map<String, Set<String>> _presenceByHost = <String, Set<String>>{};

  /// Union of every connected host's current feed, i.e. the keys the relay
  /// mesh currently sees subscribed.
  final Set<String> _onlineKeys = <String>{};

  /// Created in the constructor: it replays the presence book on listen, and
  /// an instance field initializer cannot reach back into `this` to do that.
  late final StreamController<DtmPeer> _peerController;
  EnvelopeSink? _sink;
  String? _myEdPubKey;
  String? _myXPubKey;
  String? _myPeerId;
  RelayMode _relayMode = RelayMode.auto;
  bool _running = false;
  bool _stopping = false;

  /// Observability counters (tests + settings screen show them).
  int trackerRequestsSent = 0;
  int peersImported = 0;

  HostTransport({
    required this.settings,
    required this.lastTimestamp,
    this.peerIdProvider,
    this.advertiseAddrs,
    this.peerImport,
    this.peerCount,
    this.stopTrackerPeers = trackerStopPeerListCount,
    this.bootstrapHost,
    this.retiredHosts = const <String>{},
    this.maxHostFailures = hostPoolMaxFailures,
    this.reconnectBase = _reconnectBase,
    this.reconnectMax = _reconnectMax,
    this.allowLoopbackHosts = false,
    this.webSocketConnector,
  }) {
    _peerController = StreamController<DtmPeer>.broadcast(
      onListen: _replayPresence,
    );
  }

  /// The messenger subscribes to [peers] only once `start()` has already
  /// kicked off the reconnect loop, so the first presence feed can land before
  /// anyone is listening — a broadcast stream drops it, and because the peer
  /// book only ever emits *changes* the "online" state would stay invisible
  /// until the peer flickered away and back. Hand the current book to every
  /// first listener instead.
  void _replayPresence() {
    if (_peerController.isClosed) return;
    for (final peer in _presenceBook.values) {
      _peerController.add(peer);
    }
  }

  @override
  String get name => 'host';

  @override
  bool get isRunning => _running;

  @override
  Stream<DtmPeer> get peers => _peerController.stream;

  @override
  void setEnvelopeSink(EnvelopeSink sink) {
    _sink = sink;
  }

  /// Hosts the app knows about, in insertion order.
  List<HostEndpoint> get hosts => List.unmodifiable(_hosts.values);

  /// Hosts currently connected (subscribed ready for relay).
  List<HostEndpoint> get connectedHosts {
    return _hosts.values
        .where((h) => _conns[h.addr]?.connected ?? false)
        .toList(growable: false);
  }

  /// How the device treats relays learned from tracker-capable hosts.
  RelayMode get relayMode => _relayMode;

  /// Hosts shown in settings: in [RelayMode.manual] learned hosts stay
  /// remembered but never dialed, so only configured relays are visible.
  List<HostEndpoint> get visibleHosts {
    return _hosts.values
        .where(
          (h) =>
              _relayMode == RelayMode.auto ||
              !_learnedAddrs.contains(h.addr),
        )
        .toList(growable: false);
  }

  Future<void> _loadPersisted() async {
    final modeRaw = await settings.get(relayModeSettingsKey);
    _relayMode = RelayMode.values.firstWhere(
      (mode) => mode.name == modeRaw,
      orElse: () => RelayMode.auto,
    );
    final raw = await settings.get(_settingsKey);
    if (raw == null || raw.isEmpty) return;
    for (final endpoint in HostLink.decodeStoredList(raw)) {
      _hosts.putIfAbsent(endpoint.addr, () => endpoint);
    }
    final learnedRaw = await settings.get(_learnedKey);
    if (learnedRaw != null && learnedRaw.isNotEmpty) {
      final decoded = _decodeLearned(learnedRaw);
      if (decoded != null) {
        _learnedAddrs.addAll(decoded);
      }
    }
  }

  Future<void> _persistLearned() async {
    await settings.set(
      _learnedKey,
      jsonEncode(_learnedAddrs.toList(growable: false)),
    );
  }

  static List<String>? _decodeLearned(String raw) {
    final dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return null;
    }
    if (decoded is! List) return null;
    return decoded.whereType<String>().toList(growable: false);
  }

  Future<void> _persist() async {
    final payload = jsonEncode(
      _hosts.values.map((h) => h.toJson()).toList(growable: false),
    );
    await settings.set(_settingsKey, payload);
  }

  @override
  Future<void> start({
    required String myEdPubKey,
    required String myXPubKey,
    required String displayName,
  }) async {
    if (_running) return;
    _running = true;
    _stopping = false;
    _myEdPubKey = myEdPubKey;
    _myXPubKey = myXPubKey;
    final resolvedPeerId = peerIdProvider?.call();
    _myPeerId = resolvedPeerId ?? myEdPubKey;
    await _loadPersisted();
    // Union rather than seed-on-empty: an existing install already has a host
    // list, so a relay that moved would otherwise never be added. Retired
    // addresses are dropped in the same pass.
    var changed = false;
    for (final addr in retiredHosts) {
      if (_hosts.remove(addr) != null) changed = true;
      if (_learnedAddrs.remove(addr)) changed = true;
    }
    final seed = bootstrapHost;
    if (seed != null && !_hosts.containsKey(seed.addr)) {
      _hosts[seed.addr] = seed;
      changed = true;
    }
    if (changed) {
      await _persist();
      await _persistLearned();
    }
    if (_hosts.length > maxHosts) {
      final excess = _hosts.length - maxHosts;
      for (final addr in _hosts.keys.take(excess).toList(growable: false)) {
        _hosts.remove(addr);
      }
      await _persist();
    }
    for (final endpoint in _hosts.values) {
      unawaited(_ensureConnected(endpoint));
    }
  }

  /// Adds a host (e.g. from a `soty://host` deep link), persists it, and
  /// connects. Returns `false` when the endpoint is malformed or the host
  /// count ceiling is already reached.
  Future<bool> addHost(HostEndpoint endpoint) async {
    if (_hosts.containsKey(endpoint.addr)) {
      unawaited(_ensureConnected(endpoint));
      return true;
    }
    if (_hosts.length >= maxHosts) return false;
    _hosts[endpoint.addr] = endpoint;
    await _persist();
    if (_running || _stopping) {
      unawaited(_ensureConnected(endpoint));
    }
    return true;
  }

  /// Removes a host by address, persists, and tears its connection down.
  Future<void> removeHost(String addr) async {
    if (_hosts.remove(addr) == null) return;
    _learnedAddrs.remove(addr);
    await _persist();
    await _persistLearned();
    final conn = _conns.remove(addr);
    if (conn != null) {
      conn.closing = true;
      conn.reconnect?.cancel();
      final ws = conn.ws;
      if (ws != null) {
        await ws.close();
      }
      for (final pending in conn.pending.values) {
        if (!pending.isCompleted) pending.complete(false);
      }
    }
  }

  /// Applies the failover mode live. Persisting the choice is the caller's
  /// job ([AppPrefs.setRelayMode]); switching to [RelayMode.manual] drains
  /// learned connections, back to [RelayMode.auto] redials them.
  Future<void> setRelayMode(RelayMode mode) async {
    if (_relayMode == mode) return;
    _relayMode = mode;
    if (mode == RelayMode.manual) {
      for (final addr in _learnedAddrs.toList(growable: false)) {
        final conn = _conns.remove(addr);
        if (conn == null) continue;
        conn.closing = true;
        conn.reconnect?.cancel();
        final ws = conn.ws;
        if (ws != null) {
          await ws.close();
        }
        for (final pending in conn.pending.values) {
          if (!pending.isCompleted) pending.complete(false);
        }
      }
      return;
    }
    for (final endpoint in _hosts.values) {
      if (!_learnedAddrs.contains(endpoint.addr)) continue;
      if (_conns[endpoint.addr]?.connected ?? false) continue;
      unawaited(_ensureConnected(endpoint));
    }
  }

  @override
  Future<void> stop() async {
    _running = false;
    _stopping = true;
    for (final conn in _conns.values) {
      conn.closing = true;
      conn.reconnect?.cancel();
      final ws = conn.ws;
      if (ws != null) {
        await ws.close();
      }
      for (final pending in conn.pending.values) {
        if (!pending.isCompleted) pending.complete(false);
      }
    }
    _conns.clear();
    await _markAllOffline();
  }

  /// A host going away invalidates its presence claims: without a feed we can
  /// no longer vouch that the peers it listed are still reachable, so they
  /// drop back to offline instead of being shown as online forever.
  Future<void> _markAllOffline() async {
    if (_onlineKeys.isEmpty) return;
    _presenceByHost.clear();
    _recomputePresence();
  }

  @override
  Future<bool> send(Envelope envelope, {bool directOnly = false}) async {
    if (directOnly) {
      // Direct-only slices are never stored by a relay. A relay that
      // advertises dtm-live may forward one to an online subscriber.
      final live = _conns.values
          .where(
            (c) =>
                c.connected &&
                c.liveCapable &&
                c.ws != null &&
                !c.closing,
          )
          .toList(growable: false);
      if (live.isEmpty) return false;
      final answers = await Future.wait(
        live.map((conn) => _publishAndWait(conn, envelope, live: true)),
      );
      return answers.any((ok) => ok);
    }
    if (_ledger.isDelivered(envelope.id)) return true;
    final candidates = _conns.values
        .where((c) => c.connected)
        .toList(growable: false);
    if (candidates.isEmpty) return false;
    // Publish to every connected relay at once: waiting for a dead host's ack
    // before trying the healthy one is exactly the 30-second stall we had.
    final answers = await Future.wait(
      candidates.map((conn) => _publishAndWait(conn, envelope)),
    );
    final acceptedAny = answers.any((ok) => ok);
    if (acceptedAny) _ledger.markDelivered(envelope.id);
    return acceptedAny;
  }

  Future<bool> _publishAndWait(
    _HostConnection conn,
    Envelope envelope, {
    bool live = false,
  }) async {
    if (conn.ws == null) return false;
    final completer = Completer<bool>();
    conn.pending[envelope.id] = completer;
    try {
      final message = live
          ? PublishLiveMessage(envelope: envelope)
          : PublishMessage(envelope: envelope);
      conn.ws!.add(jsonEncode(message.toJson()));
    } catch (_) {
      conn.pending.remove(envelope.id);
      return false;
    }
    final ack = await completer.future.timeout(_ackTimeout, onTimeout: () {
      conn.pending.remove(envelope.id);
      return false;
    });
    conn.pending.remove(envelope.id);
    return ack;
  }

  Future<void> _ensureConnected(HostEndpoint endpoint) async {
    if (!_isRelayActive(endpoint)) return;
    var conn = _conns[endpoint.addr];
    if (conn != null && conn.connected) return;
    conn = _HostConnection(endpoint: endpoint);
    _conns[endpoint.addr] = conn;
    await _connect(conn);
  }

  bool _isRelayActive(HostEndpoint endpoint) {
    if (_relayMode == RelayMode.auto) return true;
    return !_learnedAddrs.contains(endpoint.addr);
  }

  static Future<WebSocket> _webSocketDefault(
    String url,
    Duration keepAlive,
  ) async {
    final ws = await WebSocket.connect(url);
    ws.pingInterval = keepAlive;
    return ws;
  }

  Future<void> _connect(_HostConnection conn) async {
    if (_stopping || conn.closing) return;
    if (!_isRelayActive(conn.endpoint)) return;
    conn.pinnedOk = null;
    try {
      final connector = webSocketConnector ?? _webSocketDefault;
      final ws = await connector(
        conn.endpoint.addr,
        keepAliveInterval,
      ).timeout(_connectTimeout);
      conn.ws = ws;
      conn.attempt = 0;
      final myEd = _myEdPubKey;
      if (myEd == null) {
        await ws.close();
        return;
      }
      final myPeerId = _myPeerId ?? myEd;
      final addrs = advertiseAddrs?.call() ?? const <String>[];
      ws.add(
        jsonEncode(
          HelloMessage(
            myPeerId: myPeerId,
            capabilities: const [dtmPresence],
            myAddrs: addrs.take(maxPeerAddrsOnWire).toList(growable: false),
          ).toJson(),
        ),
      );
      await for (final frame in ws) {
        if (conn.closing || _stopping) break;
        // Reject the raw frame before decoding/allocating: a hostile relay
        // must not make the client UTF-8-decode a multi-megabyte message.
        final String text;
        if (frame is String) {
          if (frame.length > maxFrameBytes) break;
          text = frame;
        } else if (frame is List<int>) {
          if (frame.length > maxFrameBytes) break;
          text = utf8.decode(frame);
        } else {
          break;
        }
        if (text.length > maxFrameBytes) break;
        final decoded = jsonDecode(text);
        if (decoded is! Map<String, dynamic>) break;
        final message = GossipMessage.fromJson(decoded);
        await _handleInbound(conn, message, ws);
      }
    } on FormatException {
      debugPrint('[host] format error, drop+reconnect');
      // Hostile/corrupt reply: drop and reconnect later.
    } on WebSocketException {
      debugPrint('[host] ws exception, reconnect');
      // Host offline.
    } catch (e) {
      debugPrint('[host] connect error: $e');
      // Timeout / any residual failure: reconnect later.
    } finally {
      conn.connected = false;
      conn.ws = null;
      _forgetPresence(conn.endpoint.addr);
      for (final pending in conn.pending.values) {
        if (!pending.isCompleted) pending.complete(false);
      }
      conn.pending.clear();
      if (!_stopping && !conn.closing) {
        _noteFailure(conn);
        final delay = _backoff(conn.attempt++);
        debugPrint('[host] reconnect in ${delay.inSeconds}s');
        conn.reconnect?.cancel();
        conn.reconnect = Timer(delay, () => unawaited(_connect(conn)));
      }
    }
  }

  /// One failed eager connect: after [maxHostFailures] in a row a host the
  /// device only knows from a tracker is dropped from the pool. Pinned or
  /// otherwise manually added hosts keep retrying.
  void _noteFailure(_HostConnection conn) {
    conn.failures++;
    if (conn.failures < maxHostFailures) return;
    if (!_learnedAddrs.contains(conn.endpoint.addr)) return;
    debugPrint('[host] evict unresponsive learned host ${conn.endpoint.addr}');
    unawaited(removeHost(conn.endpoint.addr));
  }

  Duration _backoff(int attempt) {
    final shift = attempt < 6 ? attempt : 6;
    final ms = reconnectBase.inMilliseconds * (1 << shift);
    final capped = ms > reconnectMax.inMilliseconds
        ? reconnectMax.inMilliseconds
        : ms;
    return Duration(milliseconds: capped);
  }

  Future<void> _handleInbound(
    _HostConnection conn,
    GossipMessage message,
    WebSocket ws,
  ) async {
    switch (message) {
      case WelcomeMessage(:final identity, :final capabilities):
        conn.trackerCapable = capabilities.contains('dtm-tracker');
        conn.liveCapable = capabilities.contains('dtm-live');
        if (identity != null && conn.pinnedOk == null) {
          final expected = conn.endpoint.edPubKey;
          conn.pinnedOk = expected == null || expected == identity;
          debugPrint(
            '[host] welcome identity=$identity pinned=${conn.pinnedOk}',
          );
          if (conn.pinnedOk != true) {
            await _dropAndWait(conn);
            return;
          }
          await _subscribe(conn, ws);
        }
      case PublishLiveMessage():
        // Live frames travel device → relay → device; a device never receives
        // one from a relay.
        break;
      case EnvelopesMessage(:final envelopes, :final hops):
        final sink = _sink;
        if (sink == null) return;
        for (final envelope in envelopes) {
          try {
            await sink.process(
              envelope,
              source: TransportSource.host,
              hops: hops,
            );
          } catch (e) {
            debugPrint('[host] envelope rejected: $e');
          }
        }
      case PublishedMessage(:final id, :final accepted):
        final completer = conn.pending.remove(id);
        if (completer != null && !completer.isCompleted) {
          completer.complete(accepted);
        }
      case PeerListMessage(:final peers, :final hosts):
        await _onPeerList(conn, peers, hosts);
      case PresenceMessage(:final online):
        _applyPresence(conn, online);
      case HelloMessage() || WantMessage() || HaveMessage() ||
            GetMessage() || PublishMessage() || SubscribeMessage() ||
            PeerListRequestMessage() || NetworkMessage():
        break;
    }
  }

  /// One host's presence feed is authoritative for the keys it lists and says
  /// nothing about the rest, so a peer stays online while any other host
  /// still lists it. Feeds are unioned per host into a running [online set];
  /// a peer is online while at least one connected host lists it, and goes
  /// offline the moment the last host stops listing it.
  void _applyPresence(_HostConnection conn, List<String> online) {
    _presenceByHost[conn.endpoint.addr] = online.toSet();
    _recomputePresence();
  }

  void _forgetPresence(String addr) {
    _presenceByHost.remove(addr);
    _recomputePresence();
  }

  void _recomputePresence() {
    final now = DateTime.now();
    final union = <String>{
      for (final set in _presenceByHost.values) ...set,
    };
    final cameOnline = union.difference(_onlineKeys);
    final wentOffline = _onlineKeys.difference(union);
    _onlineKeys
      ..clear()
      ..addAll(union);
    for (final key in wentOffline) {
      _emitPresence(key, online: false, at: now);
    }
    for (final key in cameOnline) {
      _emitPresence(key, online: true, at: now);
    }
  }

  void _emitPresence(String key, {required bool online, required DateTime at}) {
    if (_myXPubKey == key) return;
    final known = _presenceBook[key];
    if (known != null && known.online == online) return;
    final updated = _presenceBook[key] =
        (known ?? DtmPeer(pubKey: key, lastSeen: at)).copyWith(
          online: online,
          // Going offline keeps the last moment we had evidence it was alive.
          lastSeen: online ? at : known?.lastSeen ?? at,
        );
    if (!_peerController.isClosed) _peerController.add(updated);
  }

  /// Seeded peers become dialable, tracker-host adds grow the pool. Both are
  /// bounded: peers go through the p2p book (maxActivePeers) and hosts
  /// through [maxHosts].
  Future<void> _onPeerList(
    _HostConnection conn,
    List<PeerRef> peers,
    List<HostEndpoint> hosts,
  ) async {
    final importer = peerImport;
    final count = peerCount?.call();
    final bookFull = count != null && count >= stopTrackerPeers;
    if (importer != null && !bookFull) {
      var added = 0;
      var refreshed = 0;
      for (final ref in peers) {
        if (ref.xPubKey == _myXPubKey) continue;
        final known = _discoveredPeerKeys.contains(ref.xPubKey);
        try {
          importer.importPeer(
            DtmPeer(
              pubKey: ref.xPubKey,
              peerId: ref.peerId,
              addrs: ref.addrs,
              lastSeen: ref.lastSeen == null
                  ? DateTime.now()
                  : DateTime.fromMillisecondsSinceEpoch(
                      ref.lastSeen!,
                      isUtc: true,
                    ),
            ),
          );
          _discoveredPeerKeys.add(ref.xPubKey);
          if (known) {
            refreshed++;
          } else {
            peersImported++;
            added++;
          }
        } catch (e) {
          debugPrint('[host] import peer failed: $e');
        }
      }
      debugPrint(
        '[host] peerList peers=${peers.length} imported=$added '
        'refreshed=$refreshed',
      );
    }
    if (_relayMode != RelayMode.auto) return;
    for (final endpoint in hosts) {
      if (_hosts.containsKey(endpoint.addr)) continue;
      if (!HostEndpoint.isSafeLearnedAddr(
        endpoint.addr,
        allowLoopback: allowLoopbackHosts,
      )) {
        debugPrint('[host] refused unsafe learned endpoint: ${endpoint.addr}');
        continue;
      }
      final ok = await addHost(endpoint);
      if (!ok) continue;
      _learnedAddrs.add(endpoint.addr);
      await _persistLearned();
    }
  }

  /// Asks a tracker-capable host for peers, unless the device already knows
  /// enough devices to dial directly. In [RelayMode.auto] the request always
  /// goes out so tracker-advertised relays are learned even when the p2p book
  /// is full (peer import itself stays bounded by the book).
  void _maybeRequestDiscovery(_HostConnection conn, WebSocket ws) {
    if (!conn.trackerCapable) return;
    final count = peerCount?.call();
    if (_relayMode != RelayMode.auto &&
        count != null &&
        count >= stopTrackerPeers) {
      return;
    }
    ws.add(jsonEncode(const PeerListRequestMessage().toJson()));
    trackerRequestsSent++;
  }

  /// Re-sends our identity with the current advertised addresses on every
  /// live connection, so the trackers (and thus their peer lists) learn a
  /// changed LAN/network layout without waiting for a drop and reconnect.
  /// Used by the periodic LAN-address refresh.
  Future<void> reannounce() async {
    if (_stopping) return;
    final myEd = _myEdPubKey;
    if (myEd == null) return;
    final myPeerId = _myPeerId ?? myEd;
    final addrs = advertiseAddrs?.call() ?? const <String>[];
    final wire = addrs.take(maxPeerAddrsOnWire).toList(growable: false);
    for (final conn in _conns.values) {
      final ws = conn.ws;
      if (ws == null || !conn.connected || conn.closing) continue;
      try {
        ws.add(
          jsonEncode(
            HelloMessage(
              myPeerId: myPeerId,
              capabilities: const [dtmPresence],
              myAddrs: wire,
            ).toJson(),
          ),
        );
      } catch (_) {
        continue;
      }
      _maybeRequestDiscovery(conn, ws);
    }
  }

  Future<void> _subscribe(_HostConnection conn, WebSocket ws) async {
    final xPub = _myXPubKey;
    if (xPub == null) return;
    final since = await lastTimestamp();
    debugPrint('[host] subscribe since=$since keys=${xPub.substring(0, 8)}');
    ws.add(
      jsonEncode(
        SubscribeMessage(
          since: since ?? 0,
          keys: [xPub],
        ).toJson(),
      ),
    );
    conn.connected = true;
    conn.failures = 0;
    _maybeRequestDiscovery(conn, ws);
  }

  Future<void> _dropAndWait(_HostConnection conn) async {
    final ws = conn.ws;
    if (ws != null) {
      await ws.close();
    }
  }
}

class _HostConnection {
  final HostEndpoint endpoint;
  WebSocket? ws;
  bool connected = false;
  bool closing = false;
  int attempt = 0;
  int failures = 0;
  bool trackerCapable = false;
  bool liveCapable = false;
  bool? pinnedOk;
  Timer? reconnect;
  final Map<String, Completer<bool>> pending = {};

  _HostConnection({required this.endpoint});
}
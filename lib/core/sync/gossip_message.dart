import 'dart:convert';

import '../../models/envelope.dart';
import '../crypto/hex.dart' show isHexOfLength;
import '../host/host_link.dart' show HostEndpoint, HostLink;
import '../security_limits.dart' as limits;

/// Wire messages shared by the device gossip protocol and the federation
/// host protocol. All messages are JSON and cross a bounded frame boundary;
/// parsing is strict and rejects malformed or oversized input with
/// [FormatException] (SIG: bounded every list a remote peer drives).
sealed class GossipMessage {
  const GossipMessage();

  Map<String, dynamic> toJson();

  /// Strict parsing: malformed or oversized control messages throw
  /// [FormatException] and are dropped at the boundary (never processed).
  static GossipMessage fromJson(Map<String, dynamic> json) {
    return switch (json['type']) {
      'HELLO' => HelloMessage(
        myPeerId: _peerIdField(json),
        capabilities:
            _boundedStrings(json['capabilities'], limits.maxCapabilities),
        myAddrs: _boundedAddrs(json['myAddrs']),
        announce: _boundedAnnounce(json['announce']),
      ),
      'WELCOME' => WelcomeMessage(
        serverTime: _intField(json, 'serverTime'),
        retentionSeconds: _intField(json, 'retentionSeconds'),
        maxEnvelopeSize: _intField(json, 'maxEnvelopeSize'),
        identity: _optionalString(json, 'identity'),
        capabilities: _boundedStrings(
          json['capabilities'],
          limits.maxCapabilities,
        ),
      ),
      'WANT' => WantMessage(since: _intOrZero(json, 'since')),
      'HAVE' => HaveMessage(ids: _boundedList(json['ids'])),
      'GET' => GetMessage(ids: _boundedList(json['ids'])),
      'ENVELOPES' => EnvelopesMessage(
        envelopes: _boundedEnvelopes(json['envelopes']),
        done: _boolOrFalse(json, 'done'),
        hops: _boundedHops(json['hops']),
      ),
      'PUBLISH' => PublishMessage(envelope: _boundedEnvelope(json['envelope'])),
      'PUBLISH_LIVE' =>
        PublishLiveMessage(envelope: _boundedEnvelope(json['envelope'])),
      'PUBLISHED' => PublishedMessage(
        id: _stringField(json, 'id'),
        accepted: _boolOrFalse(json, 'accepted'),
      ),
      'SUBSCRIBE' => SubscribeMessage(
        since: _intOrZero(json, 'since'),
        keys: _boundedList(json['keys']),
      ),
      'PEER_LIST_REQUEST' => const PeerListRequestMessage(),
      'PEER_LIST' => PeerListMessage(
        peers: _boundedPeerRefs(json['peers']),
        hosts: _boundedHostEndpoints(json['hosts']),
      ),
      'NETWORK' => NetworkMessage(
        hosts: _boundedHostEndpoints(
          json['hosts'],
          cap: limits.maxFederatedHosts,
        ),
      ),
      'PRESENCE' => PresenceMessage(
        online: _presenceKeys(json['online']),
        at: _intField(json, 'at'),
      ),
      _ => throw FormatException('Unknown gossip message: ${json['type']}'),
    };
  }

  /// A HELLO peer id is persisted by the tracker and echoed in PEER_LIST,
  /// so bound it at the parser like every other remote-driven string.
  static String _peerIdField(Map<String, dynamic> json) {
    final value = _stringField(json, 'myPeerId');
    if (value.isEmpty || value.length > limits.maxPeerIdLength) {
      throw const FormatException('Gossip peer id is out of bounds');
    }
    return value;
  }

  static int _intField(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! int) {
      throw const FormatException('Gossip int field is missing or mistyped');
    }
    return value;
  }

  static String _stringField(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! String) {
      throw const FormatException('Gossip string field is missing or mistyped');
    }
    return value;
  }

  /// An optional string field: absent/`null` is allowed, another type is a
  /// protocol error (never silently dropped).
  static String? _optionalString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) return null;
    if (value is! String) {
      throw const FormatException('Gossip string field is mistyped');
    }
    return value;
  }

  /// An optional integer cursor: absent means "from the start". A value of
  /// another type is malformed input, not a default.
  static int _intOrZero(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) return 0;
    if (value is! int) {
      throw const FormatException('Gossip int field is mistyped');
    }
    return value;
  }

  /// An optional boolean flag; `false` when absent, strict when present.
  static bool _boolOrFalse(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) return false;
    if (value is! bool) {
      throw const FormatException('Gossip bool field is mistyped');
    }
    return value;
  }

  static Envelope _boundedEnvelope(dynamic raw) {
    if (raw is! Map) {
      throw const FormatException('PUBLISH envelope is missing or mistyped');
    }
    return Envelope.fromJson(raw.cast());
  }

  /// An optional list of strings. The length is checked **before** any element
  /// is touched, so a hostile frame cannot make the parser allocate its way
  /// through a huge list.
  static List<String> _boundedList(dynamic raw) {
    final list = _asList(raw, 'Gossip');
    if (list.length > limits.maxGossipItems) {
      throw const FormatException('Gossip list is too large');
    }
    final out = <String>[];
    for (final item in list) {
      if (item is! String) {
        throw const FormatException('Gossip list item is not a string');
      }
      out.add(item);
    }
    return out;
  }

  static List<Envelope> _boundedEnvelopes(dynamic raw) {
    final list = _asList(raw, 'Gossip envelope');
    if (list.length > limits.maxGossipItems) {
      throw const FormatException('Gossip envelope list is too large');
    }
    final out = <Envelope>[];
    for (final item in list) {
      if (item is! Map) {
        throw const FormatException('Gossip envelope is not an object');
      }
      out.add(Envelope.fromJson(item.cast()));
    }
    return out;
  }

  /// `null`/absent means an empty list; anything else must be a list.
  static List<dynamic> _asList(dynamic raw, String what) {
    if (raw == null) return const [];
    if (raw is! List) {
      throw FormatException('$what list is missing or mistyped');
    }
    return raw;
  }

  /// Hop metadata bounded to the federation ceiling; out-of-range values are
  /// clamped into range (a liar only shortens its own relay reach).
  static int _boundedHops(dynamic raw) {
    final value = raw is int ? raw : 0;
    if (value < 0) return 0;
    if (value > limits.hostGossipMaxHops) return limits.hostGossipMaxHops;
    return value;
  }

  /// A bounded list of opaque strings; malformed or oversized lists throw.
  static List<String> _boundedStrings(dynamic raw, int cap) {
    final list = _asList(raw, 'Gossip string');
    if (list.length > cap) {
      throw const FormatException('Gossip string list is too large');
    }
    final out = <String>[];
    for (final item in list) {
      if (item is! String) {
        throw const FormatException('Gossip string list item is not a string');
      }
      out.add(item);
    }
    return out;
  }

  /// HELLO addresses: each must be a plausible multiaddr (starts with `/`),
  /// within [limits.maxAddrLength], and the list is capped at
  /// [limits.maxPeerAddrsOnWire]. Malformed input throws at the boundary.
  static List<String> _boundedAddrs(dynamic raw) {
    final list = _asList(raw, 'HELLO addr');
    if (list.length > limits.maxPeerAddrsOnWire) {
      throw const FormatException('HELLO addr list is too large');
    }
    final out = <String>[];
    for (final item in list) {
      if (item is! String) {
        throw const FormatException('HELLO addr is not a string');
      }
      if (item.isEmpty || item.length > limits.maxAddrLength) {
        throw const FormatException('HELLO addr is out of bounds');
      }
      if (!item.startsWith('/')) {
        throw const FormatException('HELLO addr is not a multiaddr');
      }
      out.add(item);
    }
    return out;
  }

  /// A host's reachable WebSocket URL (`ws://…` / `wss://…`, bounded).
  /// Absent for devices; only federated hosts announce themselves.
  static String? _boundedAnnounce(dynamic raw) {
    if (raw == null) return null;
    if (raw is! String || raw.isEmpty || raw.length > limits.maxAddrLength) {
      throw const FormatException('HELLO announce is out of bounds');
    }
    if (!raw.startsWith('ws://') && !raw.startsWith('wss://')) {
      throw const FormatException('HELLO announce is not a ws:// URL');
    }
    return raw;
  }

  /// Tracker peer refs: nebulous entries are dropped, never fatal — a messy
  /// registry must not kill the connection.
  static List<PeerRef> _boundedPeerRefs(dynamic raw) {
    final list = _asList(raw, 'PEER_LIST peer');
    if (list.length > limits.maxTrackerPeers) {
      throw const FormatException('PEER_LIST peers list is too large');
    }
    final out = <PeerRef>[];
    for (final item in list) {
      try {
        out.add(PeerRef.fromJson((item as Map<dynamic, dynamic>).cast()));
      } on FormatException {
        // Skip the corrupt entry.
      } on TypeError {
        // Skip a non-object entry.
      }
    }
    return out;
  }

  /// Tracker-advertised hosts: reuse the invite-dropping policy, bounded.
  static List<HostEndpoint> _boundedHostEndpoints(
    dynamic raw, {
    int cap = limits.maxTrackerHosts,
  }) {
    final list = _asList(raw, 'Host');
    if (list.length > cap) {
      throw const FormatException('Host list is too large');
    }
    return HostLink.decodeStoredList(jsonEncode(list));
  }

  /// PRESENCE online keys: 32-byte hex only, and a feed wider than
  /// [limits.maxPresenceKeys] is fatal. Individual malformed keys are
  /// dropped — a hostile relay must not be able to kill a live connection
  /// with one bad entry, and a wrong key costs nothing to ignore.
  static List<String> _presenceKeys(dynamic raw) {
    final list = _asList(raw, 'PRESENCE key');
    if (list.length > limits.maxPresenceKeys) {
      throw const FormatException('PRESENCE key list is too large');
    }
    return [
      for (final item in list)
        if (item is String && isHexOfLength(item, 32)) item,
    ];
  }
}

class HelloMessage extends GossipMessage {
  final String myPeerId;
  final List<String> capabilities;

  /// Multiaddrs the peer believes it is reachable at (advertised to trackers).
  final List<String> myAddrs;

  /// The host's own reachable WebSocket URL; set only by a federated host so
  /// the network can address it back. Bounded; absent for devices.
  final String? announce;
  const HelloMessage({
    required this.myPeerId,
    this.capabilities = const [],
    this.myAddrs = const [],
    this.announce,
  });

  @override
  Map<String, dynamic> toJson() => {
    'type': 'HELLO',
    'myPeerId': myPeerId,
    'capabilities': capabilities,
    'myAddrs': myAddrs,
    if (announce != null) 'announce': announce,
  };
}

class WelcomeMessage extends GossipMessage {
  final int serverTime;
  final int retentionSeconds;
  final int maxEnvelopeSize;

  /// The signer's Ed25519 pubkey (hosts pin identity for server-auth and
  /// for host-host links). Absent in device-to-device gossip.
  final String? identity;

  /// Host capabilities; `dtm-tracker` means the host answers PEER_LIST
  /// requests (old hosts omit it and are never polled).
  final List<String> capabilities;
  const WelcomeMessage({
    required this.serverTime,
    required this.retentionSeconds,
    required this.maxEnvelopeSize,
    this.identity,
    this.capabilities = const [],
  });

  @override
  Map<String, dynamic> toJson() => {
    'type': 'WELCOME',
    'serverTime': serverTime,
    'retentionSeconds': retentionSeconds,
    'maxEnvelopeSize': maxEnvelopeSize,
    'identity': identity,
    'capabilities': capabilities,
  };
}

class WantMessage extends GossipMessage {
  final int since;
  const WantMessage({required this.since});

  @override
  Map<String, dynamic> toJson() => {'type': 'WANT', 'since': since};
}

class HaveMessage extends GossipMessage {
  final List<String> ids;
  const HaveMessage({required this.ids});

  @override
  Map<String, dynamic> toJson() => {'type': 'HAVE', 'ids': ids};
}

class GetMessage extends GossipMessage {
  final List<String> ids;
  const GetMessage({required this.ids});

  @override
  Map<String, dynamic> toJson() => {'type': 'GET', 'ids': ids};
}

class EnvelopesMessage extends GossipMessage {
  final List<Envelope> envelopes;
  final bool done;

  /// Federation relay depth already traveled (device gossip ignores it).
  final int hops;
  const EnvelopesMessage({
    required this.envelopes,
    this.done = true,
    this.hops = 0,
  });

  @override
  Map<String, dynamic> toJson() => {
    'type': 'ENVELOPES',
    'envelopes': envelopes.map((e) => e.toJson()).toList(growable: false),
    'done': done,
    'hops': hops,
  };
}

class PublishMessage extends GossipMessage {
  final Envelope envelope;
  const PublishMessage({required this.envelope});

  @override
  Map<String, dynamic> toJson() => {
    'type': 'PUBLISH',
    'envelope': envelope.toJson(),
  };
}

/// Publishes an envelope to the relay's currently connected subscribers
/// without storing it. Used for direct-only media slices: the relay forwards
/// an online recipient's slice live and keeps no copy on disk.
class PublishLiveMessage extends GossipMessage {
  final Envelope envelope;
  const PublishLiveMessage({required this.envelope});

  @override
  Map<String, dynamic> toJson() => {
    'type': 'PUBLISH_LIVE',
    'envelope': envelope.toJson(),
  };
}

class PublishedMessage extends GossipMessage {
  final String id;
  final bool accepted;
  const PublishedMessage({required this.id, this.accepted = false});

  @override
  Map<String, dynamic> toJson() => {
    'type': 'PUBLISHED',
    'id': id,
    'accepted': accepted,
  };
}

class SubscribeMessage extends GossipMessage {
  final int since;
  final List<String> keys;
  const SubscribeMessage({required this.since, required this.keys});

  @override
  Map<String, dynamic> toJson() => {
    'type': 'SUBSCRIBE',
    'since': since,
    'keys': keys,
  };
}

/// A peer a tracker vouches for: enough for a client to dial it directly
/// (libp2p PeerId + multiaddrs) and to bind identities (X25519 key).
class PeerRef {
  final String xPubKey;
  final String peerId;
  final List<String> addrs;

  /// When the tracker last saw this peer (epoch ms), when it reports one.
  final int? lastSeen;

  const PeerRef({
    required this.xPubKey,
    required this.peerId,
    this.addrs = const [],
    this.lastSeen,
  });

  factory PeerRef.fromJson(Map<String, dynamic> json) {
    final xPubKey = json['xPubKey'];
    final peerId = json['peerId'];
    final rawAddrs = json['addrs'];
    if (rawAddrs != null && rawAddrs is! List) {
      throw const FormatException('PeerRef addrs is mistyped');
    }
    final addrs = rawAddrs == null ? const <dynamic>[] : rawAddrs as List;
    if (xPubKey is! String || !isHexOfLength(xPubKey, 32)) {
      throw const FormatException('PeerRef xPubKey is not a 32-byte key');
    }
    if (peerId is! String ||
        peerId.isEmpty ||
        peerId.length > limits.maxPeerIdLength) {
      throw const FormatException('PeerRef peerId is out of bounds');
    }
    if (addrs.length > limits.maxPeerAddrsOnWire) {
      throw const FormatException('PeerRef has too many addrs');
    }
    final out = <String>[];
    for (final item in addrs) {
      if (item is! String ||
          item.isEmpty ||
          item.length > limits.maxAddrLength ||
          !item.startsWith('/')) {
        throw const FormatException('PeerRef addr is out of bounds');
      }
      out.add(item);
    }
    final rawLastSeen = json['lastSeen'];
    if (rawLastSeen != null &&
        (rawLastSeen is! int ||
            rawLastSeen < 0 ||
            rawLastSeen > limits.maxReasonableTimestamp)) {
      throw const FormatException('PeerRef lastSeen is out of bounds');
    }
    return PeerRef(
      xPubKey: xPubKey,
      peerId: peerId,
      addrs: List.unmodifiable(out),
      lastSeen: rawLastSeen as int?,
    );
  }

  Map<String, dynamic> toJson() => {
    'xPubKey': xPubKey,
    'peerId': peerId,
    'addrs': addrs,
    if (lastSeen != null) 'lastSeen': lastSeen,
  };
}

class PeerListRequestMessage extends GossipMessage {
  const PeerListRequestMessage();

  @override
  Map<String, dynamic> toJson() => {'type': 'PEER_LIST_REQUEST'};
}

/// Federation network membership: the host's known relay-network members
/// (itself included). Exchanged only between `dtm-net`-capable hosts.
class NetworkMessage extends GossipMessage {
  final List<HostEndpoint> hosts;
  const NetworkMessage({this.hosts = const []});

  @override
  Map<String, dynamic> toJson() => {
    'type': 'NETWORK',
    'hosts': hosts.map((h) => h.toJson()).toList(growable: false),
  };
}

/// Tracker answer: peers to dial plus other known hosts to pool.
class PeerListMessage extends GossipMessage {
  final List<PeerRef> peers;
  final List<HostEndpoint> hosts;
  const PeerListMessage({
    this.peers = const [],
    this.hosts = const [],
  });

  @override
  Map<String, dynamic> toJson() => {
    'type': 'PEER_LIST',
    'peers': peers.map((p) => p.toJson()).toList(growable: false),
    'hosts': hosts.map((h) => h.toJson()).toList(growable: false),
  };
}
/// HELLO capability a device announces to receive [PresenceMessage] feeds.
const String dtmPresence = 'dtm-presence';

/// Live presence from a relay host: the X25519 keys of the devices that are
/// subscribed to it right now. Only clients that announced [dtmPresence] in
/// their HELLO receive it, so an older app on a newer host keeps working.
class PresenceMessage extends GossipMessage {
  /// X25519 keys (32-byte hex) currently subscribed to the sending host,
  /// newest subscriptions first, at most [limits.maxPresenceKeys] entries.
  final List<String> online;

  /// Host clock (UTC ms) when the feed was produced.
  final int at;

  const PresenceMessage({this.online = const [], this.at = 0});

  @override
  Map<String, dynamic> toJson() => {
    'type': 'PRESENCE',
    'online': online,
    'at': at,
  };
}

/// A known DTM peer, keyed by its X25519 public key.
///
/// [peerId] is the libp2p PeerId when known; [addrs] are concrete
/// multiaddrs (e.g. `/ip4/192.168.0.5/tcp/4001/p2p/<peerId>`) so that
/// direct streams can be opened without a central registry.
///
/// [edPubKey] is the peer's Ed25519 identity key when it was learned from a
/// verified [IdentityClaim]. It lets inbound messages (signed by Ed25519) be
/// attributed to the conversation addressed by the X25519 key.
class DtmPeer {
  final String pubKey;
  final String? edPubKey;
  final String displayName;
  final String? peerId;
  final List<String> addrs;
  final DateTime lastSeen;
  final bool online;

  /// A user-facing contact (imported via invite or promoted by a chat),
  /// as opposed to a directory peer learned from a tracker.
  final bool isContact;

  /// Ed25519 key the user confirmed by comparing safety numbers, and when.
  final String? verifiedEdPubKey;
  final DateTime? verifiedAt;

  const DtmPeer({
    required this.pubKey,
    this.edPubKey,
    this.displayName = '',
    this.peerId,
    this.addrs = const [],
    required this.lastSeen,
    this.online = false,
    this.isContact = false,
    this.verifiedEdPubKey,
    this.verifiedAt,
  });

  /// The current Ed25519 binding is the one the user confirmed.
  bool get isVerified =>
      verifiedEdPubKey != null && verifiedEdPubKey == edPubKey;

  /// The user verified this peer and its Ed25519 binding is different now (or
  /// gone), which is exactly the case a safety number is meant to catch.
  bool get keyChanged => verifiedEdPubKey != null && !isVerified;

  DtmPeer copyWith({
    String? edPubKey,
    String? displayName,
    String? peerId,
    List<String>? addrs,
    DateTime? lastSeen,
    bool? online,
    bool? isContact,
    String? verifiedEdPubKey,
    DateTime? verifiedAt,
  }) {
    return DtmPeer(
      pubKey: pubKey,
      edPubKey: edPubKey ?? this.edPubKey,
      displayName: displayName ?? this.displayName,
      peerId: peerId ?? this.peerId,
      addrs: addrs ?? this.addrs,
      lastSeen: lastSeen ?? this.lastSeen,
      online: online ?? this.online,
      isContact: isContact ?? this.isContact,
      verifiedEdPubKey: verifiedEdPubKey ?? this.verifiedEdPubKey,
      verifiedAt: verifiedAt ?? this.verifiedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'pubKey': pubKey,
    if (edPubKey != null) 'edPubKey': edPubKey,
    'displayName': displayName,
    'peerId': peerId,
    'addrs': addrs,
    'lastSeen': lastSeen.toUtc().toIso8601String(),
    'online': online,
    if (isContact) 'isContact': true,
  };

  factory DtmPeer.fromJson(Map<String, dynamic> json) {
    return DtmPeer(
      pubKey: json['pubKey'] as String,
      edPubKey: json['edPubKey'] as String?,
      displayName: (json['displayName'] as String?) ?? '',
      peerId: json['peerId'] as String?,
      addrs: List<String>.from((json['addrs'] as List<dynamic>?) ?? const []),
      lastSeen: DateTime.parse(json['lastSeen'] as String).toLocal(),
      online: (json['online'] as bool?) ?? false,
      isContact: (json['isContact'] as bool?) ?? false,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is DtmPeer && other.pubKey == pubKey;

  @override
  int get hashCode => pubKey.hashCode;

  @override
  String toString() =>
      'DtmPeer(${displayName.isEmpty ? '?' : displayName}, '
      'pub: ${pubKey.substring(0, 8)}}…)';
}

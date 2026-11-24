import 'dart:convert';

import '../../models/peer.dart';
import '../crypto/hex.dart' show isHexOfLength;
import '../security_limits.dart';
import '../storage/conversation_dao.dart' show ConversationDao;

/// Identity half of a backup: the two private seeds and the display name.
///
/// Seeds are only ever inside the encrypted payload; the outer document holds
/// ciphertext and KDF parameters and nothing else.
class BackupIdentity {
  final String edSeedHex;
  final String xSeedHex;
  final String displayName;

  const BackupIdentity({
    required this.edSeedHex,
    required this.xSeedHex,
    required this.displayName,
  });

  Map<String, dynamic> toJson() => {
        'edSeedHex': edSeedHex,
        'xSeedHex': xSeedHex,
        'displayName': displayName,
      };

  factory BackupIdentity.fromJson(Object? raw) {
    final map = _asMap(raw, 'identity');
    final displayName = _string(map, 'displayName');
    if (displayName.length > maxDisplayNameLength) {
      throw const FormatException('identity name is too long');
    }
    return BackupIdentity(
      edSeedHex: _hex(map, 'edSeedHex'),
      xSeedHex: _hex(map, 'xSeedHex'),
      displayName: displayName,
    );
  }
}

/// One contact entry, including the binding the user verified (if any).
class BackupPeer {
  final String pubKey;
  final String? edPubKey;
  final String displayName;
  final String? peerId;
  final List<String> addrs;
  final int lastSeen;
  final bool isContact;
  final String? verifiedEdPubKey;
  final int? verifiedAt;

  const BackupPeer({
    required this.pubKey,
    required this.edPubKey,
    required this.displayName,
    this.peerId,
    required this.addrs,
    required this.lastSeen,
    required this.isContact,
    this.verifiedEdPubKey,
    this.verifiedAt,
  });

  factory BackupPeer.fromPeer(DtmPeer peer) => BackupPeer(
        pubKey: peer.pubKey,
        edPubKey: peer.edPubKey,
        displayName: peer.displayName,
        peerId: peer.peerId,
        addrs: peer.addrs,
        lastSeen: peer.lastSeen.toUtc().millisecondsSinceEpoch,
        isContact: peer.isContact,
        verifiedEdPubKey: peer.verifiedEdPubKey,
        verifiedAt: peer.verifiedAt?.toUtc().millisecondsSinceEpoch,
      );

  DtmPeer toPeer() => DtmPeer(
        pubKey: pubKey,
        edPubKey: edPubKey,
        displayName: displayName,
        peerId: peerId,
        addrs: addrs,
        lastSeen: DateTime.fromMillisecondsSinceEpoch(lastSeen, isUtc: true),
        isContact: isContact,
        verifiedEdPubKey: verifiedEdPubKey,
        verifiedAt: verifiedAt == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(verifiedAt!, isUtc: true),
      );

  Map<String, dynamic> toJson() => {
        'pubKey': pubKey,
        if (edPubKey != null) 'edPubKey': edPubKey,
        'displayName': displayName,
        if (peerId != null) 'peerId': peerId,
        'addrs': addrs,
        'lastSeen': lastSeen,
        'isContact': isContact,
        if (verifiedEdPubKey != null) 'verifiedEdPubKey': verifiedEdPubKey,
        if (verifiedAt != null) 'verifiedAt': verifiedAt,
      };

  factory BackupPeer.fromJson(Object? raw) {
    final map = _asMap(raw, 'peer');
    final displayName = _string(map, 'displayName');
    if (displayName.length > maxDisplayNameLength) {
      throw const FormatException('peer name is too long');
    }
    final peerId = _optionalString(map, 'peerId');
    if (peerId != null && peerId.length > maxPeerIdLength) {
      throw const FormatException('peer id is too long');
    }
    final addrs = _stringList(map, 'addrs', maxPeerAddrs);
    for (final addr in addrs) {
      if (addr.length > maxAddrLength) {
        throw const FormatException('peer address is too long');
      }
    }
    return BackupPeer(
      pubKey: _hex(map, 'pubKey'),
      edPubKey: _optionalHex(map, 'edPubKey'),
      displayName: displayName,
      peerId: peerId,
      addrs: addrs,
      lastSeen: _integer(map, 'lastSeen'),
      isContact: _bool(map, 'isContact'),
      verifiedEdPubKey: _optionalHex(map, 'verifiedEdPubKey'),
      verifiedAt: _optionalInteger(map, 'verifiedAt'),
    );
  }
}

/// The plaintext document sealed inside a backup file.
/// One chat with its roster, as stored locally.
class BackupConversation {
  final String id;
  final String kind;
  final String title;
  final int createdTs;
  final int lastTs;
  final int readAt;
  final List<({String key, String role})> members;

  const BackupConversation({
    required this.id,
    required this.kind,
    required this.title,
    required this.createdTs,
    required this.lastTs,
    required this.readAt,
    required this.members,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind,
        'title': title,
        'createdTs': createdTs,
        'lastTs': lastTs,
        'readAt': readAt,
        'members': [
          for (final member in members)
            {'key': member.key, 'role': member.role},
        ],
      };

  factory BackupConversation.fromJson(Object? raw) {
    final map = _asMap(raw, 'conversation');
    final kind = _string(map, 'kind');
    if (kind != 'dm' && kind != 'group') {
      throw const FormatException('unknown conversation kind');
    }
    final title = _string(map, 'title');
    if (title.length > maxGroupTitleLength) {
      throw const FormatException('conversation title is too long');
    }
    final rawMembers = map['members'];
    if (rawMembers is! List) {
      throw const FormatException('members must be a list');
    }
    if (rawMembers.length > maxGroupMembers) {
      throw const FormatException('too many members in a conversation');
    }
    final members = <({String key, String role})>[];
    for (final rawMember in rawMembers) {
      final member = _asMap(rawMember, 'member');
      final role = _string(member, 'role');
      if (role != ConversationDao.adminRole &&
          role != ConversationDao.memberRole) {
        throw const FormatException('unknown member role');
      }
      members.add((key: _hex(member, 'key'), role: role));
    }
    return BackupConversation(
      id: _hex(map, 'id'),
      kind: kind,
      title: title,
      createdTs: _integer(map, 'createdTs'),
      lastTs: _integer(map, 'lastTs'),
      readAt: _integer(map, 'readAt'),
      members: members,
    );
  }
}

/// One stored envelope. Ciphertext only: the backup never contains plaintext
/// except this device's own outgoing bodies, which are stored separately.
class BackupMessage {
  final String id;
  final String senderPubKey;
  final String recipientPubKey;
  final int timestamp;
  final String ciphertext;
  final String ephemeralPubKey;
  final String signature;
  final String source;
  final int hops;
  final String chainLink;
  final bool forked;
  final bool control;
  final bool groupPayload;
  final String? groupId;

  const BackupMessage({
    required this.id,
    required this.senderPubKey,
    required this.recipientPubKey,
    required this.timestamp,
    required this.ciphertext,
    required this.ephemeralPubKey,
    required this.signature,
    required this.source,
    required this.hops,
    required this.chainLink,
    required this.forked,
    required this.control,
    required this.groupPayload,
    required this.groupId,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'senderPubKey': senderPubKey,
        'recipientPubKey': recipientPubKey,
        'timestamp': timestamp,
        'ciphertext': ciphertext,
        'ephemeralPubKey': ephemeralPubKey,
        'signature': signature,
        'source': source,
        'hops': hops,
        'chainLink': chainLink,
        'forked': forked,
        'control': control,
        'groupPayload': groupPayload,
        if (groupId != null) 'groupId': groupId,
      };

  factory BackupMessage.fromJson(Object? raw) {
    final map = _asMap(raw, 'message');
    final ciphertext = _string(map, 'ciphertext');
    if (ciphertext.length > maxFrameBytes) {
      throw const FormatException('message ciphertext is too large');
    }
    return BackupMessage(
      id: _hex(map, 'id'),
      senderPubKey: _hex(map, 'senderPubKey'),
      recipientPubKey: _hex(map, 'recipientPubKey'),
      timestamp: _integer(map, 'timestamp'),
      ciphertext: ciphertext,
      ephemeralPubKey: _hex(map, 'ephemeralPubKey'),
      signature: _hex64(map, 'signature'),
      source: _string(map, 'source'),
      hops: _integer(map, 'hops'),
      chainLink: _optionalString(map, 'chainLink') ?? '',
      forked: _bool(map, 'forked'),
      control: _bool(map, 'control'),
      groupPayload: _bool(map, 'groupPayload'),
      groupId: _optionalHex(map, 'groupId'),
    );
  }
}

class BackupStatus {
  final String id;
  final int status;
  final int updatedAt;

  const BackupStatus({
    required this.id,
    required this.status,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'status': status,
        'updatedAt': updatedAt,
      };

  factory BackupStatus.fromJson(Object? raw) {
    final map = _asMap(raw, 'status');
    final status = _integer(map, 'status');
    if (status < 0 || status > 3) {
      throw const FormatException('unknown message status');
    }
    return BackupStatus(
      id: _hex(map, 'id'),
      status: status,
      updatedAt: _integer(map, 'updatedAt'),
    );
  }
}

class BackupBody {
  final String id;
  final String plaintext;
  final int timestamp;

  const BackupBody({
    required this.id,
    required this.plaintext,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'plaintext': plaintext,
        'timestamp': timestamp,
      };

  factory BackupBody.fromJson(Object? raw) {
    final map = _asMap(raw, 'body');
    final plaintext = _string(map, 'plaintext');
    if (plaintext.length > maxMediaPlaintextBytes) {
      throw const FormatException('outgoing body is too large');
    }
    return BackupBody(
      id: _hex(map, 'id'),
      plaintext: plaintext,
      timestamp: _integer(map, 'timestamp'),
    );
  }
}

/// Chats, messages, statuses and the local plaintext of our own messages.
class BackupHistory {
  final List<BackupConversation> conversations;
  final List<BackupMessage> messages;
  final List<BackupStatus> statuses;
  final List<BackupBody> bodies;

  const BackupHistory({
    required this.conversations,
    required this.messages,
    required this.statuses,
    required this.bodies,
  });

  Map<String, dynamic> toJson() => {
        'conversations': [
          for (final conversation in conversations) conversation.toJson(),
        ],
        'messages': [for (final message in messages) message.toJson()],
        'statuses': [for (final status in statuses) status.toJson()],
        'bodies': [for (final body in bodies) body.toJson()],
      };

  factory BackupHistory.fromJson(Object? raw) {
    final map = _asMap(raw, 'history');
    final conversations = _list(map, 'conversations');
    final messages = _list(map, 'messages');
    final statuses = _list(map, 'statuses');
    final bodies = _list(map, 'bodies');
    if (conversations.length > maxBackupConversations) {
      throw const FormatException('too many conversations in backup');
    }
    if (messages.length > maxBackupMessages) {
      throw const FormatException('too many messages in backup');
    }
    if (statuses.length > maxBackupMessages ||
        bodies.length > maxBackupMessages) {
      throw const FormatException('too many rows in backup history');
    }
    return BackupHistory(
      conversations: [
        for (final conversation in conversations)
          BackupConversation.fromJson(conversation),
      ],
      messages: [
        for (final message in messages) BackupMessage.fromJson(message),
      ],
      statuses: [for (final status in statuses) BackupStatus.fromJson(status)],
      bodies: [for (final body in bodies) BackupBody.fromJson(body)],
    );
  }
}

class BackupPayload {
  static const String format = 'soty-backup-payload-2';
  static const String legacyFormat = 'soty-backup-payload-1';

  final BackupIdentity identity;
  final List<BackupPeer> peers;
  final BackupHistory? history;

  const BackupPayload({
    required this.identity,
    required this.peers,
    this.history,
  });

  Map<String, dynamic> toJson() => {
        'format': format,
        'identity': identity.toJson(),
        'peers': [for (final peer in peers) peer.toJson()],
        if (history != null) 'history': history!.toJson(),
      };

  String encode() => jsonEncode(toJson());

  factory BackupPayload.decode(String raw) {
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      throw const FormatException('backup payload is not JSON');
    }
    return BackupPayload.fromJson(decoded);
  }

  factory BackupPayload.fromJson(Object? raw) {
    final map = _asMap(raw, 'payload');
    final rawFormat = map['format'];
    if (rawFormat != format && rawFormat != legacyFormat) {
      throw const FormatException('unsupported backup payload');
    }
    final peers = map['peers'];
    if (peers is! List) {
      throw const FormatException('peers must be a list');
    }
    if (peers.length > maxBackupPeers) {
      throw const FormatException('too many peers in backup');
    }
    final history = map['history'];
    return BackupPayload(
      identity: BackupIdentity.fromJson(map['identity']),
      peers: [for (final peer in peers) BackupPeer.fromJson(peer)],
      history: history == null ? null : BackupHistory.fromJson(history),
    );
  }
}

Map<String, dynamic> _asMap(Object? raw, String what) {
  if (raw is! Map<String, dynamic>) {
    throw FormatException('$what must be an object');
  }
  return raw;
}

String _string(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is! String) throw FormatException('$key must be a string');
  return value;
}

String? _optionalString(Map<String, dynamic> map, String key) {
  if (!map.containsKey(key) || map[key] == null) return null;
  return _string(map, key);
}

int _integer(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is! int) throw FormatException('$key must be an integer');
  return value;
}

int? _optionalInteger(Map<String, dynamic> map, String key) {
  if (!map.containsKey(key) || map[key] == null) return null;
  return _integer(map, key);
}

bool _bool(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is! bool) throw FormatException('$key must be a boolean');
  return value;
}

String _hex(Map<String, dynamic> map, String key) {
  final value = _string(map, key);
  if (!isHexOfLength(value, 32)) {
    throw FormatException('$key must be a 32-byte hex string');
  }
  return value.toLowerCase();
}

String _hex64(Map<String, dynamic> map, String key) {
  final value = _string(map, key);
  if (!isHexOfLength(value, 64)) {
    throw FormatException('$key must be a 64-byte hex string');
  }
  return value.toLowerCase();
}

String? _optionalHex(Map<String, dynamic> map, String key) {
  final value = _optionalString(map, key);
  if (value == null) return null;
  if (!isHexOfLength(value, 32)) {
    throw FormatException('$key must be a 32-byte hex string');
  }
  return value.toLowerCase();
}

List<Object?> _list(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is! List) throw FormatException('$key must be a list');
  return value;
}

List<String> _stringList(Map<String, dynamic> map, String key, int max) {
  final value = map[key];
  if (value is! List) throw FormatException('$key must be a list');
  if (value.length > max) throw FormatException('$key has too many items');
  final out = <String>[];
  for (final item in value) {
    if (item is! String) throw FormatException('$key must hold strings');
    out.add(item);
  }
  return out;
}

import '../../core/security_limits.dart';

enum ConversationKind { dm, group }

/// UI model of one chat. For a 1:1 conversation the natural [id] equals the
/// peer's X25519 address; groups use a random 32-byte hex id.
class ConversationView {
  const ConversationView({
    required this.id,
    required this.kind,
    required this.title,
    required this.createdTs,
    required this.lastTs,
    required this.memberKeys,
    this.unreadCount = 0,
  });

  final String id;
  final ConversationKind kind;

  /// User-set rename; empty means the UI derives the title from the peers.
  final String title;
  final int createdTs;
  final int lastTs;

  /// Participants as X25519 addresses; for 1:1 this is always [id].
  final List<String> memberKeys;

  /// Inbound messages the user has not seen yet (derived from the messages
  /// table at load time, never stored as a counter).
  final int unreadCount;

  bool get isGroup => kind == ConversationKind.group;

  static ConversationKind kindFrom(String raw) {
    return raw == 'group' ? ConversationKind.group : ConversationKind.dm;
  }

  static String kindTo(ConversationKind kind) {
    return kind == ConversationKind.group ? 'group' : 'dm';
  }

  ConversationView copyWith({String? title, int? lastTs, int? unreadCount}) {
    return ConversationView(
      id: id,
      kind: kind,
      title: title ?? this.title,
      createdTs: createdTs,
      lastTs: lastTs ?? this.lastTs,
      memberKeys: memberKeys,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}

/// Throws [ArgumentError] when [title] exceeds the security ceiling, keeping
/// every write to the conversations table within the caps.
void assertTitleInLimits(String title) {
  if (title.length > maxGroupTitleLength) {
    throw ArgumentError.value(
      title,
      'title',
      'exceeds maxGroupTitleLength $maxGroupTitleLength',
    );
  }
}
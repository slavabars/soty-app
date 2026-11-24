import '../../core/crypto/hex.dart' show isHexOfLength;

enum GroupContainerKind { message, title, roster }

/// A group message laid inside the E2EE plaintext: `g1`/`m1` + the group
/// conversation id (32-byte hex) + `\n` + payload. The envelope wire format
/// stays untouched — the container only lives under encryption.
class GroupContainer {
  final String conversationId;
  final GroupContainerKind kind;
  final String value;

  const GroupContainer({
    required this.conversationId,
    required this.kind,
    required this.value,
  });
}

class GroupPayload {
  GroupPayload._();

  static String composeMessage({
    required String conversationId,
    required String text,
  }) {
    return 'g1$conversationId\n$text';
  }

  static String composeTitle({
    required String conversationId,
    required String title,
  }) {
    return 'm1$conversationId\n$title';
  }

  /// Legacy-free roster update, kept inside the E2EE plaintext.
  static String composeRoster({
    required String conversationId,
    required String action,
    required String targetKey,
  }) {
    return 'r2$conversationId\n$action$targetKey';
  }

  /// Recognizes a group container. Ordinary text returns `null` (including
  /// text that merely starts like a container but fails the strict id/newline
  /// check — the sender-membership gate keeps such noise out of groups).
  static GroupContainer? tryParseGroup(String plaintext) {
    if (plaintext.length < 67) return null;
    final kind = switch (plaintext[0]) {
      'g' => GroupContainerKind.message,
      'm' => GroupContainerKind.title,
      _ => null,
    };
    if (kind == null || plaintext[1] != '1') return null;
    final id = plaintext.substring(2, 66);
    if (!isHexOfLength(id, 32)) return null;
    if (plaintext[66] != '\n') return null;
    return GroupContainer(
      conversationId: id,
      kind: kind,
      value: plaintext.substring(67),
    );
  }
}
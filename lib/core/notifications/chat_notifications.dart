import 'dart:async';

import '../../models/group_payload.dart';
import '../../models/message_payload.dart';
import '../sync/envelope_processor.dart';
import 'notification_service.dart';

/// Turns decrypted inbound messages into device notifications.
///
/// Kept free of Flutter/plugin imports so the mapping rules are unit-testable:
/// which peer key the tap opens, which title is shown, which messages are
/// worth a banner and single-line preview truncation.
class ChatNotifications {
  final NotificationService service;
  final Stream<DecryptedMessage> Function() onDecrypted;
  final String Function(String senderEdPubKey) resolvePeerPubKey;
  final String Function(String senderEdPubKey) resolveTitle;

  /// Resolves a group container to its conversation id and title when this
  /// device is a member of that group; `null` drops the banner entirely, so a
  /// stranger's container can never raise one. Groups are addressed by the
  /// group id, never by the member who happened to send the copy — otherwise
  /// the banner (and its tap) would land on that member's 1:1 chat.
  final ({String id, String title})? Function(String conversationId)
      resolveGroup;

  /// Whether this 1:1 chat is the one currently on screen. The old rule was
  /// "silent while the app is in the foreground", which is wrong in both
  /// directions: a message for a chat you are not looking at stays silent
  /// just because you happen to be in the app, and a message that lands in
  /// the open chat raises a banner on the screen that already shows it.
  final bool Function(String peerPubKey) isConversationVisible;

  /// Localizes the "Encrypted" placeholder shown for a message whose body the
  /// device cannot read; injected so the mapping stays free of Flutter.
  final String encryptedBody;

  /// The banner body for a media container, built from its kind. Injected so
  /// the mapping stays free of Flutter and of the translation tables.
  final String Function(MediaKind kind) mediaBody;

  StreamSubscription<DecryptedMessage>? _subscription;

  ChatNotifications({
    required this.service,
    required this.onDecrypted,
    required this.resolvePeerPubKey,
    required this.resolveTitle,
    required this.resolveGroup,
    required this.isConversationVisible,
    this.encryptedBody = '',
    this.mediaBody = defaultMediaBody,
  });

  void start() {
    _subscription = onDecrypted().listen((message) {
      unawaited(_notify(message));
    });
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  /// Drops the banner for [peerPubKey] once its chat has been read. The key
  /// is resolved the same way [_notify] resolves the sender, so a conversation
  /// stored under the Ed25519 key still cancels the notification that was
  /// posted under the owning X25519 key.
  Future<void> cancel(String peerPubKey) async {
    try {
      await service.cancelChatMessage(resolvePeerPubKey(peerPubKey));
    } catch (_) {
      // Notifications are best-effort; a platform failure must not crash.
    }
  }

  Future<void> _notify(DecryptedMessage message) async {
    final payload = MessagePayload.parse(message.plaintext);
    final text = _text(payload);
    if (text == null) return;
    final body = _body(text);
    if (body == null) return;
    final target = _target(payload, message.senderPubKey);
    if (target == null) return;
    if (isConversationVisible(target.id)) return;
    try {
      await service.showChatMessage(
        peerPubKey: target.id,
        title: target.title,
        body: body,
      );
    } catch (_) {
      // Notifications are best-effort; a platform failure must not crash.
    }
  }

  /// The conversation a message belongs to: the group it was addressed to, or
  /// the 1:1 chat with the sender. `null` when the message is not worth
  /// addressing (a group this device does not know).
  ({String id, String title})? _target(
    MessagePayload payload,
    String senderEdPubKey,
  ) {
    if (payload is GroupMessagePayload) {
      return resolveGroup(payload.conversationId);
    }
    if (payload is MediaPayload && payload.conversationId.isNotEmpty) {
      return resolveGroup(payload.conversationId);
    }
    return (
      id: resolvePeerPubKey(senderEdPubKey),
      title: resolveTitle(senderEdPubKey),
    );
  }

  /// The prose a container carries, or `null` when the container is not a
  /// message at all (a title meta or a receipt).
  String? _text(MessagePayload payload) => switch (payload) {
        DirectPayload(:final text) => text,
        TextPayload(:final text) => text,
        GroupMessagePayload(:final kind, :final value) =>
          kind == GroupContainerKind.message ? value : null,
        // A media banner is built from the kind directly, not from prose.
        MediaPayload(:final kind) => mediaBody(kind),
        FileManifestPayload(:final kind) => mediaBody(kind),
        // A slice or a chunk request is control data, never a banner.
        FileChunkPayload() => null,
        FileRequestPayload() => null,
        DroppedPayload() => null,
        ReceiptPayload() => null,
      };

  /// The text a banner should carry, or `null` when the message deserves no
  /// banner at all. The plaintext is an encrypted container (`x1 …`, `g2 …`,
  /// `t1 …`, receipts), not prose, so the raw string must never be shown: a
  /// banner that reads `g2 10977d0ac7b… <text>` tells the user nothing. Title
  /// metadata and receipts are silent, and a body the device could not decrypt
  /// says so instead of leaking the placeholder glyph.
  String? _body(String text) {
    if (text == encryptedPlaceholder) {
      return encryptedBody.isEmpty ? null : encryptedBody;
    }
    return _preview(text);
  }

  /// Banners fit one line: newlines become spaces and the line is bounded to
  /// roughly one screen width.
  static String _preview(String plaintext) {
    final oneLine = plaintext.replaceAll('\n', ' ').trim();
    return oneLine.length <= 92 ? oneLine : '${oneLine.substring(0, 92)}…';
  }
}

/// What `UiMessage` shows when a body cannot be read. Kept in one place so the
/// notifier can recognize it and substitute [ChatNotifications.encryptedBody].
const String encryptedPlaceholder = '🔒 Encrypted';

/// The fallback banner body of a media container, used when no translation
/// is injected.
String defaultMediaBody(MediaKind kind) =>
    kind == MediaKind.voice
        ? 'Voice message'
        : kind == MediaKind.video
            ? 'Video'
            : kind == MediaKind.file
                ? 'File'
                : 'Photo';
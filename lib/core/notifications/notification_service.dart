/// Whether the platform can deliver a banner right now.
enum NotificationAvailability {
  /// Not probed yet: the notifier is still starting up.
  unknown,

  /// Banners are expected to show, with sound.
  ready,

  /// The OS has notifications switched off for this app.
  blocked,

  /// The notifier itself failed to start; [NotificationService.lastError]
  /// carries the platform reason.
  unavailable,

  /// No notifier exists for this platform.
  unsupported,
}

/// Outcome of [NotificationService.sendTest].
enum NotificationTestResult { sent, blocked, unavailable, unsupported }

/// Platform notification surface, abstracted so tests can substitute a fake.
abstract class NotificationService {
  /// Prepares the platform (permissions, channel, cold-start launch tap).
  ///
  /// [actionLabel] is the text a notification server shows for the action that
  /// opens the chat; it is localized by the caller because the notifier has
  /// no access to the app's locale.
  Future<void> initialize({String? actionLabel});

  /// Shows a notification for a new peer message. [peerPubKey] becomes the
  /// tap payload that opens the conversation.
  Future<void> showChatMessage({
    required String peerPubKey,
    required String title,
    required String body,
  });

  /// Removes the chat's notification once its messages are read, so a banner
  /// the user already opened cannot linger in the shade for its full timeout.
  Future<void> cancelChatMessage(String peerPubKey);

  /// Fires with the peer pub key whenever a notification is tapped.
  Stream<String> get onNotificationTap;

  /// Probes the platform. Cheap enough to call whenever the settings screen
  /// opens or returns from the system notification settings.
  Future<NotificationAvailability> availability();

  /// Posts a banner with a fixed payload so the user (and we) can see whether
  /// the platform shows anything at all. [title] and [body] are localized by
  /// the caller, since the notifier has no locale of its own.
  Future<NotificationTestResult> sendTest({
    required String title,
    required String body,
  });

  /// Why the last platform call failed, empty when it succeeded. Shown in
  /// settings: a notification that silently never appears is impossible to
  /// report, and in release builds there is no log to fall back on.
  String get lastError;

  /// Whether the OS exposes a screen where this app's notifications are
  /// switched on. Only Android does; a Linux desktop has no per-app screen, so
  /// offering the button there would be a dead end.
  bool get canOpenSystemSettings;

  /// Opens the OS screen where notifications are switched on. No-op where the
  /// platform has no such screen.
  Future<void> openSystemSettings();

  Future<void> dispose();
}

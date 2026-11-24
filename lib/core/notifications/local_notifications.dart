import 'dart:async';

import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'notification_service.dart';

/// flutter_local_notifications-backed [NotificationService] for Android and
/// Linux. Both platforms are fed by the same [details]: Android through its
/// channel, Linux through `org.freedesktop.Notifications` on the session bus.
class LocalNotificationService implements NotificationService {
  /// Android fixes a channel's sound and importance when the channel is first
  /// created and never lets the app change them afterwards. A channel created
  /// by a build whose notification chime the resource shrinker stripped is
  /// therefore silent for good, so the id is versioned: a new build announces
  /// itself on a fresh channel and the broken one is left unused instead of
  /// needing a destructive migration.
  static const String channelId = 'soty_messages_v3';

  static const String channelName = 'Soty messages';

  static const String channelDescription =
      'New messages from your Soty contacts';

  /// Brand teal, so the banner is visibly ours and not a grey system toast.
  static const Color _accent = Color(0xFF00897B);

  /// The chime, relative to the Flutter assets directory. Android plays the
  /// very same file as a raw resource; the freedesktop notifier can only name
  /// a file inside `data/flutter_assets`, so it is declared as an asset too.
  static const String soundAsset = 'assets/soty_chime.ogg';

  /// Action key for the tap that opens the chat, and the default action name
  /// a Linux notification server shows for the banner itself.
  static const String actionKey = 'open';
  static const String defaultActionLabel = 'Open';

  /// Id of the banner posted by [sendTest]; kept clear of the per-peer ids
  /// (first 8 hex chars of a pub key) so a probe never replaces a real one.
  static const int testNotificationId = 0x50e7;

  /// Exposed so tests can assert the alert profile without a device.
  static const AndroidNotificationChannel channel = AndroidNotificationChannel(
    channelId,
    channelName,
    description: channelDescription,
    importance: Importance.high,
    sound: RawResourceAndroidNotificationSound('soty_chime'),
    enableVibration: true,
    playSound: true,
    showBadge: true,
  );

  /// Exposed so tests can assert the alert profile without a device. Not a
  /// const: the freedesktop sound model takes a non-const path.
  static final NotificationDetails details = NotificationDetails(
    android: const AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.message,
      visibility: NotificationVisibility.private,
      color: _accent,
      colorized: false,
      ticker: channelName,
      playSound: true,
      enableVibration: true,
      showWhen: true,
      // A second message in the same chat must alert again even while the
      // previous banner for that chat is still on screen.
      onlyAlertOnce: false,
      sound: RawResourceAndroidNotificationSound('soty_chime'),
    ),
    linux: LinuxNotificationDetails(
      category: LinuxNotificationCategory.imReceived,
      urgency: LinuxNotificationUrgency.critical,
      // Not const: the freedesktop sound model has no const constructor.
      // ignore: prefer_const_constructors
      sound: AssetsLinuxSound(soundAsset),
    ),
  );

  /// Linux needs its own settings block: without it the plugin's D-Bus client
  /// is never registered and every `show` is dropped silently, because the
  /// platform never had initialization settings to work with.
  static InitializationSettings initializationSettings({
    String actionLabel = defaultActionLabel,
  }) => InitializationSettings(
    android: const AndroidInitializationSettings('@mipmap/ic_launcher'),
    linux: LinuxInitializationSettings(
      defaultActionName: actionLabel,
      defaultSound: AssetsLinuxSound(soundAsset),
    ),
  );

  static const MethodChannel _settingsChannel =
      MethodChannel('ru.dcns.soty/system_settings');

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final StreamController<String> _taps =
      StreamController<String>.broadcast();

  String _lastError = '';
  bool _initialized = false;

  @override
  Stream<String> get onNotificationTap => _taps.stream;

  @override
  String get lastError => _lastError;

  @override
  Future<void> initialize({String? actionLabel}) async {
    try {
      await _plugin.initialize(
        settings: initializationSettings(
          actionLabel: actionLabel ?? defaultActionLabel,
        ),
        onDidReceiveNotificationResponse: (response) {
          final peer = response.payload;
          if (peer != null && peer.isNotEmpty) _taps.add(peer);
        },
      );
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        await android.requestNotificationsPermission();
        await android.createNotificationChannel(channel);
        // Cold start from a notification tap: surface the payload once. The
        // freedesktop build has no such notion, and asking the platform
        // anyway throws UnimplementedError there, which would leave the whole
        // notifier looking broken.
        final launched = await android.getNotificationAppLaunchDetails();
        if (launched?.didNotificationLaunchApp ?? false) {
          final payload = launched?.notificationResponse?.payload;
          if (payload != null && payload.isNotEmpty) _taps.add(payload);
        }
      }
      _initialized = true;
      _lastError = '';
    } catch (error) {
      _initialized = false;
      _record(error);
    }
  }

  /// Stable per-peer notification id (first 8 hex chars of the pub key), so a
  /// new message replaces the same chat's previous banner while two different
  /// chats never collide. Long enough to stay under the 32-bit id cap and
  /// short enough to skip a peer book whose keys are not hex.
  @visibleForTesting
  static int notificationId(String peerPubKey) {
    final prefix = peerPubKey.length >= 8 ? peerPubKey.substring(0, 8) : '';
    final parsed = int.tryParse(prefix, radix: 16);
    // Android ids are 32-bit signed; keep the top bit clear so the value
    // survives the trip to Java unchanged.
    if (parsed != null) return parsed & 0x7fffffff;
    var hash = 0;
    for (final unit in peerPubKey.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return hash;
  }

  @override
  Future<void> showChatMessage({
    required String peerPubKey,
    required String title,
    required String body,
  }) async {
    try {
      await _plugin.show(
        id: notificationId(peerPubKey),
        title: title,
        body: body,
        notificationDetails: details,
        payload: peerPubKey,
      );
      _lastError = '';
    } catch (error) {
      _record(error);
    }
  }

  @override
  Future<void> cancelChatMessage(String peerPubKey) async {
    try {
      await _plugin.cancel(id: notificationId(peerPubKey));
    } catch (error) {
      _record(error);
    }
  }

  @override
  Future<NotificationAvailability> availability() async {
    if (!_initialized) {
      return _lastError.isEmpty
          ? NotificationAvailability.unknown
          : NotificationAvailability.unavailable;
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android == null) return NotificationAvailability.unsupported;
      final allowed = await android.areNotificationsEnabled();
      return allowed == true
          ? NotificationAvailability.ready
          : NotificationAvailability.blocked;
    }
    if (defaultTargetPlatform == TargetPlatform.linux) {
      final linux = _plugin.resolvePlatformSpecificImplementation<
          LinuxFlutterLocalNotificationsPlugin>();
      if (linux == null) return NotificationAvailability.unsupported;
      try {
        // A session bus is the other half of D-Bus: no bus, no notifications.
        await linux.getCapabilities();
        return NotificationAvailability.ready;
      } catch (error) {
        _record(error);
        return NotificationAvailability.unavailable;
      }
    }
    return NotificationAvailability.unsupported;
  }

  @override
  Future<NotificationTestResult> sendTest({
    required String title,
    required String body,
  }) async {
    final state = await availability();
    if (state == NotificationAvailability.blocked) {
      return NotificationTestResult.blocked;
    }
    if (state == NotificationAvailability.unsupported) {
      return NotificationTestResult.unsupported;
    }
    try {
      await _plugin.show(
        id: testNotificationId,
        title: title,
        body: body,
        notificationDetails: details,
        payload: '',
      );
      _lastError = '';
      return NotificationTestResult.sent;
    } catch (error) {
      _record(error);
      return NotificationTestResult.unavailable;
    }
  }

  @override
  bool get canOpenSystemSettings =>
      defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<void> openSystemSettings() async {
    if (!canOpenSystemSettings) return;
    try {
      await _settingsChannel.invokeMethod<void>('openAppNotificationSettings');
    } catch (error) {
      _record(error);
    }
  }

  /// Keeps the reason on screen instead of only in a log that release builds
  /// do not print: a notification that silently never appears otherwise looks
  /// exactly like a working one.
  void _record(Object error) {
    final text = error.toString().replaceAll('\n', ' ').trim();
    _lastError = text.length <= 200 ? text : '${text.substring(0, 200)}…';
  }

  @override
  Future<void> dispose() => _taps.close();
}

/// A no-op [NotificationService]; used on platforms without a notifier.
class NoopNotificationService implements NotificationService {
  NoopNotificationService();

  @override
  Stream<String> get onNotificationTap => const Stream<String>.empty();

  @override
  String get lastError => '';

  @override
  Future<void> initialize({String? actionLabel}) async {}

  @override
  Future<NotificationAvailability> availability() async =>
      NotificationAvailability.unsupported;

  @override
  Future<NotificationTestResult> sendTest({
    required String title,
    required String body,
  }) async => NotificationTestResult.unsupported;

  @override
  bool get canOpenSystemSettings => false;

  @override
  Future<void> openSystemSettings() async {}

  @override
  Future<void> showChatMessage({
    required String peerPubKey,
    required String title,
    required String body,
  }) async {}

  @override
  Future<void> cancelChatMessage(String peerPubKey) async {}

  @override
  Future<void> dispose() async {}
}

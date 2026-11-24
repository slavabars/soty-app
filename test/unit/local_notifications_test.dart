import 'dart:io';

import 'package:dtm_app/core/notifications/local_notifications.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

/// The user's complaint was "nothing arrives on my phone at all", and the cause
/// was a release-only resource stripper that silently deleted the notification
/// chime. These tests pin the two properties that keep alerts alive across
/// upgrades: a fresh, versioned channel id (a channel frozen without a sound by
/// an older build can never be repaired), and an alert profile that asks for
/// sound + vibration + a message category.
void main() {
  group('LocalNotificationService channel', () {
    test('uses a versioned channel id, never a legacy one', () {
      // v1 shipped in 1.0.x; v2 shipped in builds whose chime the resource
      // shrinker stripped, so that channel is permanently silent. Reusing
      // either would inherit state the device froze back then.
      expect(LocalNotificationService.channelId, isNot('soty_messages'));
      expect(LocalNotificationService.channelId, isNot('soty_messages_v2'));
      expect(LocalNotificationService.channelId, 'soty_messages_v3');
    });

    test('announces itself with high importance, sound and vibration', () {
      final channel = LocalNotificationService.channel;
      expect(channel.importance, Importance.high);
      expect(channel.sound, isNotNull);
      expect(channel.enableVibration, isTrue);
      expect(channel.showBadge, isTrue);
      expect(channel.name, isNotEmpty);
      expect(channel.description, isNotEmpty);
    });

    test('gives every peer a distinct notification id', () {
      // One id per chat: a new message replaces that chat's banner instead of
      // stacking a second one, and two different chats never overwrite
      // each other's notification.
      final first = LocalNotificationService.notificationId('a' * 64);
      final same = LocalNotificationService.notificationId('a' * 64);
      final other = LocalNotificationService.notificationId('b' * 64);
      expect(first, same);
      expect(first, isNot(other));
      expect(first, lessThan(0x7fffffff));
    });

    test('per-message details float as a heads-up banner', () {
      final android = LocalNotificationService.details.android;
      expect(android, isNotNull);
      expect(android!.importance, Importance.high);
      expect(android.priority, Priority.high);
      // A banner competes with other high-priority notifications; a message
      // category lets the system rank it as a conversation.
      expect(android.category, AndroidNotificationCategory.message);
      expect(android.playSound, isTrue);
      expect(android.enableVibration, isTrue);
      expect(android.showWhen, isTrue);
      // Never re-alert-suppress: a second message in the same chat is news.
      expect(android.onlyAlertOnce, isFalse);
      expect(android.color, isNotNull);
    });
  });

  group('LocalNotificationService Linux', () {
    // Without these two blocks the freedesktop side never had anything to
    // work with: no initialization settings meant the D-Bus client was never
    // registered, so every banner was dropped before a server saw it.
    test('initialization settings register a Linux notifier', () {
      final settings = LocalNotificationService.initializationSettings();
      expect(settings.linux, isNotNull);
      expect(settings.linux!.defaultActionName, isNotEmpty);
      // A session bus alone plays nothing; the sound has to be named.
      expect(settings.linux!.defaultSound, isNotNull);
      expect(settings.android, isNotNull);
    });

    test('the action label is localized by the caller', () {
      final settings =
          LocalNotificationService.initializationSettings(
        actionLabel: 'Открыть',
      );
      expect(settings.linux!.defaultActionName, 'Открыть');
    });

    test('per-message details carry the chime from the asset bundle', () {
      final linux = LocalNotificationService.details.linux;
      expect(linux, isNotNull);
      expect(linux!.urgency, LinuxNotificationUrgency.critical);
      expect(linux.category, LinuxNotificationCategory.imReceived);
      final sound = linux.sound;
      expect(sound, isA<AssetsLinuxSound>());
      expect((sound! as AssetsLinuxSound).relativePath,
          LocalNotificationService.soundAsset);
    });

    test('the chime asset is declared in pubspec', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      // Pinned as a shape, not as a literal: the version moves on every
      // release, and asserting the exact string would only fail the build.
      expect(pubspec, matches(RegExp(r'^version: \d+\.\d+\.\d+\+\d+$',
          multiLine: true)));
      expect(pubspec, contains('- ${LocalNotificationService.soundAsset}'));
      expect(
        File(LocalNotificationService.soundAsset).existsSync(),
        isTrue,
        reason: 'the Linux notifier can only name a file that ships',
      );
      // The very same bytes Android plays as a raw resource.
      expect(
        File('android/app/src/main/res/raw/soty_chime.ogg')
            .readAsBytesSync(),
        File(LocalNotificationService.soundAsset).readAsBytesSync(),
      );
    });
  });
}

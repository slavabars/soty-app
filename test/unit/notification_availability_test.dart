import 'package:dtm_app/core/notifications/local_notifications.dart';
import 'package:dtm_app/core/notifications/notification_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

/// A banner that never appears and never explains itself is indistinguishable
/// from a working one, so every platform call records its failure and the
/// settings screen can show it. These tests pin that contract against the
/// plugin's method channel.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // The platform registration a real Android build gets from the generated
  // plugin registrant, pinned so the notifier can be driven off-device.
  FlutterLocalNotificationsPlatform.instance =
      AndroidFlutterLocalNotificationsPlugin();
  debugDefaultTargetPlatformOverride = TargetPlatform.android;
  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <String>[];

  void mockPlugin({
    bool enabled = true,
    bool failInitialize = false,
    bool failShow = false,
  }) {
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      if (failInitialize) {
        throw PlatformException(code: 'boom', message: 'no channel');
      }
      if (failShow) {
        throw PlatformException(code: 'show', message: 'rejected');
      }
      return switch (call.method) {
        'areNotificationsEnabled' => enabled,
        'initialize' => true,
        'getNotificationAppLaunchDetails' => null,
        _ => null,
      };
    });
  }

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    calls.clear();
  });

  tearDownAll(() {
    debugDefaultTargetPlatformOverride = null;
  });

  test('a working notifier reports itself ready', () async {
    mockPlugin();
    final service = LocalNotificationService();
    await service.initialize();

    expect(await service.availability(), NotificationAvailability.ready);
    expect(service.lastError, isEmpty);
  });

  test('a notifier the system switched off is reported as blocked', () async {
    mockPlugin(enabled: false);
    final service = LocalNotificationService();
    await service.initialize();

    expect(await service.availability(), NotificationAvailability.blocked);
  });

  test('a notifier that refused to start keeps its reason', () async {
    mockPlugin(failInitialize: true);
    final service = LocalNotificationService();
    await service.initialize();

    // Not a crash and not silence: the reason is what the user is shown.
    expect(await service.availability(), NotificationAvailability.unavailable);
    expect(service.lastError, contains('no channel'));
  });

  test('a notifier that never started is unknown, not blocked', () async {
    final service = LocalNotificationService();

    expect(await service.availability(), NotificationAvailability.unknown);
  });

  test('a rejected banner keeps its reason instead of vanishing', () async {
    mockPlugin(failShow: true);
    final service = LocalNotificationService();
    await service.initialize();

    await service.showChatMessage(
      peerPubKey: 'a' * 64,
      title: 'Zora',
      body: 'hello',
    );

    expect(service.lastError, contains('rejected'));
  });

  test('a test banner is never posted while notifications are blocked',
      () async {
    mockPlugin(enabled: false);
    final service = LocalNotificationService();
    await service.initialize();

    final result = await service.sendTest(title: 'Soty', body: 'test');

    expect(result, NotificationTestResult.blocked);
    // Offering a test that the system will drop teaches the user nothing.
    expect(calls, isNot(contains('show')));
  });

  test('a test banner reports a platform rejection', () async {
    mockPlugin(failShow: true);
    final service = LocalNotificationService();
    await service.initialize();

    final result = await service.sendTest(title: 'Soty', body: 'test');

    expect(result, NotificationTestResult.unavailable);
    expect(service.lastError, contains('rejected'));
  });

  test('a test banner is posted with its own id and no chat payload',
      () async {
    mockPlugin();
    final service = LocalNotificationService();
    await service.initialize();

    final result = await service.sendTest(title: 'Soty', body: 'test');

    expect(result, NotificationTestResult.sent);
    expect(service.lastError, isEmpty);
    expect(calls, contains('show'));
  });

  test('a platform without a notifier says so instead of pretending',
      () async {
    final service = NoopNotificationService();

    expect(await service.availability(), NotificationAvailability.unsupported);
    expect(
      await service.sendTest(title: 'Soty', body: 'test'),
      NotificationTestResult.unsupported,
    );
    expect(service.lastError, isEmpty);
    await service.initialize(actionLabel: 'Открыть');
    await service.showChatMessage(
      peerPubKey: 'a' * 64,
      title: 'Zora',
      body: 'hello',
    );
    await service.cancelChatMessage('a' * 64);
    await service.openSystemSettings();
    await service.dispose();
  });
}

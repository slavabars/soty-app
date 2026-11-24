import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dtm_app/core/notifications/local_notifications.dart';
import 'package:dtm_app/core/notifications/notification_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

/// Exercises the freedesktop path against a real session bus and a real
/// org.freedesktop.Notifications server, because that is the whole point of the
/// Linux report: nothing was ever reaching a bus.
///
///     dbus-run-session -- flutter test --no-pub \
///       test/integration/linux_dbus_notification_test.dart
///
/// The stub is tool/linux_notify_server.py and it records every call, so the
/// assertions below are on the wire, not on a Dart mock. A desktop session
/// already has a notification daemon holding the bus name, so there the file
/// skips: a private bus is the only place this can be honest.
class _Bundle {
  _Bundle(this.created);
  final List<Directory> created;

  /// The plugin derives its asset directory from /proc/self/exe and wants a
  /// real version.json plus a real file behind every asset hint, so a
  /// bundle-shaped tree is staged next to the running binary.
  static _Bundle? stage() {
    final exe = File('/proc/self/exe').resolveSymbolicLinksSync();
    final root = Directory('${File(exe).parent.path}/data');
    if (Directory('${root.path}/flutter_assets').existsSync()) return null;
    final created = <Directory>[];
    try {
      root.createSync(recursive: true);
      created.add(root);
      final assets = Directory('${root.path}/flutter_assets')
        ..createSync();
      created.add(assets);
      File('${assets.path}/version.json')
          .writeAsStringSync('{"app_name":"soty"}');
      final sounds = Directory('${assets.path}/assets')..createSync();
      created.add(sounds);
      File('${sounds.path}/soty_chime.ogg').writeAsBytesSync(
        File('assets/soty_chime.ogg').readAsBytesSync(),
      );
      return _Bundle(created);
    } on FileSystemException {
      for (final dir in created.reversed) {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      }
      return null;
    }
  }

  void discard() {
    for (final dir in created.reversed) {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    }
  }
}

void main() {
  final address = Platform.environment['DBUS_SESSION_BUS_ADDRESS'];
  if (address == null || address.isEmpty) {
    test('needs a session bus', () {}, skip: 'run under dbus-run-session');
    return;
  }

  TestWidgetsFlutterBinding.ensureInitialized();
  debugDefaultTargetPlatformOverride = TargetPlatform.linux;
  FlutterLocalNotificationsPlatform.instance =
      LinuxFlutterLocalNotificationsPlugin();

  final log = File('${Directory.systemTemp.path}/soty-notify-$pid.jsonl');
  Process? server;
  _Bundle? bundle;
  LocalNotificationService? service;
  String? skip;

  setUpAll(() async {
    server = await Process.start(
      'python3',
      ['tool/linux_notify_server.py', '--log', log.path],
    );
    final output = StringBuffer();
    final done = Completer<String>();
    void watch(Stream<List<int>> stream) {
      stream.transform(utf8.decoder).listen(
        (line) {
          output.write(line);
          if (line.contains('ready')) done.complete('ready');
          if (line.contains('busy')) done.complete('busy');
        },
        onError: (Object error) {
          output.writeln(error);
          if (!done.isCompleted) done.completeError(error);
        },
      );
    }

    watch(server!.stdout);
    watch(server!.stderr);
    final state = await done.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () => throw StateError('no verdict from the stub: $output'),
    );
    if (state == 'busy') {
      skip =
          'the session bus already has a notification daemon; '
          'run this under dbus-run-session';
      return;
    }
    bundle = _Bundle.stage();
    service = LocalNotificationService();
    await service!.initialize(actionLabel: 'Open');
  });

  tearDownAll(() async {
    // Anything that can hang has to be inside the try, or the stub server
    // outlives the run and holds the bus name away from the next attempt.
    try {
      await service?.dispose();
    } finally {
      server?.kill(ProcessSignal.sigterm);
      await server?.exitCode.timeout(
        const Duration(seconds: 5),
        onTimeout: () => -1,
      );
      if (log.existsSync()) log.deleteSync();
      bundle?.discard();
      debugDefaultTargetPlatformOverride = null;
    }
  });

  LocalNotificationService notifier() => service!;

  /// markTestSkipped does not stop the body, so callers bail out on false.
  bool check() {
    if (skip == null) return true;
    markTestSkipped(skip!);
    return false;
  }

  List<Map<String, Object?>> entries() {
    if (!log.existsSync()) return const [];
    return log
        .readAsLinesSync()
        .map((line) => jsonDecode(line) as Map<String, Object?>)
        .toList();
  }

  List<Map<String, Object?>> notifies() => entries()
      .where((entry) => entry['method'] == 'Notify')
      .toList();

  test('the notifier starts on a real session bus', () {
    if (!check()) return;
    expect(notifier().lastError, isEmpty);
  });

  test('a chat banner reaches the server as an instant message', () async {
    if (!check()) return;
    await notifier().showChatMessage(
      peerPubKey: 'a' * 64,
      title: 'Zora',
      body: 'hello',
    );

    expect(notifier().lastError, isEmpty);
    final call = notifies().single;
    expect(call['summary'], 'Zora');
    expect(call['body'], 'hello');
    // A click has to be wired up, and the label on it is the one the app
    // localized. The chat key never goes on the bus: the plugin keeps the
    // payload in its own session storage and hands it back on the action.
    expect(call['actions'], ['default', 'Open']);
  });

  test('the banner asks for a floating banner with the shipped chime', () {
    if (!check()) return;
    final hints = notifies().last['hints'] as Map<String, Object?>;
    expect(hints['urgency'], 2);
    expect(hints['category'], 'im.received');
    final sound = hints['sound-file'];
    if (sound == null) {
      markTestSkipped('no asset directory next to the test binary');
      return;
    }
    expect(sound, endsWith('assets/soty_chime.ogg'));
    // A hint naming a file that is not there is silence on a real desktop.
    expect(File(sound as String).existsSync(), isTrue);
  });

  test('reading a chat closes its banner', () async {
    if (!check()) return;
    await notifier().showChatMessage(
      peerPubKey: 'c' * 64,
      title: 'Zora',
      body: 'read me',
    );
    final posted = notifies().last['id'];
    await notifier().cancelChatMessage('c' * 64);
    // Give the bus a moment to deliver the close before reading the log.
    await Future<void>.delayed(const Duration(milliseconds: 300));

    expect(
      entries()
          .where((entry) => entry['method'] == 'CloseNotification')
          .map((entry) => entry['id']),
      contains(posted),
    );
  });

  test('a test banner is posted and the platform is told it worked', () async {
    if (!check()) return;
    final result = await notifier().sendTest(title: 'Soty', body: 'test');

    expect(result, NotificationTestResult.sent);
    expect(notifies().map((call) => call['summary']), contains('Soty'));
  });

  test('the platform agrees notifications are available', () async {
    if (!check()) return;
    expect(await notifier().availability(), NotificationAvailability.ready);
  });
}

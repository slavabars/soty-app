import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Regression guard for the release-only bug that made every Android
/// notification disappear on real devices while debug builds worked fine.
///
/// The Flutter Gradle plugin forces `isMinifyEnabled` and `isShrinkResources`
/// on the release build type (`FlutterPlugin.kt`), and the resource shrinker
/// only sees references coming from XML and the manifest. The notification
/// chime is referenced solely by the Dart string `soty_chime`, so the shrinker
/// deleted `res/raw/soty_chime.ogg` from the release APK. With the resource
/// gone, `RawResourceAndroidNotificationSound` failed to resolve and no
/// notification was posted at all — no banner, no sound, no vibration.
///
/// The source-level assertions below run always; the APK assertion needs a
/// built release artifact and is skipped until one exists.
void main() {
  group('release notification resources', () {
    test('keep.xml rescues the chime from the resource shrinker', () {
      final keep = File('android/app/src/main/res/raw/keep.xml');
      expect(
        keep.existsSync(),
        isTrue,
        reason: 'res/raw/keep.xml is the shrinker config that keeps the '
            'notification sound inside release APKs',
      );
      final body = keep.readAsStringSync();
      expect(body, contains('tools:keep'));
      expect(body, contains('@raw/soty_chime'));
    });

    test('manifest wires the shrinker config in', () {
      final manifest =
          File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
      expect(manifest, contains('android.shrinker.config'));
      expect(manifest, contains('android:resource="@raw/keep"'));
    });

    test('a built release APK still ships the chime resource', () {
      final apk = File('../build-artifacts/soty-release.apk');
      if (!apk.existsSync()) {
        markTestSkipped('no release APK in ../build-artifacts yet');
        return;
      }
      final aapt2 = _aapt2();
      if (aapt2 == null) {
        markTestSkipped('aapt2 not found under the Android SDK');
        return;
      }
      final dump = Process.runSync(
        aapt2.path,
        ['dump', 'resources', apk.path],
      );
      expect(dump.exitCode, 0, reason: '${dump.stderr}');
      expect(
        '${dump.stdout}',
        contains('raw/soty_chime'),
        reason: 'the notification chime was stripped from the release APK, so '
            'no notification can resolve its sound',
      );
    });
  });
}

/// Newest `aapt2` in the Android SDK, or null when the SDK cannot be located.
File? _aapt2() {
  final roots = <String>[
    if (Platform.environment['ANDROID_HOME'] != null)
      Platform.environment['ANDROID_HOME']!,
    if (Platform.environment['ANDROID_SDK_ROOT'] != null)
      Platform.environment['ANDROID_SDK_ROOT']!,
    '${Platform.environment['HOME']}/Android/Sdk',
  ];
  for (final root in roots) {
    final tools = Directory('$root/build-tools');
    if (!tools.existsSync()) continue;
    final versions = tools
        .listSync()
        .whereType<Directory>()
        .toList()
      ..sort((a, b) => b.path.compareTo(a.path));
    for (final version in versions) {
      final binary = File('${version.path}/aapt2');
      if (binary.existsSync()) return binary;
    }
  }
  return null;
}

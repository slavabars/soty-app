import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Joins shell line continuations so a multi-line `flutter build` command is
/// checked as one string.
List<String> _commands(String script) {
  final joined = script.replaceAll(RegExp(r'\\\r?\n\s*'), ' ');
  return joined
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty && !line.startsWith('#'))
      .toList(growable: false);
}

void main() {
  group('build scripts keep the channels apart', () {
    // `scripts/build_all.sh` ships with the app. `build_apps.sh` and
    // `build_signed_app.sh` belong to the private workspace and are not
    // published, so a standalone clone skips them instead of failing.
    const scripts = <String, String>{
      'scripts/build_all.sh': 'scripts/build_all.sh',
      'scripts/build_apps.sh': '../scripts/build_apps.sh',
      'scripts/build_signed_app.sh': '../scripts/build_signed_app.sh',
    };

    for (final entry in scripts.entries) {
      final file = File(entry.value);
      test(
        '${entry.key} pairs every flavor with its define',
        () {
          expect(file.existsSync(), isTrue, reason: entry.value);
          final lines = _commands(file.readAsStringSync());
          final play =
              lines.where((line) => line.contains('--flavor play')).toList();
          final site =
              lines.where((line) => line.contains('--flavor site')).toList();

          for (final line in play) {
            expect(
              line,
              contains('SOTY_CHANNEL=play'),
              reason: 'play without the channel define: $line',
            );
          }
          for (final line in site) {
            expect(
              line,
              isNot(contains('SOTY_CHANNEL=play')),
              reason: 'site flavour with the play define: $line',
            );
          }
        },
        skip: file.existsSync()
            ? null
            : '${entry.value} is workspace-only and not published',
      );
    }

    final missing =
        scripts.values.where((path) => !File(path).existsSync()).toList();
    test(
      'the release path really builds both flavors',
      () {
        final lines = [
          for (final path in scripts.values)
            ..._commands(File(path).readAsStringSync()),
        ];
        expect(
          lines.where((line) => line.contains('--flavor play')),
          isNotEmpty,
        );
        expect(
          lines.where((line) => line.contains('--flavor site')),
          isNotEmpty,
        );
      },
      skip: missing.isEmpty
          ? null
          : 'workspace scripts are not published: ${missing.join(', ')}',
    );
  });

  group('play manifest', () {
    late String manifest;

    setUpAll(() {
      manifest = File(
        'android/app/src/play/AndroidManifest.xml',
      ).readAsStringSync();
    });

    test('removes the APK installer permission', () {
      expect(
        RegExp(
          r'<uses-permission\s+android:name='
          r'"android\.permission\.REQUEST_INSTALL_PACKAGES"\s+'
          r'tools:node="remove"\s*/>',
        ).hasMatch(manifest),
        isTrue,
      );
    });

    test('removes the update FileProvider', () {
      expect(manifest, contains('androidx.core.content.FileProvider'));
      expect(manifest, contains(r'${applicationId}.updates'));
      expect(
        RegExp(r'tools:node="remove"').allMatches(manifest).length,
        2,
      );
    });

    test('marks the play channel', () {
      expect(manifest, contains('soty-channel-play'));
      expect(manifest, isNot(contains('soty-channel-site')));
    });
  });

  group('site manifest', () {
    test('marks the site channel', () {
      final site = File(
        'android/app/src/site/AndroidManifest.xml',
      ).readAsStringSync();
      expect(site, contains('soty-channel-site'));
    });
  });

  group('gradle flavour guard', () {
    late String gradle;

    setUpAll(() {
      gradle = File('android/app/build.gradle.kts').readAsStringSync();
    });

    test('declares both flavors on one dimension', () {
      expect(gradle, contains('flavorDimensions += "channel"'));
      expect(gradle, contains('create("site")'));
      expect(gradle, contains('create("play")'));
    });

    test('refuses a flavor built with the wrong dart define', () {
      expect(gradle, contains('SOTY_CHANNEL=play'));
      expect(gradle, contains('onVariants'));
    });
  });
}

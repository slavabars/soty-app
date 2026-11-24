import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Android deep-link registration', () {
    late String manifest;

    setUpAll(() {
      manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
    });

    test('registers the soty://invite route', () {
      expect(
        RegExp(
          r'<data[^>]*android:scheme="soty"[^>]*android:host="invite"',
        ).hasMatch(manifest),
        isTrue,
      );
    });

    test('registers the soty://host route', () {
      expect(
        RegExp(
          r'<data[^>]*android:scheme="soty"[^>]*android:host="host"',
        ).hasMatch(manifest),
        isTrue,
      );
    });

    test('routes deep links into the Flutter engine', () {
      expect(manifest, contains('flutter_deeplinking_enabled'));
    });
  });
}

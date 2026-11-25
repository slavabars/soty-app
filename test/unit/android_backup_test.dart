import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The identity seeds are encrypted with a key that lives in the Android
/// Keystore and is never part of a system backup. If Android restores the
/// encrypted blob without that key, the app can never start again, so the app
/// opts out of cloud backup and device transfer entirely.
void main() {
  group('Android backup policy', () {
    late String manifest;

    setUpAll(() {
      manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
    });

    test('opts out of the system backup', () {
      expect(manifest, contains('android:allowBackup="false"'));
      expect(manifest, contains('android:fullBackupContent="false"'));
      expect(
        manifest,
        contains('android:dataExtractionRules="@xml/data_extraction_rules"'),
      );
    });

    test('the extraction rules exclude every domain', () {
      final rules = File(
        'android/app/src/main/res/xml/data_extraction_rules.xml',
      ).readAsStringSync();

      expect(rules, contains('<cloud-backup>'));
      expect(rules, contains('<device-transfer>'));
      for (final domain in const [
        'root',
        'file',
        'database',
        'sharedpref',
        'external',
        'device_root',
        'device_file',
        'device_database',
        'device_sharedpref',
      ]) {
        expect(
          rules,
          contains('<exclude domain="$domain" path="."'),
          reason: 'the $domain domain must not be transferred',
        );
      }
    });
  });
}

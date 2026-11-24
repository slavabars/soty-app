import 'dart:io';

import 'package:dtm_app/core/build_info.dart';
import 'package:dtm_app/core/update/version_compare.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the reported version matches pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(
      r'^version: (\d+\.\d+\.\d+\+\d+)$',
      multiLine: true,
    ).firstMatch(pubspec);
    expect(match, isNotNull, reason: 'pubspec version must be x.y.z+build');
    expect(
      kSotyVersion,
      match!.group(1),
      reason: 'bump lib/core/update/app_version.dart with pubspec.yaml',
    );
  });

  test('the reported version parses', () {
    final parsed = AppVersion.tryParse(kSotyVersion);
    expect(parsed, isNotNull);
    expect('$parsed', kSotyVersion);
  });
}

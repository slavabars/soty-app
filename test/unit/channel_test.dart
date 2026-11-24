import 'dart:io' show Platform;

import 'package:dtm_app/core/channel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('distribution channel', () {
    test('defaults to the site channel', () {
      expect(kSotyChannel, 'site');
      expect(kPlayBuild, isFalse);
    });

    test('self-updates need Android outside Play', () {
      expect(selfUpdateEnabled(channel: 'site', isAndroid: true), isTrue);
      expect(selfUpdateEnabled(channel: 'play', isAndroid: true), isFalse);
      expect(selfUpdateEnabled(channel: 'site', isAndroid: false), isFalse);
      expect(selfUpdateEnabled(channel: 'play', isAndroid: false), isFalse);
    });

    test('the runtime flag follows the platform', () {
      expect(
        kSelfUpdate,
        selfUpdateEnabled(
          channel: kSotyChannel,
          isAndroid: Platform.isAndroid,
        ),
      );
    });
  });
}

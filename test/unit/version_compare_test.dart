import 'package:dtm_app/core/update/version_compare.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppVersion.tryParse', () {
    test('accepts the shapes the release feed uses', () {
      expect(AppVersion.tryParse('1.4.0'), const AppVersion(1, 4, 0));
      expect(AppVersion.tryParse('1.4.0+11'), const AppVersion(1, 4, 0, 11));
      expect(AppVersion.tryParse('v1.4.0+11'), const AppVersion(1, 4, 0, 11));
      expect(AppVersion.tryParse('V2.0.0'), const AppVersion(2, 0, 0));
      expect(AppVersion.tryParse(' 1.2.3 '), const AppVersion(1, 2, 3));
      expect(AppVersion.tryParse('0.0.0'), const AppVersion(0, 0, 0));
      expect(
        AppVersion.tryParse('999999999.1.1'),
        const AppVersion(999999999, 1, 1),
      );
    });

    test('rejects anything that is not three numbers', () {
      for (final raw in const [
        '',
        '  ',
        'v',
        '1',
        '1.4',
        '1.4.0.1',
        '1.4.0+',
        '1.4.0+11+12',
        '1..0',
        '.1.0',
        '1.2.x',
        '1.4.0-rc1',
        '1.4.0 beta',
        'vv1.4.0',
        'release-1.4.0',
        '+11',
        '1.4.0+11a',
      ]) {
        expect(AppVersion.tryParse(raw), isNull, reason: raw);
      }
    });

    test('rejects non-ASCII digits and oversized components', () {
      expect(AppVersion.tryParse('١.٤.٠'), isNull);
      expect(AppVersion.tryParse('1.4.０'), isNull);
      expect(AppVersion.tryParse('1234567890.4.0'), isNull);
      expect(AppVersion.tryParse('1.4.0+1234567890'), isNull);
    });

    test('rejects an oversized raw string before splitting it', () {
      expect(AppVersion.tryParse('1' * 5000), isNull);
      expect(AppVersion.tryParse('v${'9' * 40}.0.0'), isNull);
    });
  });

  group('AppVersion.compareTo', () {
    AppVersion v(String raw) {
      final parsed = AppVersion.tryParse(raw);
      expect(parsed, isNotNull, reason: raw);
      return parsed!;
    }

    test('orders by major, then minor, then patch, then build', () {
      expect(v('2.0.0').isNewerThan(v('1.99.99')), isTrue);
      expect(v('1.5.0').isNewerThan(v('1.4.99')), isTrue);
      expect(v('1.4.1').isNewerThan(v('1.4.0')), isTrue);
      expect(v('1.4.0+12').isNewerThan(v('1.4.0+11')), isTrue);
      expect(v('1.4.0').isNewerThan(v('1.4.0+1')), isFalse);
      expect(v('1.4.0+1').isNewerThan(v('1.4.0')), isTrue);
    });

    test('equal versions compare equal in both directions', () {
      expect(v('1.4.0+11').compareTo(v('v1.4.0+11')), 0);
      expect(v('1.4.0').compareTo(v('1.4.0+0')), 0);
      expect(v('1.4.0+11'), v('1.4.0+11'));
      expect(v('1.4.0+11').hashCode, v('1.4.0+11').hashCode);
    });

    test('a build-only bump is still a newer release', () {
      expect(v('1.3.0+11').isNewerThan(v('1.3.0+10')), isTrue);
      expect(v('1.3.0+10').isNewerThan(v('1.3.0+11')), isFalse);
    });
  });
}

import 'package:dtm_app/core/links.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('abuse report link', () {
    test('Russian lives at the site root', () {
      final uri = abuseReportUri(languageCode: 'ru', peerKey: 'abc123');

      expect(uri.toString(), 'https://soty.su/abuse?peer=abc123');
    });

    test('every other locale is prefixed like the site', () {
      expect(
        abuseReportUri(languageCode: 'en', peerKey: 'ff').path,
        '/en/abuse',
      );
      expect(
        abuseReportUri(languageCode: 'ja', peerKey: 'ff').path,
        '/ja/abuse',
      );
    });

    test('the peer key is the only query parameter', () {
      final uri = abuseReportUri(languageCode: 'de', peerKey: 'a' * 64);

      expect(uri.queryParameters, {'peer': 'a' * 64});
      expect(uri.host, 'soty.su');
      expect(uri.scheme, 'https');
    });

    test('an empty language code falls back to the root', () {
      expect(abuseReportUri(languageCode: '', peerKey: 'x').path, '/abuse');
    });
  });

  test('privacy and terms mirror the site locale routing', () {
    expect(
      privacyUri(languageCode: 'ru').path,
      '/privacy',
    );
    expect(
      termsUri(languageCode: 'ru').path,
      '/terms',
    );
    expect(
      privacyUri(languageCode: 'de').toString(),
      'https://soty.su/de/privacy',
    );
    expect(
      termsUri(languageCode: 'ja').toString(),
      'https://soty.su/ja/terms',
    );
    expect(privacyUri(languageCode: '').path, '/privacy');
  });
}

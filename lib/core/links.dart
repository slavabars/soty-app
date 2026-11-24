/// Public project links the app opens in a browser.
library;

/// Project site. Russian is published at the root, every other locale under
/// `/<code>/`, which [siteUri] mirrors.
const String kSiteUrl = 'https://soty.su';

/// Kept for the existing callers; the same host as [kSiteUrl].
const String kAbuseUrl = kSiteUrl;

/// Absolute URL of one site section in the given interface language.
Uri siteUri(String section, {required String languageCode}) {
  final code = languageCode.toLowerCase();
  final path = code == 'ru' || code.isEmpty ? '/$section' : '/$code/$section';

  return Uri.parse('$kSiteUrl$path');
}

/// Privacy policy in the interface language.
Uri privacyUri({required String languageCode}) =>
    siteUri('privacy', languageCode: languageCode);

/// Terms of use in the interface language.
Uri termsUri({required String languageCode}) =>
    siteUri('terms', languageCode: languageCode);

/// Builds the report URL for the current interface language and the peer the
/// user is reporting.
Uri abuseReportUri({
  required String languageCode,
  required String peerKey,
}) {
  return siteUri('abuse', languageCode: languageCode).replace(
    queryParameters: {'peer': peerKey},
  );
}

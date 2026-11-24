import 'dart:convert';

/// Serializes a signed identity claim into the shareable
/// `soty://invite?claim=<base64url>` deep link and parses such links back.
///
/// The claim segment is base64url (no padding), so it survives every
/// transport that would mangle `+`, `/` or `=` in a URL query. Parsing is
/// strict: any malformed segment throws [FormatException].
class InviteLink {
  static const String scheme = 'soty';
  static const String host = 'invite';

  /// Encodes [claimJson] (as produced by [IdentityClaim.encode]) into a link.
  /// The base64url segment is unpadded so query transports cannot mangle `=`.
  static String encode(String claimJson) {
    final encoded = base64Url
        .encode(utf8.encode(claimJson))
        .replaceAll(RegExp(r'=+$'), '');
    return '$scheme://$host?claim=$encoded';
  }

  /// Extracts the claim JSON from [route] (what [String] delivers through
  /// the platform dispatcher) when it is one of our invite links.
  ///
  /// Returns `null` for any route that is not an invite link. Throws
  /// [FormatException] when the claim segment exists but is corrupt — a
  /// hostile scanner/link must never silently fall back to an empty value.
  static String? claimFromRoute(String route) {
    final uri = Uri.tryParse(route);
    if (uri == null || uri.scheme != scheme || uri.host != host) return null;
    final segment = uri.queryParameters['claim'];
    if (segment == null) return null;
    final padded = segment.padRight(
      (segment.length + 3) & ~3,
      '=',
    );
    return utf8.decode(base64Url.decode(padded));
  }
}
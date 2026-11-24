/// Splits a message body into plain and link runs so the chat can render a
/// URL inside the text as a tappable span without a third-party linkifier.
///
/// The input is untrusted (decrypted, attacker-controlled) text, so this is a
/// total, linear scan: it never throws and never backtracks.
library;

import '../soty_route.dart';

/// One run of message text. When [url] is non-null the run is a link whose
/// visible [text] should be tappable and whose [url] is the target to open.
final class LinkSpan {
  const LinkSpan(this.text, [this.url]);

  final String text;
  final String? url;

  bool get isLink => url != null;

  @override
  String toString() => isLink ? 'LinkSpan($text -> $url)' : 'LinkSpan($text)';
}

/// The most links rendered tappable in one message. A body full of URLs is
/// otherwise thousands of gesture recognizers; the rest stays plain text.
const int maxMessageLinks = 64;

/// A URL longer than this is left as plain text rather than made tappable.
const int maxLinkLength = 2048;

/// Matches a candidate starting at a word boundary, stopping at whitespace and
/// at the characters that delimit a URL inside prose `< > " ' « » —`. The
/// quantifier is a single flat class, so matching is linear.
final RegExp _candidates = RegExp(
  r'''\b(?:https?://|www\.|soty://)[^\s<>"'«»—]+''',
  caseSensitive: false,
);

/// Code units stripped from the end of a candidate because they belong to the
/// sentence, not the URL: `. , ; : ! ? " '`.
const Set<int> _trailingPunctuation = {
  0x2E, 0x2C, 0x3B, 0x3A, 0x21, 0x3F, 0x22, 0x27,
};

/// Splits [text] into runs, turning `http://`, `https://`, bare `www.` and our
/// own `soty://invite?claim=…` / `soty://host?addr=…` candidates into links.
/// Any other scheme (`javascript:`, `file:`, `data:`, `intent:`, …) is not
/// matched and stays plain text, so a crafted message can never surface an
/// actionable non-web target.
List<LinkSpan> linkify(
  String text, {
  int maxLinks = maxMessageLinks,
  int maxUrlLength = maxLinkLength,
}) {
  if (text.isEmpty) return const <LinkSpan>[];
  final spans = <LinkSpan>[];
  var cursor = 0;
  var links = 0;
  for (final match in _candidates.allMatches(text)) {
    if (links >= maxLinks) break;
    final trimmed = _stripTrailing(match.group(0)!);
    if (trimmed.isEmpty) continue;
    final url = _resolveUrl(trimmed);
    if (url == null || url.length > maxUrlLength) continue;
    if (match.start > cursor) {
      spans.add(LinkSpan(text.substring(cursor, match.start)));
    }
    spans.add(LinkSpan(trimmed, url));
    cursor = match.start + trimmed.length;
    links++;
  }
  if (cursor < text.length) {
    spans.add(LinkSpan(text.substring(cursor)));
  }
  return spans;
}

/// Removes sentence punctuation from the end of [raw], keeping a closing
/// `)`, `]` or `}` that is balanced by an opener inside the URL (a Wikipedia
/// `..._(disambiguation)` link must keep its final paren).
String _stripTrailing(String raw) {
  var paren = 0;
  var bracket = 0;
  var brace = 0;
  for (var i = 0; i < raw.length; i++) {
    final c = raw.codeUnitAt(i);
    if (c == 0x28) {
      paren--;
    } else if (c == 0x29) {
      paren++;
    } else if (c == 0x5B) {
      bracket--;
    } else if (c == 0x5D) {
      bracket++;
    } else if (c == 0x7B) {
      brace--;
    } else if (c == 0x7D) {
      brace++;
    }
  }
  var end = raw.length;
  while (end > 0) {
    final c = raw.codeUnitAt(end - 1);
    if (_trailingPunctuation.contains(c)) {
      end--;
      continue;
    }
    if (c == 0x29 && paren > 0) {
      paren--;
      end--;
      continue;
    }
    if (c == 0x5D && bracket > 0) {
      bracket--;
      end--;
      continue;
    }
    if (c == 0x7D && brace > 0) {
      brace--;
      end--;
      continue;
    }
    break;
  }
  return raw.substring(0, end);
}

/// The absolute target for a trimmed candidate: a bare `www.` host is served
/// over https, and our own `soty://` links are handed back as-is. Returns null
/// unless the result is exactly an `http`/`https` URL with a dotted host, or a
/// `soty://invite?claim=…` / `soty://host?addr=…` link, so `http://` alone,
/// `www.` alone or `soty://` alone is not a link.
String? _resolveUrl(String candidate) {
  if (candidate.toLowerCase().startsWith('soty://')) {
    return _resolveSoty(candidate);
  }
  final target = candidate.toLowerCase().startsWith('www.')
      ? 'https://$candidate'
      : candidate;
  final uri = Uri.tryParse(target);
  if (uri == null) return null;
  if (uri.scheme != 'http' && uri.scheme != 'https') return null;
  if (uri.host.isEmpty || !uri.host.contains('.')) return null;
  return target;
}

/// Accepts only the two `soty://` deep links the app acts on (see
/// [isSotyRoute]): an invite must carry a non-empty `claim`, a host a non-empty
/// `addr`. Everything else (`soty://settings`, a bare `soty://host`) stays
/// plain text so a message can never surface an actionable route the app does
/// not handle.
String? _resolveSoty(String candidate) {
  final uri = Uri.tryParse(candidate);
  if (uri == null || !isSotyRoute(uri)) return null;
  return candidate;
}

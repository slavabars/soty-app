import 'dart:math';

import '../security_limits.dart' show maxDisplayNameLength;

const List<String> _adjectives = [
  'amber',
  'brave',
  'bright',
  'calm',
  'clear',
  'crisp',
  'eager',
  'golden',
  'gentle',
  'kind',
  'lively',
  'quiet',
  'soft',
  'steady',
  'swift',
  'warm',
];

const List<String> _nouns = [
  'bee',
  'bumblebee',
  'cell',
  'bridge',
  'comb',
  'firefly',
  'lark',
  'meadow',
  'otter',
  'pine',
  'puma',
  'rook',
  'sparrow',
  'wren',
];

/// A suggested random display name ("Soty Bright Puma"). Deterministic when
/// [random] is supplied, so tests can pin exact output.
String suggestSotyName({Random? random, String prefix = 'Soty'}) {
  final rng = random ?? Random();
  var candidate = '';
  for (var attempt = 0; attempt < 8; attempt++) {
    final adjective = _adjectives[rng.nextInt(_adjectives.length)];
    final noun = _nouns[rng.nextInt(_nouns.length)];
    candidate = '$prefix $adjective $noun';
    if (candidate.length <= maxDisplayNameLength) return candidate;
  }
  return candidate.length <= maxDisplayNameLength
      ? candidate
      : candidate.substring(0, maxDisplayNameLength);
}

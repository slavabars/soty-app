import 'dart:typed_data';

import 'package:cryptography/cryptography.dart' show Sha256;

import 'hex.dart';

/// A short human-comparable fingerprint of a two-party key set.
///
/// Each side mixes its own Ed25519 + X25519 public keys with the peer's,
/// orders the two per-party blocks deterministically and hashes the result, so
/// both devices print exactly the same digits for the same pair of identities.
/// Comparing the code over a trusted channel catches a relay or host that
/// swapped a key: the swap changes the digits on both sides.
///
/// The code is 12 groups of five decimal digits (60 digits), which is short
/// enough to read aloud and long enough that a forged match is impractical.
class SafetyNumber {
  const SafetyNumber._();

  /// Groups of five digits printed per code.
  static const int groupCount = 12;

  /// Digits per group.
  static const int groupDigits = 5;

  /// Total digits in a code.
  static const int totalDigits = groupCount * groupDigits;

  static final RegExp _allDigits = RegExp(r'^\d{60}$');

  /// The code for this device and [theirEd]/[theirX].
  ///
  /// All four keys must be 32-byte hex; anything else throws
  /// [FormatException] and is never hashed.
  static Future<String> forPair({
    required String myX,
    required String myEd,
    required String theirX,
    required String theirEd,
  }) async {
    final blocks = [
      _partyBlock(myEd, myX, 'local'),
      _partyBlock(theirEd, theirX, 'peer'),
    ]..sort();
    var seed = Uint8List.fromList([
      ...hexToBytes(blocks[0]),
      ...hexToBytes(blocks[1]),
    ]);
    final sha = Sha256();
    final groups = <String>[];
    for (var i = 0; i < groupCount; i++) {
      final digest = (await sha.hash(seed)).bytes;
      final value =
          ((digest[0] << 24) |
              (digest[1] << 16) |
              (digest[2] << 8) |
              digest[3]) %
          100000;
      groups.add(value.toString().padLeft(groupDigits, '0'));
      seed = Uint8List.fromList(digest);
    }
    return groups.join(' ');
  }

  /// Compares a local [expected] code with whatever a QR scan produced.
  ///
  /// Spacing, a `soty:safety:` prefix and surrounding prose are ignored; the
  /// scanned text must still yield exactly [totalDigits] digits, so a payload
  /// padded with extra numbers cannot fake a match.
  static bool matches(String expected, String scanned) {
    final wanted = digitsOnly(expected);
    final seen = digitsOnly(scanned);
    if (!_allDigits.hasMatch(wanted)) return false;
    if (!_allDigits.hasMatch(seen)) return false;
    return wanted == seen;
  }

  /// Strips every non-digit character.
  static String digitsOnly(String raw) => raw.replaceAll(RegExp(r'\D'), '');

  /// One party as `Ed25519 || X25519` lowercase hex, used as a sortable block.
  static String _partyBlock(String ed, String x, String which) {
    if (!isHexOfLength(ed, 32)) {
      throw FormatException('$which Ed25519 key is not 32-byte hex');
    }
    if (!isHexOfLength(x, 32)) {
      throw FormatException('$which X25519 key is not 32-byte hex');
    }
    return ed.toLowerCase() + x.toLowerCase();
  }
}

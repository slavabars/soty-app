import 'dart:typed_data';

/// Hex encoding/decoding helpers shared by the crypto layer.
String bytesToHex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

/// True when [value] is exactly the hex encoding of an [n]-byte value.
bool isHexOfLength(String value, int n) {
  if (value.length != n * 2) return false;
  for (var i = 0; i < value.length; i++) {
    if (!_isHexValue(value.codeUnitAt(i))) return false;
  }
  return true;
}

bool _isHexValue(int c) =>
    (c >= 48 && c <= 57) || (c >= 97 && c <= 102) || (c >= 65 && c <= 70);

/// Decodes [hex] into bytes; throws [ArgumentError] on malformed input.
Uint8List hexToBytes(String hex) {
  if (hex.length.isOdd) {
    throw ArgumentError('Hex string must have an even length');
  }
  final out = Uint8List(hex.length ~/ 2);
  for (var i = 0; i < out.length; i++) {
    final hi = _hexVal(hex.codeUnitAt(i * 2));
    final lo = _hexVal(hex.codeUnitAt(i * 2 + 1));
    out[i] = (hi << 4) | lo;
  }
  return out;
}

int _hexVal(int c) {
  if (c >= 48 && c <= 57) return c - 48;
  if (c >= 97 && c <= 102) return c - 87;
  if (c >= 65 && c <= 70) return c - 55;
  throw ArgumentError('Invalid hex character: ${String.fromCharCode(c)}');
}

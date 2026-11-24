import 'dart:typed_data';

import 'package:dtm_app/core/crypto/hex.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('hex helpers', () {
    test('bytesToHex round-trips through hexToBytes', () {
      final bytes = Uint8List.fromList([0, 1, 15, 16, 255]);
      final hex = bytesToHex(bytes);
      expect(hex, '00010f10ff');
      expect(hexToBytes(hex), bytes);
    });

    test('empty input produces empty output', () {
      expect(bytesToHex(const []), '');
      expect(hexToBytes(''), isEmpty);
    });

    test('hexToBytes rejects odd-length strings', () {
      expect(() => hexToBytes('abc'), throwsArgumentError);
    });

    test('hexToBytes rejects non-hex characters', () {
      expect(() => hexToBytes('zz'), throwsArgumentError);
      expect(() => hexToBytes('0x'), throwsArgumentError);
    });

    test('isHexOfLength enforces exact length and charset', () {
      expect(isHexOfLength('ab' * 32, 32), isTrue);
      expect(isHexOfLength('AB' * 32, 32), isTrue);
      expect(isHexOfLength('ab' * 31, 32), isFalse);
      expect(isHexOfLength('zz' * 32, 32), isFalse);
      expect(isHexOfLength('', 0), isTrue);
    });
  });
}

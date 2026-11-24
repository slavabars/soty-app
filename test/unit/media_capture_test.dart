import 'dart:typed_data';

import 'package:dtm_app/core/media/media_capture.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List _bytes(List<int> values) => Uint8List.fromList(values);

/// A JPEG header followed by padding, so the length is never the reason a
/// sniff succeeds.
Uint8List _jpeg([int length = 32]) {
  final out = List<int>.filled(length, 0);
  out[0] = 0xFF;
  out[1] = 0xD8;
  out[2] = 0xFF;
  return Uint8List.fromList(out);
}

Uint8List _png([int length = 32]) {
  final out = List<int>.filled(length, 0);
  out.setAll(0, const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
  return Uint8List.fromList(out);
}

Uint8List _webp([int length = 32]) {
  final out = List<int>.filled(length, 0);
  out.setAll(0, const [0x52, 0x49, 0x46, 0x46]);
  out.setAll(8, const [0x57, 0x45, 0x42, 0x50]);
  return Uint8List.fromList(out);
}

void main() {
  group('detectImageMime', () {
    test('a JPEG header is sniffed as image/jpeg', () {
      expect(detectImageMime(_jpeg()), 'image/jpeg');
    });

    test('a PNG header is sniffed as image/png', () {
      expect(detectImageMime(_png()), 'image/png');
    });

    test('a WebP header is sniffed as image/webp', () {
      expect(detectImageMime(_webp()), 'image/webp');
    });

    test('empty bytes are not an image', () {
      expect(detectImageMime(Uint8List(0)), isNull);
    });

    test('a truncated JPEG magic prefix is not an image', () {
      expect(detectImageMime(_bytes([0xFF, 0xD8])), isNull);
    });

    test('a truncated PNG magic prefix is not an image', () {
      expect(
        detectImageMime(
          _bytes([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A]),
        ),
        isNull,
      );
    });

    test('a truncated WebP magic prefix is not an image', () {
      expect(
        detectImageMime(
          _bytes([0x52, 0x49, 0x46, 0x46, 0, 0, 0, 0, 0x57, 0x45]),
        ),
        isNull,
      );
    });

    test('arbitrary bytes are not an image', () {
      expect(detectImageMime(_bytes(List<int>.filled(64, 0x41))), isNull);
    });

    test('a partial JPEG prefix is not enough', () {
      // FF D8 alone is what a JPEG starts with, but the third byte must be
      // FF as well: a loose match would let any file claim the type.
      expect(detectImageMime(_bytes([0xFF, 0xD8, 0x41, 0x42])), isNull);
    });
  });

  group('isAcceptedPhotoMime', () {
    test('the three sniffed image types are accepted', () {
      expect(isAcceptedPhotoMime('image/jpeg'), isTrue);
      expect(isAcceptedPhotoMime('image/png'), isTrue);
      expect(isAcceptedPhotoMime('image/webp'), isTrue);
    });

    test('an unknown image type is refused', () {
      expect(isAcceptedPhotoMime('image/gif'), isFalse);
      expect(isAcceptedPhotoMime('image/heic'), isFalse);
    });

    test('a non-image type is refused', () {
      expect(isAcceptedPhotoMime('audio/mp4'), isFalse);
      expect(isAcceptedPhotoMime('application/octet-stream'), isFalse);
      expect(isAcceptedPhotoMime(''), isFalse);
    });

    test('a MIME with a trailing parameter is refused', () {
      expect(isAcceptedPhotoMime('image/jpeg; charset=utf-8'), isFalse);
    });
  });
}

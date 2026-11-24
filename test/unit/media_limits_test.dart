import 'dart:convert' show base64Encode;

import 'package:dtm_app/core/security_limits.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the text limit is untouched by the media limits', () {
    expect(maxPlaintextBytes, 4 * 1024);
  });

  test('a full media blob always fits into one wire frame', () {
    // The container is `<header>\n<base64(data)>`; the header is bounded by
    // the fields a media payload carries, generously padded here.
    const headerBytes = 512;
    final encoded = base64Encode(List<int>.filled(maxMediaBlobBytes, 0));
    final container = headerBytes + encoded.length;
    expect(container, lessThanOrEqualTo(maxFrameBytes));
    expect(container, lessThanOrEqualTo(maxMediaPlaintextBytes));
  });

  test('the media plaintext ceiling leaves room under the frame cap', () {
    expect(maxMediaPlaintextBytes, lessThan(maxFrameBytes));
  });

  test('a media blob is larger than a text message but bounded', () {
    expect(maxMediaBlobBytes, greaterThan(maxPlaintextBytes));
    expect(maxMediaBlobBytes, lessThanOrEqualTo(256 * 1024));
  });

  test('phase one carries exactly one envelope per media item', () {
    expect(maxMediaChunks, 1);
  });

  test('voice recording ceiling matches the announced 30 seconds', () {
    expect(maxVoiceMs, 30000);
    expect(minVoiceMs, lessThan(maxVoiceMs));
  });

  test('photo duration is not applicable and stays non-positive', () {
    expect(mediaVoiceKinds, contains('voice'));
    expect(mediaVoiceKinds, isNot(contains('photo')));
  });
}

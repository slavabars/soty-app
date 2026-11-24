import 'package:dtm_app/core/security_limits.dart';
import 'package:dtm_app/models/envelope.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Envelope valid() => Envelope(
    id: 'a' * 64,
    senderPubKey: 'b' * 64,
    recipientPubKey: 'c' * 64,
    timestamp: 1,
    ciphertext: 'Zg==',
    ephemeralPubKey: 'd' * 64,
    signature: 'e' * 128,
  );

  group('Envelope.decode size guard', () {
    test('accepts a valid encoding', () {
      expect(Envelope.decode(valid().encode()).id, valid().id);
    });

    test('rejects payloads larger than maxFrameBytes', () {
      final huge = 'x' * (maxFrameBytes + 1);
      expect(() => Envelope.decode(huge), throwsFormatException);
    });

    test('honours a custom maxBytes ceiling', () {
      expect(
        () => Envelope.decode(valid().encode(), maxBytes: 4),
        throwsFormatException,
      );
    });

    test('rejects non-object JSON', () {
      expect(() => Envelope.decode('[]'), throwsFormatException);
      expect(() => Envelope.decode('not json'), throwsFormatException);
    });
  });

  group('Envelope.fromJson validation', () {
    test('rejects an empty object', () {
      expect(() => Envelope.fromJson(const {}), throwsFormatException);
    });

    test('rejects mistyped fields', () {
      final json = valid().toJson()..['timestamp'] = 'now';
      expect(() => Envelope.fromJson(json), throwsFormatException);
    });

    test('rejects wrong key lengths', () {
      final short = valid().toJson()..['senderPubKey'] = 'aa';
      expect(() => Envelope.fromJson(short), throwsFormatException);

      final badSig = valid().toJson()..['signature'] = 'aa';
      expect(() => Envelope.fromJson(badSig), throwsFormatException);
    });

    test('rejects an empty ciphertext and non-hex id', () {
      final empty = valid().toJson()..['ciphertext'] = '';
      expect(() => Envelope.fromJson(empty), throwsFormatException);

      final badId = valid().toJson()..['id'] = 'zz' * 32;
      expect(() => Envelope.fromJson(badId), throwsFormatException);
    });

    test('accepts a fully valid object', () {
      final restored = Envelope.fromJson(valid().toJson());
      expect(restored.signature, valid().signature);
    });
  });

  test('toString tolerates truncated keys', () {
    const envelope = Envelope(
      id: 'ab',
      senderPubKey: 'cd',
      recipientPubKey: 'ef',
      timestamp: 0,
      ciphertext: 'x',
      ephemeralPubKey: 'gh',
      signature: 'ij',
    );
    expect(envelope.toString(), contains('Envelope'));
  });
}

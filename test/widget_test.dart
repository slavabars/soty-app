import 'package:dtm_app/core/crypto/keypair.dart';
import 'package:dtm_app/models/envelope.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('DtM app boots without a widget-level smoke test', () async {
    final kp = await DtmKeyPair.generate();
    expect(await kp.ed25519PublicKeyHex, isNotEmpty);
    expect(await kp.x25519PublicKeyHex, isNotEmpty);
  });

  test('Envelope JSON round-trip preserves every field', () {
    final envelope = Envelope(
      id: 'a' * 64,
      senderPubKey: 'b' * 64,
      recipientPubKey: 'c' * 64,
      timestamp: 123456789,
      ciphertext: 'ZGF0YQ==',
      ephemeralPubKey: 'e' * 64,
      signature: 'f' * 128,
    );
    final restored = Envelope.fromJson(envelope.toJson());
    expect(restored.id, envelope.id);
    expect(restored.senderPubKey, envelope.senderPubKey);
    expect(restored.recipientPubKey, envelope.recipientPubKey);
    expect(restored.timestamp, envelope.timestamp);
    expect(restored.ciphertext, envelope.ciphertext);
    expect(restored.ephemeralPubKey, envelope.ephemeralPubKey);
    expect(restored.signature, envelope.signature);
  });
}

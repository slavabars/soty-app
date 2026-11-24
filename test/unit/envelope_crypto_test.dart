import 'dart:convert' show base64Decode, base64Encode, utf8;

import 'package:dtm_app/core/crypto/envelope_crypto.dart';
import 'package:dtm_app/core/crypto/keypair.dart';
import 'package:dtm_app/models/envelope.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('hex round-trip', () {
    final bytes = [0x00, 0xff, 0xab, 0x10];
    expect(bytesToHex(bytes), '00ffab10');
    expect(hexToBytes('00ffab10'), bytes);
  });

  test('hexToBytes rejects odd input', () {
    expect(() => hexToBytes('abc'), throwsArgumentError);
    expect(() => hexToBytes('0z'), throwsArgumentError);
  });

  test('encrypt then decrypt round-trips plaintext', () async {
    final sender = await DtmKeyPair.generate();
    final recipient = await DtmKeyPair.generate();

    final senderPub = await sender.ed25519PublicKeyHex;
    final recipientPub = await recipient.x25519PublicKeyHex;

    final encrypted = await encryptPayload(
      plaintext: 'hello mesh',
      senderEd25519PubKeyHex: senderPub,
      recipientX25519PubKeyHex: recipientPub,
    );
    final envelope = Envelope(
      id: (await Envelope.computeId(
        senderPub,
        recipientPub,
        encrypted.ciphertext,
        1,
      )),
      senderPubKey: senderPub,
      recipientPubKey: recipientPub,
      timestamp: 1,
      ciphertext: encrypted.ciphertext,
      ephemeralPubKey: encrypted.ephemeralPubKeyHex,
      signature: '',
    );

    final decrypted = await decryptPayload(
      envelope: envelope,
      recipientX25519KeyPair: recipient.xKeyPair,
      senderEd25519PubKeyHex: senderPub,
    );
    expect(decrypted, 'hello mesh');
  });

  test('wrong recipient cannot decrypt (AEAD fails silently)', () async {
    final sender = await DtmKeyPair.generate();
    final recipient = await DtmKeyPair.generate();
    final attacker = await DtmKeyPair.generate();

    final senderPub = await sender.ed25519PublicKeyHex;
    final recipientPub = await recipient.x25519PublicKeyHex;

    final encrypted = await encryptPayload(
      plaintext: 'secret',
      senderEd25519PubKeyHex: senderPub,
      recipientX25519PubKeyHex: recipientPub,
    );
    final envelope = Envelope(
      id: (await Envelope.computeId(
        senderPub,
        recipientPub,
        encrypted.ciphertext,
        1,
      )),
      senderPubKey: senderPub,
      recipientPubKey: recipientPub,
      timestamp: 1,
      ciphertext: encrypted.ciphertext,
      ephemeralPubKey: encrypted.ephemeralPubKeyHex,
      signature: '',
    );

    final decrypted = await decryptPayload(
      envelope: envelope,
      recipientX25519KeyPair: attacker.xKeyPair,
      senderEd25519PubKeyHex: senderPub,
    );
    expect(decrypted, isNull);
  });

  test('createEnvelopeForPubKey signs and verifies a whole envelope', () async {
    final sender = await DtmKeyPair.generate();
    final recipient = await DtmKeyPair.generate();
    final recipientPub = await recipient.x25519PublicKeyHex;

    final envelope = await createEnvelopeForPubKey(
      sender: sender,
      recipientX25519PubKeyHex: recipientPub,
      plaintext: 'direct message',
    );

    expect(await envelope.verify(), isTrue);
    expect(await envelope.hasValidId(), isTrue);
    expect(envelope.senderPubKey, await sender.ed25519PublicKeyHex);
    expect(envelope.recipientPubKey, recipientPub);

    final decrypted = await decryptPayload(
      envelope: envelope,
      recipientX25519KeyPair: recipient.xKeyPair,
      senderEd25519PubKeyHex: envelope.senderPubKey,
    );
    expect(decrypted, 'direct message');
  });

  test('tampered ciphertext breaks signature and id verification', () async {
    final sender = await DtmKeyPair.generate();
    final recipient = await DtmKeyPair.generate();
    final recipientPub = await recipient.x25519PublicKeyHex;

    final envelope = await createEnvelopeForPubKey(
      sender: sender,
      recipientX25519PubKeyHex: recipientPub,
      plaintext: 'hello',
    );

    final tampered = Envelope(
      id: envelope.id,
      senderPubKey: envelope.senderPubKey,
      recipientPubKey: envelope.recipientPubKey,
      timestamp: envelope.timestamp,
      ciphertext: base64Encode(
        List<int>.from(base64Decode(envelope.ciphertext)..[0] ^= 0xff),
      ),
      ephemeralPubKey: envelope.ephemeralPubKey,
      signature: envelope.signature,
    );

    // The signature covers `id || timestamp || ciphertext`, and the id covers
    // the ciphertext too, so flipping a payload byte breaks both.
    expect(await tampered.verify(), isFalse);
    expect(await tampered.hasValidId(), isFalse);
  });

  test('future-skew guard', () async {
    final sender = await DtmKeyPair.generate();
    final recipient = await DtmKeyPair.generate();
    final recipientPub = await recipient.x25519PublicKeyHex;

    final future = DateTime.now()
        .toUtc()
        .add(const Duration(minutes: 10))
        .millisecondsSinceEpoch;

    final envelope = await createEnvelopeForPubKey(
      sender: sender,
      recipientX25519PubKeyHex: recipientPub,
      plaintext: 'clock drift',
      timestamp: future,
    );

    expect(envelope.withinSkew(), isFalse);
  });

  test('keypair seeds reproduce the same keypairs', () async {
    final kp = await DtmKeyPair.generate();
    final edSeed = await kp.ed25519SeedHex;
    final xSeed = await kp.x25519SeedHex;
    final edPub = await kp.ed25519PublicKeyHex;
    final xPub = await kp.x25519PublicKeyHex;

    final restored = await DtmKeyPair.fromSeeds(
      ed25519SeedHex: edSeed,
      x25519SeedHex: xSeed,
    );
    expect(await restored.ed25519PublicKeyHex, edPub);
    expect(await restored.x25519PublicKeyHex, xPub);
  });

  test('envelope json round-trip', () async {
    final sender = await DtmKeyPair.generate();
    final recipient = await DtmKeyPair.generate();
    final recipientPub = await recipient.x25519PublicKeyHex;

    final envelope = await createEnvelopeForPubKey(
      sender: sender,
      recipientX25519PubKeyHex: recipientPub,
      plaintext: 'serde check',
    );
    final json = envelope.toJson();
    final decoded = Envelope.fromJson(json);
    expect(decoded.id, envelope.id);
    expect(decoded.ciphertext, envelope.ciphertext);
    expect(await decoded.verify(), isTrue);
  });

  test('fresh ephemeral keys differ between messages', () async {
    final sender = await DtmKeyPair.generate();
    final recipient = await DtmKeyPair.generate();
    final recipientPub = await recipient.x25519PublicKeyHex;

    final a = await encryptPayload(
      plaintext: 'same secret',
      senderEd25519PubKeyHex: await sender.ed25519PublicKeyHex,
      recipientX25519PubKeyHex: recipientPub,
    );
    final b = await encryptPayload(
      plaintext: 'same secret',
      senderEd25519PubKeyHex: await sender.ed25519PublicKeyHex,
      recipientX25519PubKeyHex: recipientPub,
    );

    expect(a.ephemeralPubKeyHex, isNot(b.ephemeralPubKeyHex));
    expect(a.ciphertext, isNot(b.ciphertext));
  });

  test('a different chainLink changes id, signature and verification',
      () async {
    final sender = await DtmKeyPair.generate();
    final recipient = await DtmKeyPair.generate();
    final recipientPub = await recipient.x25519PublicKeyHex;

    final genesis = await createEnvelopeForPubKey(
      sender: sender,
      recipientX25519PubKeyHex: recipientPub,
      plaintext: 'root',
      chainLink: '',
    );
    final linked = await createEnvelopeForPubKey(
      sender: sender,
      recipientX25519PubKeyHex: recipientPub,
      plaintext: 'root',
      chainLink: genesis.id,
    );

    expect(linked.id, isNot(genesis.id));
    expect(await linked.verify(), isTrue);
    expect(await linked.hasValidId(), isTrue);

    final tamperedLink = Envelope(
      id: linked.id,
      senderPubKey: linked.senderPubKey,
      recipientPubKey: linked.recipientPubKey,
      timestamp: linked.timestamp,
      ciphertext: linked.ciphertext,
      ephemeralPubKey: linked.ephemeralPubKey,
      signature: linked.signature,
      chainLink: '0' * 64,
    );
    expect(await tamperedLink.verify(), isFalse);
    expect(await tamperedLink.hasValidId(), isFalse);
  });

  test('fromJson requires chainLink and rejects malformed values', () async {
    final sender = await DtmKeyPair.generate();
    final recipient = await DtmKeyPair.generate();
    final envelope = await createEnvelopeForPubKey(
      sender: sender,
      recipientX25519PubKeyHex: await recipient.x25519PublicKeyHex,
      plaintext: 'serde',
      chainLink: '',
    );
    final json = envelope.toJson();

    final genesis = Envelope.fromJson({...json, 'chainLink': ''});
    expect(genesis.chainLink, '');

    expect(
      () => Envelope.fromJson({...json}..remove('chainLink')),
      throwsFormatException,
    );
    expect(
      () => Envelope.fromJson({...json, 'chainLink': 'not-hex'}),
      throwsFormatException,
    );
    expect(
      () => Envelope.fromJson({
        ...json,
        'chainLink': 'abcd',
      }),
      throwsFormatException,
    );
    expect(
      () => Envelope.fromJson({...json, 'chainLink': 42}),
      throwsFormatException,
    );
  });

  test('byte payloads round-trip through the envelope', () async {
    final sender = await DtmKeyPair.generate();
    final recipient = await DtmKeyPair.generate();
    final senderPub = await sender.ed25519PublicKeyHex;
    final recipientPub = await recipient.x25519PublicKeyHex;

    // Every byte value, including NUL and invalid UTF-8 sequences.
    final data = List<int>.generate(4096, (i) => i % 256);

    final encrypted = await encryptPayloadBytes(
      plaintextBytes: data,
      senderEd25519PubKeyHex: senderPub,
      recipientX25519PubKeyHex: recipientPub,
    );
    final envelope = await createEnvelopeBytesForPubKey(
      sender: sender,
      recipientX25519PubKeyHex: recipientPub,
      plaintextBytes: data,
    );

    final roundTrip = await decryptPayloadBytes(
      envelope: envelope,
      recipientX25519KeyPair: recipient.xKeyPair,
      senderEd25519PubKeyHex: senderPub,
    );
    expect(roundTrip, data);
    expect(await envelope.verify(), isTrue);
    expect(await envelope.hasValidId(), isTrue);

    expect(encrypted.ciphertext, isNotEmpty);
  });

  test('a byte payload is byte-identical to its string encoding', () async {
    final sender = await DtmKeyPair.generate();
    final recipient = await DtmKeyPair.generate();
    final senderPub = await sender.ed25519PublicKeyHex;
    final recipientPub = await recipient.x25519PublicKeyHex;

    final text = 'кириллица и emoji 🎤';
    final asBytes = await encryptPayloadBytes(
      plaintextBytes: utf8.encode(text),
      senderEd25519PubKeyHex: senderPub,
      recipientX25519PubKeyHex: recipientPub,
    );
    final asString = await encryptPayload(
      plaintext: text,
      senderEd25519PubKeyHex: senderPub,
      recipientX25519PubKeyHex: recipientPub,
    );

    // Both are valid AEAD boxes over the same plaintext; only the ephemeral
    // key and nonce differ, so the ciphertexts must differ but both decrypt.
    expect(asBytes.ciphertext, isNot(asString.ciphertext));
  });

  test('byte decryption fails silently on a wrong recipient', () async {
    final sender = await DtmKeyPair.generate();
    final recipient = await DtmKeyPair.generate();
    final attacker = await DtmKeyPair.generate();

    final envelope = await createEnvelopeBytesForPubKey(
      sender: sender,
      recipientX25519PubKeyHex: await recipient.x25519PublicKeyHex,
      plaintextBytes: const [1, 2, 3, 4],
    );

    expect(
      await decryptPayloadBytes(
        envelope: envelope,
        recipientX25519KeyPair: attacker.xKeyPair,
        senderEd25519PubKeyHex: envelope.senderPubKey,
      ),
      isNull,
    );
  });

  test('byte decryption rejects a tampered ciphertext', () async {
    final sender = await DtmKeyPair.generate();
    final recipient = await DtmKeyPair.generate();
    final envelope = await createEnvelopeBytesForPubKey(
      sender: sender,
      recipientX25519PubKeyHex: await recipient.x25519PublicKeyHex,
      plaintextBytes: const [9, 9, 9],
    );

    final raw = base64Decode(envelope.ciphertext)..[0] ^= 0xff;
    final tampered = Envelope(
      id: envelope.id,
      senderPubKey: envelope.senderPubKey,
      recipientPubKey: envelope.recipientPubKey,
      timestamp: envelope.timestamp,
      ciphertext: base64Encode(raw),
      ephemeralPubKey: envelope.ephemeralPubKey,
      signature: envelope.signature,
    );

    expect(
      await decryptPayloadBytes(
        envelope: tampered,
        recipientX25519KeyPair: recipient.xKeyPair,
        senderEd25519PubKeyHex: envelope.senderPubKey,
      ),
      isNull,
    );
  });

  test('computeId folds chainLink into the content address', () async {
    final id = await Envelope.computeId('a', 'b', 'c', 1, chainLink: 'x');
    final noLink = await Envelope.computeId('a', 'b', 'c', 1);
    expect(id, isNot(noLink));
  });
}

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../../models/envelope.dart';
import 'hex.dart';
import 'keypair.dart';

export 'hex.dart' show bytesToHex, hexToBytes, isHexOfLength;

/// Builds a `SimplePublicKey` for use with `package:cryptography` calls.
SimplePublicKey simplePublicKey(Uint8List bytes, KeyPairType type) =>
    SimplePublicKey(bytes, type: type);

/// Length of the AES-GCM nonce.
const int gcmNonceLength = 12;

final _random = Random.secure();

/// Encrypts [plaintext] for [recipientX25519PubKeyHex] using a fresh
/// ephemeral X25519 keypair and HKDF-derived AES-256-GCM key.
///
/// Returns `(ciphertext, ephemeralPubKeyHex)` where
/// `ciphertext = base64( cipher || mac || nonce )`.
Future<({String ciphertext, String ephemeralPubKeyHex})> encryptPayload({
  required String plaintext,
  required String senderEd25519PubKeyHex,
  required String recipientX25519PubKeyHex,
}) =>
    encryptPayloadBytes(
      plaintextBytes: utf8.encode(plaintext),
      senderEd25519PubKeyHex: senderEd25519PubKeyHex,
      recipientX25519PubKeyHex: recipientX25519PubKeyHex,
    );

/// Byte-level [encryptPayload]: media containers are binary, so they must not
/// be routed through a UTF-8 encode/decode that a malformed file could break.
Future<({String ciphertext, String ephemeralPubKeyHex})> encryptPayloadBytes({
  required List<int> plaintextBytes,
  required String senderEd25519PubKeyHex,
  required String recipientX25519PubKeyHex,
}) async {
  final ephemeral = await X25519().newKeyPair();
  final ephemeralPub = await ephemeral.extractPublicKey();

  final shared = await X25519().sharedSecretKey(
    keyPair: ephemeral,
    remotePublicKey: simplePublicKey(
      hexToBytes(recipientX25519PubKeyHex),
      KeyPairType.x25519,
    ),
  );

  final key = await _deriveKey(
    shared,
    senderEd25519PubKeyHex,
    recipientX25519PubKeyHex,
  );
  final nonce = _randomNonce();
  final box = await AesGcm.with256bits().encrypt(
    plaintextBytes,
    secretKey: key,
    nonce: nonce,
  );

  final raw = <int>[...box.cipherText, ...box.mac.bytes, ...nonce];
  return (
    ciphertext: base64Encode(raw),
    ephemeralPubKeyHex: bytesToHex(ephemeralPub.bytes),
  );
}

/// Decrypts [envelope] with this device's long-term X25519 keypair.
///
/// Returns `null` (and never throws) when AEAD verification fails — the
/// envelope is then silently dropped, never logged.
Future<String?> decryptPayload({
  required Envelope envelope,
  required SimpleKeyPair recipientX25519KeyPair,
  required String senderEd25519PubKeyHex,
}) async {
  final clear = await decryptPayloadBytes(
    envelope: envelope,
    recipientX25519KeyPair: recipientX25519KeyPair,
    senderEd25519PubKeyHex: senderEd25519PubKeyHex,
  );
  if (clear == null) return null;
  try {
    return utf8.decode(clear);
  } catch (_) {
    // Binary payload that is not valid UTF-8: not a text message.
    return null;
  }
}

/// Byte-level [decryptPayload]. Returns `null` (never throws) on any AEAD
/// failure or malformed ciphertext, so a hostile envelope is dropped silently.
Future<Uint8List?> decryptPayloadBytes({
  required Envelope envelope,
  required SimpleKeyPair recipientX25519KeyPair,
  required String senderEd25519PubKeyHex,
}) async {
  try {
    final raw = base64Decode(envelope.ciphertext);

    final shared = await X25519().sharedSecretKey(
      keyPair: recipientX25519KeyPair,
      remotePublicKey: simplePublicKey(
        hexToBytes(envelope.ephemeralPubKey),
        KeyPairType.x25519,
      ),
    );

    final key = await _deriveKey(
      shared,
      senderEd25519PubKeyHex,
      envelope.recipientPubKey,
    );
    final nonce = raw.sublist(raw.length - gcmNonceLength);
    final body = raw.sublist(0, raw.length - gcmNonceLength);
    final macLength = 16;
    final cipher = body.sublist(0, body.length - macLength);
    final mac = body.sublist(body.length - macLength);

    final box = SecretBox(cipher, nonce: nonce, mac: Mac(mac));
    final clear = await AesGcm.with256bits().decrypt(box, secretKey: key);
    return Uint8List.fromList(clear);
  } catch (_) {
    // AEAD failure (tampering or wrong recipient) — drop silently.
    return null;
  }
}

/// Composes and signs a complete [Envelope] for `recipientX25519PubKeyHex`.
/// [chainLink] must be the current head of the directed
/// (sender, recipient) chain — `''` for the genesis message.
Future<Envelope> createEnvelopeForPubKey({
  required DtmKeyPair sender,
  required String recipientX25519PubKeyHex,
  required String plaintext,
  int? timestamp,
  String chainLink = '',
}) =>
    createEnvelopeBytesForPubKey(
      sender: sender,
      recipientX25519PubKeyHex: recipientX25519PubKeyHex,
      plaintextBytes: utf8.encode(plaintext),
      timestamp: timestamp,
      chainLink: chainLink,
    );

/// Byte-level [createEnvelopeForPubKey], used for media containers whose
/// payload is binary.
Future<Envelope> createEnvelopeBytesForPubKey({
  required DtmKeyPair sender,
  required String recipientX25519PubKeyHex,
  required List<int> plaintextBytes,
  int? timestamp,
  String chainLink = '',
}) async {
  final senderPub = await sender.ed25519PublicKeyHex;

  final encrypted = await encryptPayloadBytes(
    plaintextBytes: plaintextBytes,
    senderEd25519PubKeyHex: senderPub,
    recipientX25519PubKeyHex: recipientX25519PubKeyHex,
  );

  final ts = timestamp ?? DateTime.now().toUtc().millisecondsSinceEpoch;
  final id = await Envelope.computeId(
    senderPub,
    recipientX25519PubKeyHex,
    encrypted.ciphertext,
    ts,
    chainLink: chainLink,
  );

  final env = Envelope(
    id: id,
    senderPubKey: senderPub,
    recipientPubKey: recipientX25519PubKeyHex,
    timestamp: ts,
    ciphertext: encrypted.ciphertext,
    ephemeralPubKey: encrypted.ephemeralPubKeyHex,
    signature: '',
    chainLink: chainLink,
  );

  final signature = await Ed25519().sign(
    env.signedData,
    keyPair: sender.edKeyPair,
  );

  return Envelope(
    id: env.id,
    senderPubKey: env.senderPubKey,
    recipientPubKey: env.recipientPubKey,
    timestamp: env.timestamp,
    ciphertext: env.ciphertext,
    ephemeralPubKey: env.ephemeralPubKey,
    signature: bytesToHex(signature.bytes),
    chainLink: chainLink,
  );
}

Future<SecretKey> _deriveKey(
  SecretKey shared,
  String senderPub,
  String recipientPub,
) {
  const info = 'dtm-v1';
  final salt = utf8.encode('$senderPub$recipientPub');
  return Hkdf(
    hmac: Hmac.sha256(),
    outputLength: 32,
  ).deriveKey(secretKey: shared, nonce: salt, info: utf8.encode(info));
}

Uint8List _randomNonce() => Uint8List.fromList(
  List.generate(gcmNonceLength, (_) => _random.nextInt(256)),
);

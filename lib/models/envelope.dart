import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import '../core/crypto/envelope_crypto.dart'
    show bytesToHex, hexToBytes, simplePublicKey;
import '../core/crypto/hex.dart' show isHexOfLength;
import '../core/security_limits.dart' show maxFrameBytes;

/// Wire format for every message that travels through DTM.
///
/// The payload is always E2EE: intermediate nodes and relays only ever see
/// [ciphertext] plus the metadata below. They can verify authenticity with
/// [verify] but can never decrypt (except the intended recipient).
///
/// Identity keys (Ed25519) are distinct from transport keys (X25519).
class Envelope {
  /// SHA-256 over `sender || recipient || ciphertext || ts || chainLink`.
  final String id;

  /// Sender Ed25519 public key (hex).
  final String senderPubKey;

  /// Recipient X25519 public key (hex).
  final String recipientPubKey;

  /// UTC milliseconds at which the message was created.
  final int timestamp;

  /// base64(AES-256-GCM(payload) || nonce).
  final String ciphertext;

  /// Sender's ephemeral X25519 public key (hex).
  final String ephemeralPubKey;

  /// Ed25519 signature over `id || timestamp || ciphertext || chainLink`.
  final String signature;

  /// The previous envelope id in this directed (sender, recipient) chain;
  /// empty for the genesis message. Binding it into [id] and the signature
  /// makes any substitution/addition detectable (anti-fake history).
  final String chainLink;

  const Envelope({
    required this.id,
    required this.senderPubKey,
    required this.recipientPubKey,
    required this.timestamp,
    required this.ciphertext,
    required this.ephemeralPubKey,
    required this.signature,
    this.chainLink = '',
  });

  /// Strict field parsing. Any missing/mistyped field or malformed hex key
  /// throws [FormatException] so hostile JSON is rejected at the boundary
  /// before any crypto work runs.
  factory Envelope.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final sender = json['senderPubKey'];
    final recipient = json['recipientPubKey'];
    final timestamp = json['timestamp'];
    final ciphertext = json['ciphertext'];
    final ephemeral = json['ephemeralPubKey'];
    final signature = json['signature'];
    final chainLink = json['chainLink'];
    if (id is! String ||
        sender is! String ||
        recipient is! String ||
        timestamp is! int ||
        ciphertext is! String ||
        ephemeral is! String ||
        signature is! String ||
        chainLink is! String) {
      throw const FormatException('Envelope field is missing or mistyped');
    }
    if (!isHexOfLength(id, 32) ||
        !isHexOfLength(sender, 32) ||
        !isHexOfLength(recipient, 32) ||
        !isHexOfLength(ephemeral, 32) ||
        !isHexOfLength(signature, 64) ||
        ciphertext.isEmpty ||
        (chainLink.isNotEmpty && !isHexOfLength(chainLink, 32))) {
      throw const FormatException('Envelope field format is invalid');
    }
    return Envelope(
      id: id,
      senderPubKey: sender,
      recipientPubKey: recipient,
      timestamp: timestamp,
      ciphertext: ciphertext,
      ephemeralPubKey: ephemeral,
      signature: signature,
      chainLink: chainLink,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'senderPubKey': senderPubKey,
    'recipientPubKey': recipientPubKey,
    'timestamp': timestamp,
    'ciphertext': ciphertext,
    'ephemeralPubKey': ephemeralPubKey,
    'signature': signature,
    'chainLink': chainLink,
  };

  String encode() => jsonEncode(toJson());

  /// Parses [raw] with a byte-size ceiling of [maxBytes]. Callers hand bytes
  /// from the wire, so the guard runs *before* any allocation happens.
  static Envelope decode(String raw, {int maxBytes = maxFrameBytes}) {
    if (raw.length > maxBytes) {
      throw const FormatException('Envelope exceeds the maximum frame size');
    }
    final json = jsonDecode(raw);
    if (json is! Map<String, dynamic>) {
      throw const FormatException('Envelope must be a JSON object');
    }
    return Envelope.fromJson(json);
  }

  /// Deterministic content address per the crypto-envelope skill. The
  /// [chainLink] is folded in so a message can only point at one predecessor.
  static Future<String> computeId(
    String senderPubKey,
    String recipientPubKey,
    String ciphertext,
    int timestamp, {
    String chainLink = '',
  }) async {
    final digest = await Sha256().hash(
      utf8.encode(
        '$senderPubKey'
        '$recipientPubKey'
        '$ciphertext'
        '$timestamp'
        '$chainLink',
      ),
    );
    return bytesToHex(digest.bytes);
  }

  /// The exact bytes that are signed/verified:
  /// `id || timestamp || ciphertext || chainLink`.
  List<int> get signedData => utf8.encode('$id$timestamp$ciphertext$chainLink');

  /// Verifies that [signature] matches [senderPubKey] over the signed data.
  Future<bool> verify() async {
    final pub = simplePublicKey(hexToBytes(senderPubKey), KeyPairType.ed25519);
    final verified = await Ed25519().verify(
      signedData,
      signature: Signature(hexToBytes(signature), publicKey: pub),
    );
    return verified;
  }

  /// Recomputes [id] from the payload and compares it with self.
  Future<bool> hasValidId() async {
    final expected = await computeId(
      senderPubKey,
      recipientPubKey,
      ciphertext,
      timestamp,
      chainLink: chainLink,
    );
    return expected == id;
  }

  /// Rejects envelopes stamped more than [maxFutureSkew] in the future.
  bool withinSkew({Duration maxFutureSkew = const Duration(minutes: 5)}) {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    return timestamp <= now + maxFutureSkew.inMilliseconds;
  }

  Envelope copyWith({String? source}) => this;

  @override
  String toString() =>
      'Envelope(id: $id, from: ${_first8(senderPubKey)}, '
      'to: ${_first8(recipientPubKey)}, ts: $timestamp)';

  static String _first8(String hex) =>
      hex.length >= 8 ? hex.substring(0, 8) : hex;
}

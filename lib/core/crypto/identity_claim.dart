import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import '../security_limits.dart';
import 'hex.dart';
import 'keypair.dart';

/// Result of [IdentityClaim.check].
enum ClaimStatus {
  /// Structure, signature and age all check out.
  valid,

  /// Field shape is unusable (bad key/signature hex, name too long).
  malformed,

  /// Signature does not match the Ed25519 key.
  badSignature,

  /// [IdentityClaim.createdAt] is too far in the future (clock tampering).
  future,

  /// [IdentityClaim.createdAt] is older than [maxClaimAge].
  expired,
}

/// Binds an Ed25519 identity to the X25519 routing key it advertises.
///
/// Without this binding, a hostile relay could advertise any X25519 key under
/// its own identity and decrypt messages meant for its victim (impersonation).
/// The claim is signed by the identity's Ed25519 key over
/// `dtm-id-v2 || edPubKey || xPubKey || displayName || createdAt`.
class IdentityClaim {
  static const String _prefix = 'dtm-id-v2|';

  /// 32-byte Ed25519 public key (hex).
  final String edPubKey;

  /// 32-byte X25519 public key (hex) — the routing key peers address.
  final String xPubKey;

  /// Bounded by [maxDisplayNameLength].
  final String displayName;

  /// UTC milliseconds at which the claim was created.
  final int createdAt;

  /// 64-byte Ed25519 signature (hex).
  final String signature;

  const IdentityClaim({
    required this.edPubKey,
    required this.xPubKey,
    required this.displayName,
    required this.createdAt,
    required this.signature,
  });

  /// Signs a fresh claim for [identity]. Throws [ArgumentError] when
  /// [displayName] exceeds [maxDisplayNameLength].
  static Future<IdentityClaim> forIdentity({
    required DtmKeyPair identity,
    required String displayName,
    int? createdAt,
  }) async {
    if (displayName.length > maxDisplayNameLength) {
      throw ArgumentError(
        'Display name must not exceed $maxDisplayNameLength characters',
      );
    }
    final edPub = await identity.ed25519PublicKeyHex;
    final xPub = await identity.x25519PublicKeyHex;
    final ts = createdAt ?? DateTime.now().toUtc().millisecondsSinceEpoch;
    final unsigned = IdentityClaim(
      edPubKey: edPub,
      xPubKey: xPub,
      displayName: displayName,
      createdAt: ts,
      signature: '',
    );
    final signature = await Ed25519().sign(
      unsigned.signedData,
      keyPair: identity.edKeyPair,
    );
    return IdentityClaim(
      edPubKey: edPub,
      xPubKey: xPub,
      displayName: displayName,
      createdAt: ts,
      signature: bytesToHex(signature.bytes),
    );
  }

  /// Exact bytes covered by the signature.
  List<int> get signedData =>
      utf8.encode('$_prefix$edPubKey$xPubKey$displayName$createdAt');

  /// Full validation: shape → age → signature. Never throws for malformed
  /// field *values*; they map to [ClaimStatus.malformed].
  Future<ClaimStatus> check() async {
    if (!isHexOfLength(edPubKey, 32) ||
        !isHexOfLength(xPubKey, 32) ||
        !isHexOfLength(signature, 64) ||
        displayName.length > maxDisplayNameLength) {
      return ClaimStatus.malformed;
    }
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    if (createdAt > now + maxClockSkew.inMilliseconds) {
      return ClaimStatus.future;
    }
    if (createdAt < now - maxClaimAge.inMilliseconds) {
      return ClaimStatus.expired;
    }
    final publicKey = SimplePublicKey(
      hexToBytes(edPubKey),
      type: KeyPairType.ed25519,
    );
    final verified = await Ed25519().verify(
      signedData,
      signature: Signature(hexToBytes(signature), publicKey: publicKey),
    );
    return verified ? ClaimStatus.valid : ClaimStatus.badSignature;
  }

  Future<bool> isValid() async => await check() == ClaimStatus.valid;

  String encode() => jsonEncode(toJson());

  /// Parses a claim from a wire/invite JSON string. Throws [FormatException]
  /// when the shape is unusable (non-object, missing or mistyped fields).
  static IdentityClaim decode(String raw) {
    final json = jsonDecode(raw);
    if (json is! Map<String, dynamic>) {
      throw const FormatException('Identity claim must be a JSON object');
    }
    return IdentityClaim.fromJson(json);
  }

  /// Strict field parsing; any missing/badly-typed field throws
  /// [FormatException]. Values are re-verified by [check] later.
  factory IdentityClaim.fromJson(Map<String, dynamic> json) {
    final ed = json['edPubKey'];
    final x = json['xPubKey'];
    final name = json['displayName'];
    final ts = json['createdAt'];
    final sig = json['signature'];
    if (ed is! String ||
        x is! String ||
        name is! String ||
        ts is! int ||
        sig is! String) {
      throw const FormatException(
        'Identity claim field is missing or mistyped',
      );
    }
    return IdentityClaim(
      edPubKey: ed,
      xPubKey: x,
      displayName: name,
      createdAt: ts,
      signature: sig,
    );
  }

  Map<String, dynamic> toJson() => {
    'edPubKey': edPubKey,
    'xPubKey': xPubKey,
    'displayName': displayName,
    'createdAt': createdAt,
    'signature': signature,
  };

  @override
  String toString() {
    final name = displayName.isEmpty ? '?' : displayName;
    return 'IdentityClaim($name, ed: ${_shorten(edPubKey)}, '
        'x: ${_shorten(xPubKey)})';
  }

  static String _shorten(String hex) {
    if (hex.length < 16) return hex;
    return '${hex.substring(0, 8)}…${hex.substring(hex.length - 6)}';
  }
}

import 'package:cryptography/cryptography.dart';

import 'hex.dart';

/// A full DTM identity.
///
/// * [edKeyPair] — Ed25519 for identity, message signing and verification.
/// * [xKeyPair]  — X25519 for ECDH key exchange (the address peers send to).
///
/// One identity can be shared across several devices (multi-client). Only the
/// public halves leave the device.
class DtmKeyPair {
  final SimpleKeyPair edKeyPair;
  final SimpleKeyPair xKeyPair;

  const DtmKeyPair({required this.edKeyPair, required this.xKeyPair});

  static Future<DtmKeyPair> generate() async {
    final ed = await Ed25519().newKeyPair();
    final x = await X25519().newKeyPair();
    return DtmKeyPair(edKeyPair: ed, xKeyPair: x);
  }

  /// Rebuilds the keypair from two 32-byte hex seeds (32-byte private keys).
  static Future<DtmKeyPair> fromSeeds({
    required String ed25519SeedHex,
    required String x25519SeedHex,
  }) async {
    final ed = await Ed25519().newKeyPairFromSeed(_seed(ed25519SeedHex));
    final x = await X25519().newKeyPairFromSeed(_seed(x25519SeedHex));
    return DtmKeyPair(edKeyPair: ed, xKeyPair: x);
  }

  static List<int> _seed(String hex) => hexToBytes(hex);

  Future<SimplePublicKey> get edPublic async => edKeyPair.extractPublicKey();

  Future<SimplePublicKey> get xPublic async => xKeyPair.extractPublicKey();

  Future<String> get ed25519PublicKeyHex async {
    final pub = await edPublic;
    return pub.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  Future<String> get x25519PublicKeyHex async {
    final pub = await xPublic;
    return pub.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  Future<String> get ed25519SeedHex async {
    final seed = await edKeyPair.extractPrivateKeyBytes();
    return seed.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  Future<String> get x25519SeedHex async {
    final seed = await xKeyPair.extractPrivateKeyBytes();
    return seed.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}

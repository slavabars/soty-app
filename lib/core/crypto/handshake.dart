import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

import 'hex.dart';
import 'keypair.dart';

/// Domain-separated handshake proofs shared by the app and both relays.
///
/// A relay signs a [welcomeProofData] string with the Ed25519 key it advertises
/// as `WELCOME.identity`; the client verifies it against the pinned key. A
/// federated host signs [federationProofData] with the key it claims in
/// `HELLO.myPeerId`, proving possession of that key rather than merely naming
/// a public value.

String randomHandshakeNonce() {
  final rng = Random.secure();
  return List<String>.generate(
    32,
    (_) => rng.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}

List<int> welcomeProofData({
  required String nonce,
  required int serverTime,
  required String identity,
  required List<String> capabilities,
}) =>
    utf8.encode(
      'dtm-welcome-v1|$nonce|$serverTime|$identity|'
      '${capabilities.join(',')}',
    );

List<int> federationProofData({
  required String challenge,
  required String peerId,
  required String announce,
}) =>
    utf8.encode('dtm-fed-v1|$challenge|$peerId|$announce');

Future<String> signHandshakeData(
  DtmKeyPair keyPair,
  List<int> data,
) async {
  final signature = await Ed25519().sign(data, keyPair: keyPair.edKeyPair);
  return bytesToHex(signature.bytes);
}

Future<bool> verifyHandshakeData({
  required String publicKeyHex,
  required List<int> data,
  required String signatureHex,
}) async {
  if (!isHexOfLength(publicKeyHex, 32) || !isHexOfLength(signatureHex, 64)) {
    return false;
  }
  final publicKey = SimplePublicKey(
    hexToBytes(publicKeyHex),
    type: KeyPairType.ed25519,
  );
  return Ed25519().verify(
    data,
    signature: Signature(hexToBytes(signatureHex), publicKey: publicKey),
  );
}

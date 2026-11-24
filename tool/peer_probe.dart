// ignore_for_file: avoid_print

import 'dart:typed_data';

import 'package:dart_libp2p/core/crypto/ed25519.dart' as lp_ed;
import 'package:dart_libp2p/core/peer/peer_id.dart';
import 'package:dtm_app/core/crypto/hex.dart' show hexToBytes;
import 'package:dtm_app/core/crypto/keypair.dart';

import 'tool_identity.dart';

/// Prints the identity (ed/x public keys + libp2p peer id) of a device. Usage:
///   `dart run tool/peer_probe.dart DIR`, where DIR holds `identity.json`
///   (see `tool/identity_probe.dart`) or a legacy `dtm.sqlite`.
Future<void> main(List<String> args) async {
  if (args.length != 1) {
    print('usage: dart run tool/peer_probe.dart <dir>');
    return;
  }
  final identity = identityFromDirectory(args[0]);
  if (identity == null) return;
  final kp = await DtmKeyPair.fromSeeds(
    ed25519SeedHex: identity.edSeedHex,
    x25519SeedHex: identity.xSeedHex,
  );
  final lp = await lp_ed.generateEd25519KeyPairFromSeed(
    Uint8List.fromList(hexToBytes(await kp.ed25519SeedHex)),
  );
  print('name    ${identity.displayName}');
  print('edPub   ${await kp.ed25519PublicKeyHex}');
  print('xPub    ${await kp.x25519PublicKeyHex}');
  print('peerId  ${PeerId.fromPrivateKey(lp.privateKey)}');
}

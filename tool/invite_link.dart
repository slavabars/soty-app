// ignore_for_file: avoid_print

import 'package:dtm_app/core/crypto/identity_claim.dart';
import 'package:dtm_app/core/crypto/keypair.dart';
import 'package:dtm_app/core/invite_link.dart';

import 'tool_identity.dart';

/// Prints a fresh signed `soty://invite?claim=...` deep link for the identity
/// stored in a device database. Usage:
///   `dart run tool/invite_link.dart DIR` (with `DIR/dtm.sqlite`)
Future<void> main(List<String> args) async {
  if (args.length != 1) {
    print('usage: dart run tool/invite_link.dart <dir>');
    return;
  }
  final identity = identityFromDirectory(args[0]);
  if (identity == null) return;
  final kp = await DtmKeyPair.fromSeeds(
    ed25519SeedHex: identity.edSeedHex,
    x25519SeedHex: identity.xSeedHex,
  );
  final claim = await IdentityClaim.forIdentity(
    identity: kp,
    displayName: identity.displayName,
  );
  print(InviteLink.encode(claim.encode()));
}
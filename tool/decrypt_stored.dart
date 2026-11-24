// ignore_for_file: avoid_print

import 'dart:ffi';

import 'package:dtm_app/core/crypto/envelope_crypto.dart';
import 'package:dtm_app/core/crypto/keypair.dart';
import 'package:dtm_app/models/envelope.dart';
import 'package:sqlite3/open.dart';
import 'package:sqlite3/sqlite3.dart';

import 'tool_identity.dart';

/// Offline verification of the e2e path: opens an app database pulled from a
/// device, verifies every stored envelope's signature/id, and decrypts it with
/// the device's own X25519 key. Usage:
///   `dart run tool/decrypt_stored.dart DIR` (with `DIR/dtm.sqlite`).
Future<void> main(List<String> args) async {
  if (args.length != 1) {
    print('usage: dart run tool/decrypt_stored.dart <dir>');
    return;
  }
  open.overrideFor(
    OperatingSystem.linux,
    () => DynamicLibrary.open('libsqlite3.so.0'),
  );
  final identity = identityFromDirectory(args[0]);
  if (identity == null) return;
  final kp = await DtmKeyPair.fromSeeds(
    ed25519SeedHex: identity.edSeedHex,
    x25519SeedHex: identity.xSeedHex,
  );
  final db = sqlite3.open('${args[0]}/dtm.sqlite');
  try {
    final rows = db.select('select * from messages order by timestamp');
    print('messages: ${rows.length}');
    for (final row in rows) {
      final env = Envelope(
        id: row['id'] as String,
        senderPubKey: row['sender_pub_key'] as String,
        recipientPubKey: row['recipient_pub_key'] as String,
        timestamp: row['timestamp'] as int,
        ciphertext: row['ciphertext'] as String,
        ephemeralPubKey: row['ephemeral_pub_key'] as String,
        signature: row['signature'] as String,
        chainLink: (row['chain_link'] as String?) ?? '',
      );
      final verified = await env.verify();
      final validId = await env.hasValidId();
      final text = await decryptPayload(
        envelope: env,
        recipientX25519KeyPair: kp.xKeyPair,
        senderEd25519PubKeyHex: env.senderPubKey,
      );
      print('id        ${env.id}');
      print('chain     ${env.chainLink.isEmpty ? '<genesis>' : env.chainLink}');
      print('verify    $verified   validId $validId');
      print('plaintext ${text ?? '<cannot decrypt>'}');
    }
  } finally {
    db.dispose();
  }
}
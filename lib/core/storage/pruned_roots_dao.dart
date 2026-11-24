import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:drift/drift.dart';

import '../crypto/envelope_crypto.dart' show bytesToHex, hexToBytes;
import 'database.dart';

/// A signed Merkle root that certifies a batch of pruned messages.
class PrunedRootEntry {
  final int id;
  final int cutoffTs;
  final String merkleRoot;
  final int count;
  final String devicePubKey;
  final String signature;

  const PrunedRootEntry({
    required this.id,
    required this.cutoffTs,
    required this.merkleRoot,
    required this.count,
    required this.devicePubKey,
    required this.signature,
  });
}

/// Integrity proofs for pruned batches — read-only access plus verification.
class PrunedRootsDao extends DatabaseAccessor<AppDatabase> {
  PrunedRootsDao(super.db);

  Future<List<PrunedRootEntry>> getPrunedRoots() async {
    final rows = await (select(
      db.prunedRoots,
    )..orderBy([(r) => OrderingTerm(expression: r.cutoffTs)])).get();
    return rows
        .map(
          (r) => PrunedRootEntry(
            id: r.id,
            cutoffTs: r.cutoffTs,
            merkleRoot: r.merkleRoot,
            count: r.count,
            devicePubKey: r.devicePubKey,
            signature: r.signature,
          ),
        )
        .toList(growable: false);
  }

  /// Verifies that [entry] was signed by [devicePubKeyHex] (Ed25519) over
  /// `merkleRoot || cutoffTs || count`.
  Future<bool> verifyRootSignature(
    PrunedRootEntry entry, {
    required String devicePubKeyHex,
  }) async {
    if (entry.devicePubKey != devicePubKeyHex) return false;
    final data = utf8.encode(
      '${entry.merkleRoot}${entry.cutoffTs}${entry.count}',
    );
    final verified = await Ed25519().verify(
      data,
      signature: Signature(
        hexToBytes(entry.signature),
        publicKey: SimplePublicKey(
          hexToBytes(devicePubKeyHex),
          type: KeyPairType.ed25519,
        ),
      ),
    );
    return verified;
  }
}

/// Serializes the exact bytes that are signed for a pruned-batch root.
List<int> rootSignatureData(String merkleRoot, int cutoffTs, int count) {
  final bytes = <int>[];
  bytes.addAll(utf8.encode(merkleRoot));
  bytes.addAll(utf8.encode('$cutoffTs'));
  bytes.addAll(utf8.encode('$count'));
  return bytes;
}

/// Convenience for tests: signs the root and returns hex.
Future<String> signRootData({
  required SimpleKeyPair edKeyPair,
  required String merkleRoot,
  required int cutoffTs,
  required int count,
}) async {
  final signature = await Ed25519().sign(
    rootSignatureData(merkleRoot, cutoffTs, count),
    keyPair: edKeyPair,
  );
  return bytesToHex(signature.bytes);
}

import 'dart:convert';

import 'package:cryptography/cryptography.dart';

/// Deterministic binary Merkle tree over a sorted list of message ids.
///
/// Invariant: nodes are hashed as
/// `sha256( hex( leftNode ) || hex( rightNode ) )`
/// using the hex strings (never raw bytes) so that this is stable across
/// platforms and from/toJSON round-trips.
class MerkleTree {
  final List<String> leaves;

  const MerkleTree(this.leaves);

  bool get isEmpty => leaves.isEmpty;

  /// Computes the root. Returns `null` for an empty tree (nothing to prove).
  Future<String?> root() async {
    if (leaves.isEmpty) return null;
    var level = leaves.map((l) => hexLower(l)).toList(growable: false);
    while (level.length > 1) {
      final next = <String>[];
      for (var i = 0; i < level.length; i += 2) {
        final left = level[i];
        final right = i + 1 < level.length ? level[i + 1] : left;
        next.add(await _hashPair(left, right));
      }
      level = next;
    }
    return level.single;
  }

  Future<String> _hashPair(String left, String right) async {
    final digest = await Sha256().hash(utf8.encode('$left$right'));
    return digest.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static String hexLower(String s) => s.toLowerCase();
}

/// Convenience: root over a sorted id list, `null` when empty.
Future<String?> merkleRoot(List<String> sortedIds) =>
    MerkleTree(sortedIds).root();

import 'dart:convert';

import 'package:drift/drift.dart';

import '../../models/peer.dart';
import '../crypto/hex.dart' show isHexOfLength;
import 'database.dart';

/// Persists the imported peer book (names, routing, binding). Never synced;
/// on-disk form matches [DtmPeer] minus the runtime `online` flag.
class PeerDao extends DatabaseAccessor<AppDatabase> {
  PeerDao(super.db);

  Future<List<DtmPeer>> all() async {
    final rows = await (select(
      db.peers,
    )..orderBy([(p) => OrderingTerm.desc(p.lastSeen)])).get();
    return [for (final row in rows) _fromRow(row)];
  }

  Future<DtmPeer?> find(String pubKey) async {
    final row = await (select(
      db.peers,
    )..where((p) => p.pubKey.equals(pubKey))).getSingleOrNull();
    return row == null ? null : _fromRow(row);
  }

  Future<void> upsert(DtmPeer peer) async {
    // InsertMode.insertOrReplace would drop the verification columns on every
    // identify refresh; the update branch deliberately leaves them untouched.
    await into(db.peers).insert(
      PeersCompanion.insert(
        pubKey: peer.pubKey,
        edPubKey: Value(peer.edPubKey),
        displayName: Value(peer.displayName),
        peerId: Value(peer.peerId),
        addrsJson: Value(jsonEncode(peer.addrs)),
        lastSeen: Value(peer.lastSeen.toUtc().millisecondsSinceEpoch),
        isContact: Value(peer.isContact),
      ),
      onConflict: DoUpdate(
        (_) => PeersCompanion(
          edPubKey: Value(peer.edPubKey),
          displayName: Value(peer.displayName),
          peerId: Value(peer.peerId),
          addrsJson: Value(jsonEncode(peer.addrs)),
          lastSeen: Value(peer.lastSeen.toUtc().millisecondsSinceEpoch),
          isContact: Value(peer.isContact),
        ),
      ),
    );
  }

  /// Records that the user compared safety numbers and confirmed [edPubKey].
  ///
  /// Both keys are validated first: a malformed binding must never be stored
  /// as "verified".
  Future<void> markVerified(String pubKey, String edPubKey) async {
    if (!isHexOfLength(pubKey, 32)) {
      throw const FormatException('peer key is not 32-byte hex');
    }
    if (!isHexOfLength(edPubKey, 32)) {
      throw const FormatException('Ed25519 binding is not 32-byte hex');
    }
    await (update(db.peers)..where((p) => p.pubKey.equals(pubKey))).write(
      PeersCompanion(
        verifiedEdPubKey: Value(edPubKey.toLowerCase()),
        verifiedAt: Value(DateTime.now().toUtc().millisecondsSinceEpoch),
      ),
    );
  }

  Future<bool> hasPubKey(String pubKey) async {
    if (pubKey.isEmpty) return false;
    final query = db.select(db.peers)
      ..where((p) => p.pubKey.equals(pubKey))
      ..limit(1);
    final row = await query.getSingleOrNull();
    return row != null;
  }

  /// Blocks or unblocks a contact. Local-only: the flag never leaves the
  /// device and survives later identify upserts.
  Future<void> setBlocked(String pubKey, bool blocked) async {
    if (!isHexOfLength(pubKey, 32)) {
      throw const FormatException('peer key is not 32-byte hex');
    }
    await (update(db.peers)..where((p) => p.pubKey.equals(pubKey))).write(
      PeersCompanion(blocked: Value(blocked)),
    );
  }

  /// X25519 keys of blocked contacts, for the UI.
  Future<Set<String>> blockedPubKeys() async {
    final rows = await (select(
      db.peers,
    )..where((p) => p.blocked.equals(true))).get();
    return {for (final row in rows) row.pubKey};
  }

  /// Ed25519 keys of every blocked contact. Envelopes are signed with the
  /// sender's Ed25519 key, so this is what the processor filters on.
  Future<Set<String>> blockedEdKeys() async {
    final rows = await (select(
      db.peers,
    )..where((p) => p.blocked.equals(true))).get();
    return {
      for (final row in rows)
        if (row.edPubKey != null && row.edPubKey!.isNotEmpty)
          row.edPubKey!.toLowerCase(),
    };
  }

  Future<void> remove(String pubKey) async {
    await (delete(db.peers)..where((p) => p.pubKey.equals(pubKey))).go();
  }

  /// Evicts the least-recently-seen peers beyond the [max] newest rows, so a
  /// flood of identify claims can never grow the peer book without bound.
  Future<void> pruneTo(int max) async {
    final rows = await all();
    if (rows.length <= max) return;
    for (final victim in rows.sublist(max)) {
      await (delete(db.peers)..where((p) => p.pubKey.equals(victim.pubKey)))
          .go();
    }
  }

  DtmPeer _fromRow(Peer row) {
    return DtmPeer(
      pubKey: row.pubKey,
      edPubKey: row.edPubKey,
      displayName: row.displayName,
      peerId: row.peerId,
      addrs: _parseAddrs(row.addrsJson),
      lastSeen: DateTime.fromMillisecondsSinceEpoch(row.lastSeen),
      online: false,
      isContact: row.isContact,
      verifiedEdPubKey: row.verifiedEdPubKey,
      verifiedAt: row.verifiedAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              row.verifiedAt!,
              isUtc: true,
            ),
    );
  }

  static List<String> _parseAddrs(String raw) {
    try {
      final decoded = jsonDecode(raw);
      return decoded is List
          ? List<String>.from(decoded.whereType<String>())
          : const <String>[];
    } catch (_) {
      return const <String>[];
    }
  }
}
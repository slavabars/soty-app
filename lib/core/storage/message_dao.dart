import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:drift/drift.dart';

import '../../models/envelope.dart';
import '../../models/message_status.dart';
import '../crypto/keypair.dart';
import '../security_limits.dart' show maxPendingOutbound;
import 'database.dart';
import 'merkle.dart';
import 'pruned_roots_dao.dart' show rootSignatureData;

/// All persistence for envelopes. Envelopes are immutable: existing ids are
/// never updated — only `INSERT OR IGNORE` semantics apply.
class MessageDao extends DatabaseAccessor<AppDatabase> {
  MessageDao(super.db);

  /// Persists [envelope] if the `id` is not already stored. Returns `true`
  /// only when a new row was actually inserted. New rows are validated
  /// against the directed-chain head: a valid `chainLink` advances the head;
  /// a mismatch is stored (kept as evidence) with the `forked` flag set.
  Future<bool> insertIfAbsent(
    Envelope envelope, {
    String source = 'p2p',
    int hops = 0,
  }) async {
    var inserted = false;
    await transaction(() async {
      if (await has(envelope.id)) {
        return;
      }
      await into(db.messages).insert(
        MessagesCompanion(
          id: Value(envelope.id),
          senderPubKey: Value(envelope.senderPubKey),
          recipientPubKey: Value(envelope.recipientPubKey),
          timestamp: Value(envelope.timestamp),
          ciphertext: Value(envelope.ciphertext),
          ephemeralPubKey: Value(envelope.ephemeralPubKey),
          signature: Value(envelope.signature),
          source: Value(source),
          hops: Value(hops),
          chainLink: Value(envelope.chainLink),
        ),
        mode: InsertMode.insertOrIgnore,
      );
      inserted = true;
      await _recordChain(envelope);
    });
    return inserted;
  }

  /// The current head id of the directed (sender, recipient) chain, or `''`
  /// when the chain has no messages yet. Used as `chainLink` when sending.
  Future<String> chainLinkFor(
    String senderPubKey,
    String recipientPubKey,
  ) async {
    final head = await _headFor(senderPubKey, recipientPubKey);
    return head?.headId ?? '';
  }

  /// Whether a stored message was rejected as a forged/additional branch
  /// (its `chainLink` did not match the head at insertion time).
  Future<bool> isForked(String id) async {
    final row = await (select(db.messages)
      ..where((m) => m.id.equals(id))).getSingleOrNull();
    return row?.forked == 1;
  }

  Future<ConversationHead?> _headFor(
    String senderPubKey,
    String recipientPubKey,
  ) async {
    return (select(db.conversationHeads)
          ..where(
            (h) => h.linkKey.equals(_linkKey(senderPubKey, recipientPubKey)),
          ))
        .getSingleOrNull();
  }

  /// Advances the directed-chain head when [envelope.chainLink] matches it.
  ///
  /// Two mismatches are *not* forks and must not poison the chain:
  /// * the link names a message we never stored — normal out-of-order delivery
  ///   (mesh relay) or a chain rebuilt after a reinstall;
  /// * the link names an older stored message — the envelope is simply behind
  ///   the head.
  ///
  /// A fork is only a second, different envelope claiming the *same* parent:
  /// two messages cannot both extend one link. Such a row is stored as
  /// evidence with `forked = 1` and never moves the head.
  Future<void> _recordChain(Envelope envelope) async {
    final key = _linkKey(envelope.senderPubKey, envelope.recipientPubKey);
    final head =
        await _headFor(envelope.senderPubKey, envelope.recipientPubKey);
    final expected = head?.headId ?? '';
    if (envelope.chainLink != expected) {
      if (await _claimsTakenParent(envelope)) {
        await (update(db.messages)
              ..where((m) => m.id.equals(envelope.id)))
            .write(const MessagesCompanion(forked: Value(1)));
        return;
      }
      if (head != null && envelope.timestamp <= head.lastTs) return;
    }
    await into(db.conversationHeads).insert(
      ConversationHeadsCompanion.insert(
        linkKey: key,
        headId: envelope.id,
        count: Value((head?.count ?? 0) + 1),
        lastTs: Value(envelope.timestamp),
      ),
      onConflict: DoUpdate((_) => ConversationHeadsCompanion(
        headId: Value(envelope.id),
        count: Value((head?.count ?? 0) + 1),
        lastTs: Value(envelope.timestamp),
      )),
    );
  }

  /// Whether another stored envelope already extends the same parent link, i.e.
  /// this envelope is an additional branch rather than an out-of-order one.
  Future<bool> _claimsTakenParent(Envelope envelope) async {
    final sibling = await (select(db.messages)
          ..where(
            (m) =>
                m.senderPubKey.equals(envelope.senderPubKey) &
                m.recipientPubKey.equals(envelope.recipientPubKey) &
                m.chainLink.equals(envelope.chainLink) &
                m.id.equals(envelope.id).not(),
          )
          ..limit(1))
        .getSingleOrNull();
    return sibling != null;
  }

  static String _linkKey(String senderPubKey, String recipientPubKey) =>
      '$senderPubKey$recipientPubKey';

  Future<bool> has(String id) async {
    final row = await (select(
      db.messages,
    )..where((m) => m.id.equals(id))).getSingleOrNull();
    return row != null;
  }

  /// Stores the plaintext body of one of this device's own sent envelopes
  /// (idempotent: an existing row for [id] is never overwritten). Only called
  /// when the user enabled `soty.storeOutgoing`.
  Future<void> putBody(
    String id, {
    required String plaintext,
    required int timestamp,
  }) async {
    await into(db.outgoingBodies).insert(
      OutgoingBodiesCompanion.insert(
        id: id,
        plaintext: plaintext,
        timestamp: timestamp,
      ),
      mode: InsertMode.insertOrIgnore,
    );
  }

  /// The locally cached plaintext of [id], or `null` when not persisted.
  Future<String?> bodyFor(String id) async {
    final row = await (select(db.outgoingBodies)
          ..where((b) => b.id.equals(id)))
        .getSingleOrNull();
    return row?.plaintext;
  }

  /// Advances the delivery status of one outgoing envelope. Monotonic: the
  /// stored value only ever moves forward, so a delayed or replayed receipt
  /// can never undo a later one. The row is created on first use.
  Future<void> setStatus(String id, MessageStatus status) async {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await into(db.messageStatuses).insert(
      MessageStatusesCompanion.insert(
        id: id,
        status: Value(status.index),
        updatedAt: Value(now),
      ),
      onConflict: DoUpdate(
        (_) => MessageStatusesCompanion(
          status: Value(status.index),
          updatedAt: Value(now),
        ),
        where: (old) => old.status.isSmallerThanValue(status.index),
      ),
    );
  }

  /// The delivery status of [id], or `null` when it has none (the id was not
  /// composed by this device).
  Future<MessageStatus?> statusFor(String id) async {
    final row = await (select(db.messageStatuses)
          ..where((s) => s.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : MessageStatus.fromOrdinal(row.status);
  }

  /// Delivery statuses for a batch of ids; ids without a row are omitted so a
  /// conversation render can stay linear in one query.
  Future<Map<String, MessageStatus>> statusesFor(Iterable<String> ids) async {
    final list = ids.toList(growable: false);
    if (list.isEmpty) return const {};
    final rows = await (select(db.messageStatuses)
          ..where((s) => s.id.isIn(list)))
        .get();
    return {
      for (final row in rows) row.id: MessageStatus.fromOrdinal(row.status),
    };
  }

  /// Outgoing envelope ids no transport has accepted yet (status below
  /// `sent`), oldest first, for the retry pass. Bounded by [limit].
  Future<List<String>> pendingOutboundIds({
    int limit = maxPendingOutbound,
  }) async {
    final rows = await db
        .customSelect(
          'SELECT s.id AS id FROM message_statuses s '
          'JOIN messages m ON m.id = s.id '
          'WHERE s.status < ? '
          'ORDER BY m.timestamp ASC, m.id ASC LIMIT ?',
          variables: [
            Variable.withInt(MessageStatus.sent.index),
            Variable.withInt(limit),
          ],
        )
        .get();
    return rows.map((r) => r.read<String>('id')).toList(growable: false);
  }

  /// Flags a stored envelope as a control payload (receipt) so it never
  /// renders as a bubble nor counts as unread. Local-only; the wire format is
  /// untouched.
  Future<void> markControl(String id) async {
    await (update(db.messages)..where((m) => m.id.equals(id)))
        .write(const MessagesCompanion(control: Value(1)));
  }

  /// Whether [id] carries a control payload rather than a chat message.
  Future<bool> isControl(String id) async {
    final row = await (select(db.messages)..where((m) => m.id.equals(id)))
        .getSingleOrNull();
    return row?.control == 1;
  }

  /// Flags an envelope as direct-only: it may go over p2p/mesh but must never
  /// be handed to a relay host. Local-only; the wire format is untouched.
  Future<void> markDirectOnly(String id) async {
    await (update(db.messages)..where((m) => m.id.equals(id)))
        .write(const MessagesCompanion(directOnly: Value(1)));
  }

  /// Whether [id] must avoid relay hosts.
  Future<bool> isDirectOnly(String id) async {
    final row = await (select(db.messages)..where((m) => m.id.equals(id)))
        .getSingleOrNull();
    return row?.directOnly == 1;
  }

  /// Flags a stored envelope as a group container and records the group it
  /// belongs to, so it counts as unread only in that group. Local-only; the
  /// wire format is untouched.
  Future<void> markGroup(String id, {String? groupId}) async {
    await (update(db.messages)..where((m) => m.id.equals(id))).write(
      MessagesCompanion(
        groupPayload: const Value(1),
        groupId: Value(groupId),
      ),
    );
  }

  /// The newest envelope timestamp on this device, or `null` when the store
  /// is empty. Used as the `since` cursor when subscribing to a relay host.
  Future<int?> latestTimestamp() async {
    final row = await (selectOnly(db.messages)
          ..addColumns([db.messages.timestamp.max()]))
        .getSingle();
    return row.read(db.messages.timestamp.max());
  }

  /// The newest envelope timestamp addressed to but not signed by this device
  /// ([myXPubKey]/[myEdPubKey]), or `null` when none. A host `since` cursor
  /// must never advance past queued inbound envelopes, so it counts only the
  /// device's own received history, never its outbound or relayed mail.
  Future<int?> latestInboundTimestamp(
    String myXPubKey,
    String myEdPubKey,
  ) async {
    final row = await (select(db.messages)
          ..where((m) =>
              m.recipientPubKey.equals(myXPubKey) &
              m.senderPubKey.equals(myEdPubKey).not())
          ..orderBy([(m) => OrderingTerm.desc(m.timestamp)])
          ..limit(1))
        .getSingleOrNull();
    return row?.timestamp;
  }

  Future<Envelope?> envelopeById(String id) async {
    final row = await (select(
      db.messages,
    )..where((m) => m.id.equals(id))).getSingleOrNull();
    if (row == null) return null;
    return _toEnvelope(row);
  }

  /// Conversation with [peerXPubKey] held on this device ([myXPubKey]).
  /// Both directions, ordered oldest-first, optionally paged. Outgoing rows
  /// must have been signed by this device ([myEdPubKey]); inbound rows are
  /// scoped by the peer's Ed25519 key ([peerEdPubKey]). Relayed envelopes
  /// (neither sent nor received here) never surface in a conversation.
  Future<List<Envelope>> messagesFor(
    String peerXPubKey, {
    required String myXPubKey,
    required String myEdPubKey,
    String? peerEdPubKey,
    int? limit,
    int? before,
  }) async {
    final q = select(db.messages)
      ..where(
        (m) =>
            ((m.senderPubKey.equals(myEdPubKey) &
                    m.recipientPubKey.equals(peerXPubKey)) |
                (m.recipientPubKey.equals(myXPubKey) &
                    m.senderPubKey.equals(peerEdPubKey ?? peerXPubKey))) &
            m.control.equals(0),
      );
    if (before != null) {
      q.where((m) => m.timestamp.isSmallerThanValue(before));
    }
    q.orderBy([
      (m) => OrderingTerm(expression: m.timestamp, mode: OrderingMode.desc),
      (m) => OrderingTerm(expression: m.id),
    ]);
    if (limit != null) {
      q.limit(limit);
    }
    final rows = await q.get();
    return rows.reversed.map(_toEnvelope).toList(growable: false);
  }

  /// The shared pool of a group conversation: every copy this device sent to
  /// a member (`sender == myEd` into a member key) plus every inbound copy a
  /// member addressed to us (`recipient == myX` from a member's Ed key).
  /// Relayed envelopes never surface.
  Future<List<Envelope>> messagesForGroup({
    required String myXPubKey,
    required String myEdPubKey,
    required List<String> memberXKeys,
    required List<String> memberEdKeys,
    int? limit,
  }) async {
    final xSet = memberXKeys.toSet();
    final edSet = memberEdKeys.toSet()..remove(myEdPubKey);
    final q = select(db.messages)
      ..where(
        (m) =>
            ((m.recipientPubKey.equals(myXPubKey) &
                    m.senderPubKey.isIn(edSet)) |
                (m.senderPubKey.equals(myEdPubKey) &
                    m.recipientPubKey.isIn(xSet))) &
            m.control.equals(0),
      )
      ..orderBy([
        (m) => OrderingTerm(expression: m.timestamp, mode: OrderingMode.desc),
        (m) => OrderingTerm(expression: m.id, mode: OrderingMode.desc),
      ]);
    if (limit != null) q.limit(limit);
    final rows = await q.get();
    return rows.reversed.map(_toEnvelope).toList(growable: false);
  }

  /// All ids newer than [sinceTs], deterministically ordered
  /// (`timestamp ASC, id ASC`). Used by gossip `HAVE`; [limit] bounds hostile
  /// scan windows.
  Future<List<String>> idsSince(int sinceTs, {int? limit}) async {
    if (sinceTs < 0) sinceTs = 0;
    final q = select(db.messages)
      ..where((m) => m.timestamp.isBiggerOrEqualValue(sinceTs))
      ..orderBy([
        (m) => OrderingTerm(expression: m.timestamp),
        (m) => OrderingTerm(expression: m.id),
      ]);
    if (limit != null) {
      q.limit(limit);
    }
    final rows = await q.get();
    return rows.map((r) => r.id).toList(growable: false);
  }

  /// Distinct public keys a conversation has been held with, excluding self.
  Future<List<String>> conversationKeys({
    required String myXPubKey,
    required String myEdPubKey,
  }) async {
    final keys = <String>{};
    final recipients =
        await (selectOnly(db.messages)
              ..addColumns([db.messages.recipientPubKey])
              ..where(db.messages.senderPubKey.equals(myEdPubKey)))
            .get();
    for (final row in recipients) {
      final k = row.read(db.messages.recipientPubKey);
      if (k != null && k != myXPubKey) keys.add(k);
    }
    final senders =
        await (selectOnly(db.messages)
              ..addColumns([db.messages.senderPubKey])
              ..where(db.messages.recipientPubKey.equals(myXPubKey)))
            .get();
    for (final row in senders) {
      final from = row.read(db.messages.senderPubKey);
      if (from != null && from != myEdPubKey) keys.add(from);
    }
    return keys.toList()..sort();
  }

  /// Deletes messages older than [age] and persists a signed Merkle root of
  /// the pruned batch. Atomic: root + deletion happen in one transaction.
  Future<PrunedBatch> pruneOlderThan(
    Duration age, {
    required DtmKeyPair deviceKey,
  }) async {
    final cutoff = _cutoffTs(age);
    final devicePub = await deviceKey.ed25519PublicKeyHex;

    late final PrunedBatch result;
    await transaction(() async {
      final ids = await _idsOlderThan(cutoff);
      result = await _pruneIds(ids, cutoff, deviceKey, devicePub);
    });
    return result;
  }

  /// Per-conversation cap: if the conversation exceeds [cap] rows, the oldest
  /// rows beyond the cap are pruned using the same Merkle-root procedure.
  Future<PrunedBatch> pruneConversationOverCap(
    String peerXPubKey, {
    required String myXPubKey,
    required String myEdPubKey,
    String? peerEdPubKey,
    required int cap,
    required DtmKeyPair deviceKey,
  }) async {
    final devicePub = await deviceKey.ed25519PublicKeyHex;

    late final PrunedBatch result;
    await transaction(() async {
      final rows =
          await (select(db.messages)
                ..where(
                  (m) =>
                      (m.senderPubKey.equals(myEdPubKey) &
                          m.recipientPubKey.equals(peerXPubKey)) |
                      (m.recipientPubKey.equals(myXPubKey) &
                          m.senderPubKey.equals(peerEdPubKey ?? peerXPubKey)),
                )
                ..orderBy([
                  (m) => OrderingTerm(expression: m.timestamp),
                  (m) => OrderingTerm(expression: m.id),
                ]))
              .get();
      if (rows.length <= cap) {
        result = PrunedBatch(cutoffTs: 0, count: 0, merkleRoot: null);
        return;
      }
      final toPrune = rows.take(rows.length - cap).map((r) => r.id).toList();
      final cutoff = rows[rows.length - cap].timestamp;
      result = await _pruneIds(toPrune, cutoff, deviceKey, devicePub);
    });
    return result;
  }

  Future<List<String>> _idsOlderThan(int cutoff) async {
    final rows =
        await (select(db.messages)
              ..where((m) => m.timestamp.isSmallerThanValue(cutoff))
              ..orderBy([
                (m) => OrderingTerm(expression: m.timestamp),
                (m) => OrderingTerm(expression: m.id),
              ]))
            .get();
    return rows.map((r) => r.id).toList(growable: false);
  }

  Future<PrunedBatch> _pruneIds(
    List<String> ids,
    int cutoff,
    DtmKeyPair deviceKey,
    String devicePub,
  ) async {
    final root = await merkleRoot(ids);
    String? signature;
    if (root != null) {
      signature = await _signRoot(deviceKey, root, cutoff, ids.length);
      await into(db.prunedRoots).insert(
        PrunedRootsCompanion.insert(
          cutoffTs: cutoff,
          merkleRoot: root,
          count: ids.length,
          devicePubKey: devicePub,
          signature: signature,
        ),
      );
    }
    // SQLite builds bound-variable limits as low as 999. A normal 30-day
    // prune can exceed that, and one failed statement would roll back the
    // whole transaction and silently defeat retention. Delete in chunks.
    for (var i = 0; i < ids.length; i += 400) {
      final chunk = ids.sublist(
        i,
        i + 400 > ids.length ? ids.length : i + 400,
      );
      await (delete(db.messages)..where((m) => m.id.isIn(chunk))).go();
      await (delete(db.outgoingBodies)..where((b) => b.id.isIn(chunk))).go();
      await (delete(db.messageStatuses)..where((s) => s.id.isIn(chunk))).go();
    }
    return PrunedBatch(
      cutoffTs: cutoff,
      count: ids.length,
      merkleRoot: root,
      signature: signature,
    );
  }

  Future<String> _signRoot(
    DtmKeyPair deviceKey,
    String root,
    int cutoff,
    int count,
  ) async {
    final data = rootSignatureData(root, cutoff, count);
    final signature = await Ed25519().sign(data, keyPair: deviceKey.edKeyPair);
    return signature.bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  Envelope _toEnvelope(Message row) => Envelope(
    id: row.id,
    senderPubKey: row.senderPubKey,
    recipientPubKey: row.recipientPubKey,
    timestamp: row.timestamp,
    ciphertext: row.ciphertext,
    ephemeralPubKey: row.ephemeralPubKey,
    signature: row.signature,
    chainLink: row.chainLink,
  );

  /// Retention pruning driven by the user setting plus the fixed relay
  /// policy. [ownAge] is the user-chosen cap for the device's own
  /// conversations (`null` or zero = keep forever); [relayedAge] and
  /// [relayedMaxBytes] are the hard caps for envelopes this device merely
  /// relays for others. Both passes use the signed Merkle-root procedure.
  Future<List<PrunedBatch>> pruneByPolicy({
    required Duration? ownAge,
    required Duration relayedAge,
    required int relayedMaxBytes,
    required String myEdPubKey,
    required String myXPubKey,
    required DtmKeyPair deviceKey,
  }) async {
    final devicePub = await deviceKey.ed25519PublicKeyHex;
    final results = <PrunedBatch>[];
    await transaction(() async {
      Expression<bool> isOwn(Messages m) =>
          m.senderPubKey.equals(myEdPubKey) |
          m.recipientPubKey.equals(myXPubKey);
      if (ownAge != null && ownAge > Duration.zero) {
        final cutoff = _cutoffTs(ownAge);
        final rows = await _ordered(cutoff: cutoff, predicate: isOwn);
        if (rows.isNotEmpty) {
          results.add(
            await _pruneIds(
              rows.map((r) => r.id).toList(),
              cutoff,
              deviceKey,
              devicePub,
            ),
          );
        }
      }
      final relayed = await _ordered(
        predicate: (m) => isOwn(m).not(),
      );
      if (relayed.isEmpty) return;
      final relayedCutoff = _cutoffTs(relayedAge);
      final byAge = <String>{};
      for (final row in relayed) {
        if (row.timestamp < relayedCutoff) byAge.add(row.id);
      }
      if (byAge.isNotEmpty) {
        results.add(
          await _pruneIds(byAge.toList(), relayedCutoff, deviceKey, devicePub),
        );
      }
      // One linear pass: a `List.contains` per row made this quadratic on a
      // relayed cache that can hold tens of thousands of envelopes.
      var bytes = 0;
      final kept = <Message>[];
      for (final row in relayed) {
        if (byAge.contains(row.id)) continue;
        bytes += _ciphertextBytes(row.ciphertext);
        kept.add(row);
      }
      final overBytes = <String>[];
      var overCutoff = 0;
      for (final row in kept) {
        if (bytes <= relayedMaxBytes) break;
        bytes -= _ciphertextBytes(row.ciphertext);
        overBytes.add(row.id);
        if (row.timestamp > overCutoff) overCutoff = row.timestamp;
      }
      if (overBytes.isNotEmpty) {
        results.add(
          await _pruneIds(overBytes, overCutoff, deviceKey, devicePub),
        );
      }
    });
    return results;
  }

  Future<List<Message>> _ordered({
    int? cutoff,
    required Expression<bool> Function(Messages) predicate,
  }) async {
    final query = select(db.messages)
      ..orderBy([
        (m) => OrderingTerm(expression: m.timestamp),
        (m) => OrderingTerm(expression: m.id),
      ])
      ..where((m) {
        final p = predicate(m);
        return cutoff == null
            ? p
            : m.timestamp.isSmallerThanValue(cutoff) & p;
      });
    return query.get();
  }

  static int _ciphertextBytes(String base64) {
    final padded = base64.padRight((base64.length + 3) & ~3, '=');
    return base64Decode(padded).length;
  }

  /// Cutoff in UTC milliseconds, clamped to >= 0.
  static int _cutoffTs(Duration age) {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final cutoff = now - age.inMilliseconds;
    return cutoff < 0 ? 0 : cutoff;
  }
}

/// Result of one pruning run.
class PrunedBatch {
  final int cutoffTs;
  final int count;
  final String? merkleRoot;
  final String? signature;

  PrunedBatch({
    required this.cutoffTs,
    required this.count,
    required this.merkleRoot,
    this.signature,
  });

  bool get deletedAny => count > 0;
}

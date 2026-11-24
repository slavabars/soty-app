import 'package:drift/drift.dart';

import '../../core/crypto/hex.dart' show isHexOfLength;
import '../../core/security_limits.dart';
import '../../models/conversation.dart';
import 'database.dart';
import 'message_dao.dart';

/// Persists the chat list. Titles are renameable independently of the peer
/// book; group rosters live in [ConversationMembers].
class ConversationDao extends DatabaseAccessor<AppDatabase> {
  ConversationDao(super.db);

  static const String adminRole = 'admin';
  static const String memberRole = 'member';

  Future<List<ConversationView>> all({
    required String myXPubKey,
    required String myEdPubKey,
  }) async {
    final rows = await (select(db.conversations)
          ..orderBy([(c) => OrderingTerm.desc(c.lastTs)]))
        .get();
    final unread = await unreadCounts(
      myXPubKey: myXPubKey,
      myEdPubKey: myEdPubKey,
    );
    final out = <ConversationView>[];
    for (final row in rows) {
      out.add(
        await _view(row, unreadCount: unread[row.id] ?? 0),
      );
    }
    return out;
  }

  Future<ConversationView?> byId(String id) async {
    final row = await (select(db.conversations)
          ..where((c) => c.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _view(row);
  }

  Future<List<String>> memberKeys(String id) async {
    final rows = await (select(db.conversationMembers)
          ..where((m) => m.conversationId.equals(id))
          ..orderBy([(m) => OrderingTerm(expression: m.peerXKey)]))
        .get();
    return rows.map((r) => r.peerXKey).toList(growable: false);
  }

  /// Every X25519 key that appears in any group roster. Used to keep the
  /// 1:1 backfill from mistaking group copies for direct chats.
  Future<Set<String>> groupMemberXKeys() async {
    final groups = await (select(db.conversations)
          ..where((c) => c.kind.equals('group')))
        .get();
    final out = <String>{};
    for (final g in groups) {
      out.addAll(await memberKeys(g.id));
    }
    return out;
  }

  /// Registers a 1:1 conversation with [peerXKey] as its only member, keeping
  /// an existing row untouched (idempotent). [ts] seeds both created/last.
  Future<void> ensureOneOnOne(String peerXKey, {required int ts}) async {
    await into(db.conversations).insert(
      ConversationsCompanion.insert(
        id: peerXKey,
        kind: const Value('dm'),
        createdTs: Value(ts),
        lastTs: Value(ts),
      ),
      mode: InsertMode.insertOrIgnore,
    );
    await _insertMember(peerXKey, peerXKey);
  }

  /// Creates a group chat ([memberKeys] incl. self) under a caller-chosen
  /// random 32-byte hex [id]. Enforces the roster/title ceilings.
  Future<void> createGroup({
    required String id,
    required List<String> memberKeys,
    required String title,
    required int ts,
    List<String> adminKeys = const [],
  }) async {
    if (memberKeys.length > maxGroupMembers) {
      throw ArgumentError.value(
        memberKeys.length,
        'memberKeys',
        'exceeds maxGroupMembers $maxGroupMembers',
      );
    }
    for (final key in memberKeys) {
      if (!isHexOfLength(key, 32)) {
        throw ArgumentError.value(
          key,
          'memberKeys',
          'is not a 32-byte hex key',
        );
      }
    }
    assertTitleInLimits(title);
    final groupCount =
        await (selectOnly(db.conversations)
              ..addColumns([db.conversations.id.count()])
              ..where(db.conversations.kind.equals('group')))
            .map((row) => row.read(db.conversations.id.count()) ?? 0)
            .getSingle();
    if (groupCount >= maxGroupCount) {
      throw ArgumentError.value(
        groupCount,
        'groups',
        'exceeds maxGroupCount $maxGroupCount',
      );
    }
    final roster = memberKeys.toSet().toList()..sort();
    await into(db.conversations).insert(
      ConversationsCompanion.insert(
        id: id,
        kind: const Value('group'),
        title: Value(title),
        createdTs: Value(ts),
        lastTs: Value(ts),
      ),
      mode: InsertMode.insertOrIgnore,
    );
    for (final key in roster) {
      await _insertMember(
        id,
        key,
        role: adminKeys.contains(key) ? adminRole : memberRole,
      );
    }
  }

  /// Every member of [id] with its role, keyed by X25519 address.
  Future<List<({String key, String role})>> membersWithRoles(String id) async {
    final rows = await (select(db.conversationMembers)
          ..where((m) => m.conversationId.equals(id))
          ..orderBy([(m) => OrderingTerm(expression: m.peerXKey)]))
        .get();
    return [
      for (final row in rows) (key: row.peerXKey, role: row.role),
    ];
  }

  Future<String?> roleOf(String id, String key) async {
    final row = await (select(db.conversationMembers)
          ..where(
            (m) => m.conversationId.equals(id) & m.peerXKey.equals(key),
          ))
        .getSingleOrNull();
    return row?.role;
  }

  Future<bool> isAdmin(String id, String key) async =>
      await roleOf(id, key) == adminRole;

  /// Adds [key] as a plain member; idempotent for an existing member.
  ///
  /// Enforces the group roster ceiling and rejects malformed keys.
  Future<void> addMember(String id, String key) async {
    if (!isHexOfLength(key, 32)) {
      throw ArgumentError.value(key, 'key', 'is not a 32-byte hex key');
    }
    final members = await memberKeys(id);
    if (!members.contains(key) && members.length >= maxGroupMembers) {
      throw ArgumentError.value(
        members.length + 1,
        'members',
        'exceeds maxGroupMembers $maxGroupMembers',
      );
    }
    await _insertMember(id, key);
  }

  /// Removes [key]; returns whether a row was deleted. The last admin cannot
  /// be removed, which would otherwise lock the roster forever.
  Future<bool> removeMember(String id, String key) async {
    if (!isHexOfLength(key, 32)) {
      throw ArgumentError.value(key, 'key', 'is not a 32-byte hex key');
    }
    final role = await roleOf(id, key);
    if (role == null) return false;
    if (role == adminRole) {
      final admins = (await membersWithRoles(id))
          .where((m) => m.role == adminRole)
          .length;
      if (admins <= 1) {
        throw StateError('the last admin cannot be removed');
      }
    }
    await (delete(db.conversationMembers)..where(
          (m) => m.conversationId.equals(id) & m.peerXKey.equals(key),
        ))
        .go();
    return true;
  }

  /// Promotes or demotes [key]; [role] must be [adminRole] or [memberRole].
  Future<void> setRole(String id, String key, String role) async {
    if (role != adminRole && role != memberRole) {
      throw ArgumentError.value(role, 'role', 'unknown role');
    }
    if (!isHexOfLength(key, 32)) {
      throw ArgumentError.value(key, 'key', 'is not a 32-byte hex key');
    }
    final current = await roleOf(id, key);
    if (current == null) {
      throw ArgumentError.value(key, 'key', 'is not a member of this group');
    }
    if (current == adminRole && role == memberRole) {
      final admins = (await membersWithRoles(id))
          .where((m) => m.role == adminRole)
          .length;
      if (admins <= 1) {
        throw StateError('the last admin cannot be demoted');
      }
    }
    await (update(db.conversationMembers)..where(
          (m) => m.conversationId.equals(id) & m.peerXKey.equals(key),
        ))
        .write(ConversationMembersCompanion(role: Value(role)));
  }

  /// Applies a roster received from an admin: surviving members keep their
  /// role, new members start as `member`. Rejects an empty or admin-less
  /// roster and anything past the ceiling.
  Future<void> replaceMembers(String id, List<String> keys) async {
    final roster = keys.toSet().toList()..sort();
    if (roster.isEmpty) {
      throw ArgumentError.value(keys, 'keys', 'a group needs a member');
    }
    if (roster.length > maxGroupMembers) {
      throw ArgumentError.value(
        roster.length,
        'keys',
        'exceeds maxGroupMembers $maxGroupMembers',
      );
    }
    for (final key in roster) {
      if (!isHexOfLength(key, 32)) {
        throw ArgumentError.value(key, 'keys', 'is not a 32-byte hex key');
      }
    }
    final current = {
      for (final m in await membersWithRoles(id)) m.key: m.role,
    };
    final admins = roster
        .where((key) => current[key] == adminRole)
        .toList(growable: false);
    if (admins.isEmpty) {
      throw StateError('a roster must keep at least one admin');
    }
    await transaction(() async {
      for (final key in current.keys) {
        if (!roster.contains(key)) {
          await (delete(db.conversationMembers)..where(
                (m) => m.conversationId.equals(id) & m.peerXKey.equals(key),
              ))
              .go();
        }
      }
      for (final key in roster) {
        await _insertMember(id, key, role: current[key] ?? memberRole);
      }
    });
  }

  Future<void> rename(String id, String title) async {
    assertTitleInLimits(title);
    await (update(db.conversations)..where((c) => c.id.equals(id)))
        .write(ConversationsCompanion(title: Value(title)));
  }

  Future<void> setLastTs(String id, int ts) async {
    await (update(db.conversations)..where((c) => c.id.equals(id)))
        .write(ConversationsCompanion(lastTs: Value(ts)));
  }

  /// The timestamp up to which the user has read this conversation (`0` when
  /// never opened). Used to scope read receipts to the messages that just
  /// became read.
  Future<int> readAt(String id) async {
    final row = await (select(db.conversations)
          ..where((c) => c.id.equals(id)))
        .getSingleOrNull();
    return row?.readAt ?? 0;
  }

  /// Records that the user had this chat on screen at [ts], which makes every
  /// inbound message up to that moment read.
  Future<void> markRead(String id, int ts) async {
    final row = await (select(db.conversations)
          ..where((c) => c.id.equals(id)))
        .getSingleOrNull();
    if (row == null || row.readAt >= ts) return;
    await (update(db.conversations)..where((c) => c.id.equals(id)))
        .write(ConversationsCompanion(readAt: Value(ts)));
  }

  /// Unread inbound count per conversation id, derived from the messages
  /// table rather than a stored counter: a message newer than `read_at` from
  /// a participant of that chat. Relayed copies (addressed to somebody else)
  /// and our own outgoing messages never count. One statement, so the chat
  /// list cannot show a count that disagrees with the messages.
  Future<Map<String, int>> unreadCounts({
    required String myXPubKey,
    required String myEdPubKey,
  }) async {
    final rows = await db.customSelect(
      '''
      SELECT c.id AS id, COUNT(m.id) AS unread
        FROM conversations c
        LEFT JOIN messages m
          ON m.recipient_pub_key = ?
         AND m.timestamp > c.read_at
         AND (
           (c.kind = 'dm' AND m.group_payload = 0 AND (
             m.sender_pub_key = c.id
             OR m.sender_pub_key = (
               SELECT p.ed_pub_key FROM peers p WHERE p.pub_key = c.id
             )
           ))
           OR (c.kind = 'group' AND m.group_payload = 1
             AND m.group_id = c.id AND (
             m.sender_pub_key IN (
               SELECT peer_x_key FROM conversation_members
                WHERE conversation_id = c.id
             )
             OR m.sender_pub_key IN (
               SELECT p.ed_pub_key FROM peers p
                WHERE p.ed_pub_key IS NOT NULL
                  AND p.pub_key IN (
                    SELECT peer_x_key FROM conversation_members
                     WHERE conversation_id = c.id
                  )
             )
           ))
         )
         AND m.sender_pub_key <> ?
         AND m.control = 0
       GROUP BY c.id
      ''',
      variables: [Variable(myXPubKey), Variable(myEdPubKey)],
    ).get();
    final out = <String, int>{};
    for (final row in rows) {
      out[row.read<String>('id')] = row.read<int>('unread');
    }
    return out;
  }

  /// Data migration: materializes a 1:1 chat for every thread that already
  /// has messages (the pre-v6 form of "conversation"), folding inbound
  /// Ed25519-signed senders into the peer's X25519 address exactly like the
  /// old in-memory `conversations()`. Drops stale DM rows keyed by a peer's
  /// Ed25519 address, folding their lastTs/title into the canonical X25519
  /// chat. Idempotent — safe on every start.
  ///
  /// [learnedEdToX] carries identity bindings the transports learned at
  /// runtime (identify/claims); merged over the persisted folder map so the
  /// current session folds correctly even before those bindings hit disk.
  Future<void> backfillOneOnOne({
    required String myXPubKey,
    required String myEdPubKey,
    Map<String, String>? learnedEdToX,
  }) async {
    final folders = {...await _folders(), ...?learnedEdToX};
    final candidates = await _canonicalKeys(
      myXPubKey: myXPubKey,
      myEdPubKey: myEdPubKey,
      edToX: folders,
    );
    final roster = await groupMemberXKeys();
    for (final key in candidates) {
      if (roster.contains(key)) continue;
      final xToEd = <String, String>{
        for (final p in (await (select(db.peers)).get()))
          p.pubKey: p.edPubKey ?? p.pubKey,
      };
      final ts = await _threadMaxTs(
        myXPubKey: myXPubKey,
        myEdPubKey: myEdPubKey,
        peerXKey: key,
        peerEdKey: xToEd[key] ?? key,
      );
      await ensureOneOnOne(key, ts: ts);
    }
    await _foldEdKeyedDms(
      myXPubKey: myXPubKey,
      folders: folders,
    );
  }

  /// Removes DM conversation rows keyed by a peer's Ed25519 address. A chat
  /// created before the peer binding was learned (e.g. from an inbound
  /// envelope) must never linger as a second tile; its lastTs and title fold
  /// into the canonical X25519-keyed conversation.
  Future<void> _foldEdKeyedDms({
    required String myXPubKey,
    required Map<String, String> folders,
  }) async {
    final dms = await (select(db.conversations)
          ..where((c) => c.kind.equals('dm')))
        .get();
    for (final row in dms) {
      final canonical = folders[row.id];
      if (canonical == null || canonical == row.id) continue;
      final target = await (select(db.conversations)
            ..where((c) => c.id.equals(canonical)))
          .getSingleOrNull();
      final mergedTs = target == null || row.lastTs > target.lastTs
          ? row.lastTs
          : target.lastTs;
      await ensureOneOnOne(canonical, ts: mergedTs);
      if (row.title.isNotEmpty) {
        if (target == null || target.title != row.title) {
          await rename(canonical, row.title);
        }
      }
      if (target != null && mergedTs > target.lastTs) {
        await setLastTs(canonical, mergedTs);
      }
      await (delete(db.conversationMembers)
            ..where((m) => m.conversationId.equals(row.id)))
          .go();
      await (delete(db.conversations)..where((c) => c.id.equals(row.id))).go();
    }
  }

  Future<ConversationView> _view(
    Conversation row, {
    int unreadCount = 0,
  }) async {
    final members = row.kind == 'group'
        ? await memberKeys(row.id)
        : <String>[row.id];
    return ConversationView(
      id: row.id,
      kind: ConversationView.kindFrom(row.kind),
      title: row.title,
      createdTs: row.createdTs,
      lastTs: row.lastTs,
      memberKeys: members,
      unreadCount: unreadCount,
    );
  }

  Future<Map<String, String>> _folders() async {
    final out = <String, String>{};
    final peers = await (select(db.peers)).get();
    for (final p in peers) {
      final ed = p.edPubKey;
      if (ed != null) out[ed] = p.pubKey;
    }
    return out;
  }

  Future<Set<String>> _canonicalKeys({
    required String myXPubKey,
    required String myEdPubKey,
    required Map<String, String> edToX,
  }) async {
    final raw = await MessageDao(db).conversationKeys(
      myXPubKey: myXPubKey,
      myEdPubKey: myEdPubKey,
    );
    return {
      for (final key in raw) edToX[key] ?? key,
    };
  }

  Future<int> _threadMaxTs({
    required String myXPubKey,
    required String myEdPubKey,
    required String peerXKey,
    required String peerEdKey,
  }) async {
    final rows = await db.customSelect(
      '''
      SELECT COALESCE(MAX(ts), 0) AS ts FROM (
        SELECT timestamp AS ts FROM messages
          WHERE sender_pub_key = ? AND recipient_pub_key = ?
        UNION ALL
        SELECT timestamp AS ts FROM messages
          WHERE recipient_pub_key = ? AND sender_pub_key = ?
      )
      ''',
      variables: [
        Variable(myEdPubKey),
        Variable(peerXKey),
        Variable(myXPubKey),
        Variable(peerEdKey),
      ],
    ).get();
    return rows.single.read<int>('ts');
  }

  Future<void> _insertMember(
    String conversationId,
    String peerXKey, {
    String role = memberRole,
  }) async {
    await into(db.conversationMembers).insert(
      ConversationMembersCompanion.insert(
        conversationId: conversationId,
        peerXKey: peerXKey,
        role: Value(role),
      ),
      mode: InsertMode.insertOrIgnore,
    );
  }
}
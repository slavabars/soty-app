import 'dart:ffi';
import 'dart:io';

import 'package:dtm_app/core/storage/conversation_dao.dart';
import 'package:dtm_app/core/storage/database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/open.dart' as sqlite3_open;
import 'package:sqlite3/sqlite3.dart' as sqlite3_pkg;

const _v2MessagesSql = '''
CREATE TABLE messages (
  id TEXT NOT NULL,
  sender_pub_key TEXT NOT NULL,
  recipient_pub_key TEXT NOT NULL,
  timestamp INTEGER NOT NULL,
  ciphertext TEXT NOT NULL,
  ephemeral_pub_key TEXT NOT NULL,
  signature TEXT NOT NULL,
  source TEXT NOT NULL,
  hops INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (id)
)
''';

const _v2PrunedSql = '''
CREATE TABLE pruned_roots (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  cutoff_ts INTEGER NOT NULL,
  merkle_root TEXT NOT NULL,
  count INTEGER NOT NULL,
  device_pub_key TEXT NOT NULL,
  signature TEXT NOT NULL
)
''';

const _v2IdentitySql = '''
CREATE TABLE identity_entry (
  key TEXT NOT NULL,
  ed_seed_hex TEXT NOT NULL,
  x_seed_hex TEXT NOT NULL,
  display_name TEXT NOT NULL DEFAULT '',
  created_at INTEGER NOT NULL,
  PRIMARY KEY (key)
)
''';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('dtm_migration_test');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test(
      'a fresh v10 database has conversations, membership, bodies, '
      'is_contact, read_at and message statuses', () async {
    final db = AppDatabase.inMemory();
    addTearDown(db.close);

    final indexRows =
        await db.customSelect('PRAGMA index_list(messages)').get();
    final names = indexRows.map((r) => r.read<String>('name')).toSet();
    expect(
      names,
      containsAll([
        'idx_messages_recipient_ts',
        'idx_messages_sender_ts',
        'idx_messages_group_ts',
      ]),
    );

    final versionRows = await db.customSelect('PRAGMA user_version').get();
    expect(versionRows.single.read<int>('user_version'), 20);

    final cols = await _columns(db, 'messages');
    expect(
      cols,
      containsAll(['chain_link', 'forked', 'control', 'group_id']),
    );
    final memberCols = await _columns(db, 'conversation_members');
    expect(memberCols, contains('role'));

    final conversationCols = await _columns(db, 'conversations');
    expect(conversationCols, contains('read_at'));

    final tables = await _tables(db);
    expect(
      tables,
      containsAll(
        [
          'conversation_heads',
          'peers',
          'conversations',
          'conversation_members',
          'outgoing_bodies',
          'message_statuses',
        ],
      ),
    );
  });

  test('a v2 database is upgraded to v20 in eleven hops', () async {
    _writeV2Schema('${tempDir.path}/dtm.sqlite');

    final db = await AppDatabase.open(tempDir.path);
    addTearDown(db.close);

    final indexRows =
        await db.customSelect('PRAGMA index_list(messages)').get();
    final names = indexRows.map((r) => r.read<String>('name')).toSet();
    expect(
      names,
      containsAll([
        'idx_messages_recipient_ts',
        'idx_messages_sender_ts',
        'idx_messages_group_ts',
      ]),
    );

    final versionRows = await db.customSelect('PRAGMA user_version').get();
    expect(versionRows.single.read<int>('user_version'), 20);

    final cols = await _columns(db, 'messages');
    expect(
      cols,
      containsAll(['chain_link', 'forked', 'control', 'group_id']),
    );
    final memberCols = await _columns(db, 'conversation_members');
    expect(memberCols, contains('role'));

    final peerCols = await _columns(db, 'peers');
    expect(
      peerCols,
      containsAll(['is_contact', 'verified_ed_pub_key', 'verified_at']),
    );

    final conversationCols = await _columns(db, 'conversations');
    expect(conversationCols, contains('read_at'));

    final tables = await _tables(db);
    expect(
      tables,
      containsAll(
        [
          'conversation_heads',
          'peers',
          'conversations',
          'conversation_members',
          'outgoing_bodies',
          'message_statuses',
        ],
      ),
    );
  });

  test('a v3 database is upgraded to v20 with chain tracking', () async {
    _writeV3Schema('${tempDir.path}/dtm.sqlite');

    final db = await AppDatabase.open(tempDir.path);
    addTearDown(db.close);

    final versionRows = await db.customSelect('PRAGMA user_version').get();
    expect(versionRows.single.read<int>('user_version'), 20);

    final cols = await _columns(db, 'messages');
    expect(
      cols,
      containsAll(['chain_link', 'forked', 'control', 'group_id']),
    );
    final memberCols = await _columns(db, 'conversation_members');
    expect(memberCols, contains('role'));

    final peerCols = await _columns(db, 'peers');
    expect(
      peerCols,
      containsAll(['is_contact', 'verified_ed_pub_key', 'verified_at']),
    );

    final conversationCols = await _columns(db, 'conversations');
    expect(conversationCols, contains('read_at'));

    final tables = await _tables(db);
    expect(
      tables,
      containsAll(
        [
          'conversation_heads',
          'peers',
          'conversations',
          'conversation_members',
          'outgoing_bodies',
          'message_statuses',
        ],
      ),
    );
  });

  test('a v7 database is upgraded to v20 with peers.is_contact', () async {
    _writeV7Schema('${tempDir.path}/dtm.sqlite');

    final db = await AppDatabase.open(tempDir.path);
    addTearDown(db.close);

    final versionRows = await db.customSelect('PRAGMA user_version').get();
    expect(versionRows.single.read<int>('user_version'), 20);

    final cols = await _columns(db, 'peers');
    expect(
      cols,
      containsAll([
        'is_contact',
        'verified_ed_pub_key',
        'verified_at',
        'blocked',
      ]),
    );

    final rows = await db.customSelect(
      'SELECT pub_key, is_contact, blocked FROM peers',
    ).get();
    expect(rows, hasLength(1));
    expect(rows.single.read<String>('pub_key'), 'a' * 64);
    expect(rows.single.read<int>('is_contact'), 0);
    // v20 adds the local block flag; existing contacts start unblocked.
    expect(rows.single.read<int>('blocked'), 0);

    final conversationCols = await _columns(db, 'conversations');
    expect(conversationCols, contains('read_at'));
    final conversations = await db.customSelect(
      'SELECT last_ts, read_at FROM conversations',
    ).get();
    expect(conversations.single.read<int>('read_at'), 100);
  });

  test('a v8 database is upgraded to v20 and backfills read_at with last_ts',
      () async {
    _writeV8Schema('${tempDir.path}/dtm.sqlite');

    final db = await AppDatabase.open(tempDir.path);
    addTearDown(db.close);

    final versionRows = await db.customSelect('PRAGMA user_version').get();
    expect(versionRows.single.read<int>('user_version'), 20);

    final rows = await db.customSelect(
      'SELECT id, last_ts, read_at FROM conversations',
    ).get();
    expect(rows, hasLength(2));
    for (final row in rows) {
      expect(
        row.read<int>('read_at'),
        row.read<int>('last_ts'),
        reason: 'existing history must not arrive as unread',
      );
    }

    final unread = await ConversationDao(db).unreadCounts(
      myXPubKey: 'x' * 64,
      myEdPubKey: 'e' * 64,
    );
    expect(unread.values.every((n) => n == 0), isTrue);
  });

  test(
      'a v9 database is upgraded to v20 with the control flag and '
      'message_statuses, keeping existing messages plain', () async {
    _writeV9Schema('${tempDir.path}/dtm.sqlite');

    final db = await AppDatabase.open(tempDir.path);
    addTearDown(db.close);

    final versionRows = await db.customSelect('PRAGMA user_version').get();
    expect(versionRows.single.read<int>('user_version'), 20);

    final cols = await _columns(db, 'messages');
    expect(cols, contains('control'));
    expect(cols, contains('group_payload'));

    final tables = await _tables(db);
    expect(tables, contains('message_statuses'));

    final rows = await db.customSelect(
      'SELECT id, control, group_payload FROM messages',
    ).get();
    expect(rows, hasLength(1));
    expect(rows.single.read<String>('id'), 'a' * 64);
    expect(rows.single.read<int>('control'), 0);
    expect(rows.single.read<int>('group_payload'), 0);
  });

  test(
      'a v10 database gains the group flag without touching existing rows',
      () async {
    _writeV10Schema('${tempDir.path}/dtm.sqlite');

    final db = await AppDatabase.open(tempDir.path);
    addTearDown(db.close);

    final versionRows = await db.customSelect('PRAGMA user_version').get();
    expect(versionRows.single.read<int>('user_version'), 20);

    final cols = await _columns(db, 'messages');
    expect(cols, contains('group_payload'));

    final rows = await db.customSelect(
      'SELECT id, group_payload FROM messages',
    ).get();
    expect(rows, hasLength(1));
    expect(rows.single.read<int>('group_payload'), 0);
  });

  test('a v11 database gains the media_blobs table and both indexes',
      () async {
    _writeV11Schema('${tempDir.path}/dtm.sqlite');

    final db = await AppDatabase.open(tempDir.path);
    addTearDown(db.close);

    final versionRows = await db.customSelect('PRAGMA user_version').get();
    expect(versionRows.single.read<int>('user_version'), 20);

    expect(await _tables(db), contains('media_blobs'));

    final indexRows =
        await db.customSelect('PRAGMA index_list(messages)').get();
    final names = indexRows.map((r) => r.read<String>('name')).toSet();
    // The v11 seed predates the recipient index too; the v13 hop must add the
    // sender index without disturbing the existing rows.
    expect(names, contains('idx_messages_sender_ts'));

    final cols = await _columns(db, 'media_blobs');
    expect(
      cols,
      containsAll([
        'blob_id',
        'kind',
        'mime',
        'byte_count',
        'duration_ms',
        'data',
        'timestamp',
      ]),
    );

    final rows = await db.customSelect('SELECT * FROM media_blobs').get();
    expect(rows, isEmpty);
  });
}

Future<Set<String>> _columns(AppDatabase db, String table) async {
  final rows = await db.customSelect('PRAGMA table_info($table)').get();
  return rows.map((r) => r.read<String>('name')).toSet();
}

Future<Set<String>> _tables(AppDatabase db) async {
  final rows =
      await db.customSelect("SELECT name FROM sqlite_master WHERE type='table'")
          .get();
  return rows.map((r) => r.read<String>('name')).toSet();
}

/// Builds a file matching the schema drift used at version 2, with
/// `PRAGMA user_version = 2`, then closes it so drift can open and migrate.
void _writeV2Schema(String path) {
  _resolveSqlite3();
  final db = sqlite3_pkg.sqlite3.open(path);
  db.execute(_v2MessagesSql);
  db.execute(_v2PrunedSql);
  db.execute(_v2IdentitySql);
  db.execute('PRAGMA user_version = 2');
  db.dispose();
}

/// Version 3 added only the recipient index, so the fixtures match v2.
void _writeV3Schema(String path) {
  _resolveSqlite3();
  final db = sqlite3_pkg.sqlite3.open(path);
  db.execute(_v2MessagesSql);
  db.execute(_v2PrunedSql);
  db.execute(_v2IdentitySql);
  db.execute(
    'CREATE INDEX idx_messages_recipient_ts '
    'ON messages(recipient_pub_key, timestamp)',
  );
  db.execute('PRAGMA user_version = 3');
  db.dispose();
}

/// Version 8 conversations had no read_at column; the rows are seeded so the
/// migration can prove it backfills instead of marking history unread.
void _writeV8Schema(String path) {
  _resolveSqlite3();
  final db = sqlite3_pkg.sqlite3.open(path);
  db.execute(_v8ConversationsSql);
  db.execute('PRAGMA user_version = 8');
  db.dispose();
}

/// Version 9 already had chain_link/forked and read_at; only the control
/// column and message_statuses are missing, so a seeded row proves the
/// upgrade preserves messages and defaults control to 0.
void _writeV9Schema(String path) {
  _resolveSqlite3();
  final db = sqlite3_pkg.sqlite3.open(path);
  db.execute(_v9MessagesSql);
  db.execute('PRAGMA user_version = 9');
  db.dispose();
}

/// Version 10 already had the control column; only group_payload is missing,
/// so a seeded row proves the upgrade adds the column and defaults it to 0.
void _writeV10Schema(String path) {
  _resolveSqlite3();
  final db = sqlite3_pkg.sqlite3.open(path);
  db.execute(_v10MessagesSql);
  db.execute('PRAGMA user_version = 10');
  db.dispose();
}

/// Version 11 is version 10 plus the group_payload column; the v12 hop only
/// adds the media_blobs table and v13 adds the sender index, so a seeded
/// message proves no row is lost.
void _writeV11Schema(String path) {
  _resolveSqlite3();
  final db = sqlite3_pkg.sqlite3.open(path);
  db.execute(_v11MessagesSql);
  db.execute('PRAGMA user_version = 11');
  db.dispose();
}

const _v11MessagesSql = '''
CREATE TABLE messages (
  id TEXT NOT NULL,
  sender_pub_key TEXT NOT NULL,
  recipient_pub_key TEXT NOT NULL,
  timestamp INTEGER NOT NULL,
  ciphertext TEXT NOT NULL,
  ephemeral_pub_key TEXT NOT NULL,
  signature TEXT NOT NULL,
  source TEXT NOT NULL,
  hops INTEGER NOT NULL DEFAULT 0,
  chain_link TEXT,
  forked INTEGER NOT NULL DEFAULT 0,
  control INTEGER NOT NULL DEFAULT 0,
  group_payload INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (id)
);
INSERT INTO messages (
  id, sender_pub_key, recipient_pub_key, timestamp,
  ciphertext, ephemeral_pub_key, signature, source
) VALUES (
  'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
  'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
  5, 'ct', 'ep', 'sig', 'seed'
);
''';

const _v10MessagesSql = '''
CREATE TABLE messages (
  id TEXT NOT NULL,
  sender_pub_key TEXT NOT NULL,
  recipient_pub_key TEXT NOT NULL,
  timestamp INTEGER NOT NULL,
  ciphertext TEXT NOT NULL,
  ephemeral_pub_key TEXT NOT NULL,
  signature TEXT NOT NULL,
  source TEXT NOT NULL,
  hops INTEGER NOT NULL DEFAULT 0,
  chain_link TEXT,
  forked INTEGER NOT NULL DEFAULT 0,
  control INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (id)
);
INSERT INTO messages (
  id, sender_pub_key, recipient_pub_key, timestamp,
  ciphertext, ephemeral_pub_key, signature, source
) VALUES (
  'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
  'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
  5, 'ct', 'ep', 'sig', 'seed'
);
''';

const _v9MessagesSql = '''
CREATE TABLE messages (
  id TEXT NOT NULL,
  sender_pub_key TEXT NOT NULL,
  recipient_pub_key TEXT NOT NULL,
  timestamp INTEGER NOT NULL,
  ciphertext TEXT NOT NULL,
  ephemeral_pub_key TEXT NOT NULL,
  signature TEXT NOT NULL,
  source TEXT NOT NULL,
  hops INTEGER NOT NULL DEFAULT 0,
  chain_link TEXT,
  forked INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (id)
);
INSERT INTO messages (
  id, sender_pub_key, recipient_pub_key, timestamp,
  ciphertext, ephemeral_pub_key, signature, source
) VALUES (
  'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
  'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
  5, 'ct', 'ep', 'sig', 'seed'
);
''';

void _resolveSqlite3() {
  // Desktop test images often ship only the versioned library.
  try {
    sqlite3_open.open.overrideForAll(
      () => DynamicLibrary.open('libsqlite3.so.0'),
    );
  } catch (_) {
    // The override may already be installed by another test file.
  }
}

/// Version 7 added the outgoing_bodies table; the peers table here matches
/// the v7 shape (no is_contact column yet) with one seeded row.
void _writeV7Schema(String path) {
  _resolveSqlite3();
  final db = sqlite3_pkg.sqlite3.open(path);
  db.execute(_v7PeersSql);
  db.execute(_v7MessagesSql);
  db.execute('PRAGMA user_version = 7');
  db.dispose();
}

/// Version 7 already had chain_link/forked (added at v4); only the control
/// column is missing, so the table is present for the v10 migration step.
const _v7MessagesSql = '''
CREATE TABLE messages (
  id TEXT NOT NULL,
  sender_pub_key TEXT NOT NULL,
  recipient_pub_key TEXT NOT NULL,
  timestamp INTEGER NOT NULL,
  ciphertext TEXT NOT NULL,
  ephemeral_pub_key TEXT NOT NULL,
  signature TEXT NOT NULL,
  source TEXT NOT NULL,
  hops INTEGER NOT NULL DEFAULT 0,
  chain_link TEXT,
  forked INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (id)
);
''';

const _v8ConversationsSql = '''
CREATE TABLE peers (
  pub_key TEXT NOT NULL,
  ed_pub_key TEXT,
  display_name TEXT NOT NULL DEFAULT '',
  peer_id TEXT,
  addrs_json TEXT NOT NULL DEFAULT '[]',
  last_seen INTEGER NOT NULL DEFAULT 0,
  is_contact INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (pub_key)
);
CREATE TABLE messages (
  id TEXT NOT NULL,
  sender_pub_key TEXT NOT NULL,
  recipient_pub_key TEXT NOT NULL,
  timestamp INTEGER NOT NULL,
  ciphertext TEXT NOT NULL,
  ephemeral_pub_key TEXT NOT NULL,
  signature TEXT NOT NULL,
  source TEXT NOT NULL,
  hops INTEGER NOT NULL DEFAULT 0,
  chain_link TEXT,
  forked INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (id)
);
CREATE TABLE conversations (
  id TEXT NOT NULL,
  kind TEXT NOT NULL DEFAULT 'dm',
  title TEXT NOT NULL DEFAULT '',
  created_ts INTEGER NOT NULL DEFAULT 0,
  last_ts INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (id)
);
INSERT INTO conversations (id, kind, title, created_ts, last_ts)
VALUES ('aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        'dm', 'Old chat', 10, 100);
INSERT INTO conversations (id, kind, title, created_ts, last_ts)
VALUES ('bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
        'dm', '', 20, 200);
CREATE TABLE conversation_members (
  conversation_id TEXT NOT NULL,
  peer_x_key TEXT NOT NULL,
  PRIMARY KEY (conversation_id, peer_x_key)
);
''';

const _v7PeersSql = '''
CREATE TABLE conversations (
  id TEXT NOT NULL,
  kind TEXT NOT NULL DEFAULT 'dm',
  title TEXT NOT NULL DEFAULT '',
  created_ts INTEGER NOT NULL DEFAULT 0,
  last_ts INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (id)
);
INSERT INTO conversations (id, kind, title, created_ts, last_ts)
VALUES ('aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        'dm', 'v7 chat', 10, 100);
CREATE TABLE peers (
  pub_key TEXT NOT NULL,
  ed_pub_key TEXT,
  display_name TEXT NOT NULL DEFAULT '',
  peer_id TEXT,
  addrs_json TEXT NOT NULL DEFAULT '[]',
  last_seen INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (pub_key)
);
INSERT INTO peers (pub_key, display_name, last_seen)
VALUES ('aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        'Old', 1000);
''';
import 'dart:ffi';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:sqlite3/open.dart' as sqlite3_open;
import 'package:sqlite3/sqlite3.dart' as sqlite3_pkg;
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

part 'database.g.dart';

/// Immutable envelope storage — exactly one row per envelope [id].
/// The schema (including pruning indexes) is owned by the db-pruning skill.
@TableIndex(
  name: 'idx_messages_recipient_ts',
  columns: {#recipientPubKey, #timestamp},
)
@TableIndex(
  name: 'idx_messages_sender_ts',
  columns: {#senderPubKey, #timestamp},
)
@TableIndex(
  name: 'idx_messages_group_ts',
  columns: {#groupId, #timestamp},
)
class Messages extends Table {
  TextColumn get id => text()();
  TextColumn get senderPubKey => text()();
  TextColumn get recipientPubKey => text()();
  IntColumn get timestamp => integer()();
  TextColumn get ciphertext => text()();
  TextColumn get ephemeralPubKey => text()();
  TextColumn get signature => text()();
  TextColumn get source => text()();
  IntColumn get hops => integer().withDefault(const Constant(0))();
  TextColumn get chainLink => text().withDefault(const Constant(''))();
  IntColumn get forked => integer().withDefault(const Constant(0))();

  /// Local-only: marks an envelope that carries a control payload (a delivery
  /// or read receipt) rather than a chat message. Such rows are evidence and
  /// are deduped like any other, but never render as a bubble nor count as
  /// unread. Not part of the wire format.
  IntColumn get control => integer().withDefault(const Constant(0))();

  /// Local-only: marks an envelope that carries a group container (`g2`/`g3`/
  /// `t1`/legacy `g1`). Such a row is addressed to us like any 1:1 message, so
  /// without the mark it would count as unread on the sender's direct chat as
  /// well as on the group. Not part of the wire format.
  IntColumn get groupPayload => integer().withDefault(const Constant(0))();

  /// Local-only: the group conversation a container belongs to. Without it a
  /// member shared by two groups would make one group's message count as
  /// unread in the other. Not part of the wire format.
  TextColumn get groupId => text().nullable()();

  /// Local-only: the envelope may only travel over a direct peer transport
  /// (p2p/mesh), never through a relay host. Media slices use it so relays
  /// never store a file; the manifest still travels normally and lets the
  /// recipient show a "wait for the sender" placeholder.
  IntColumn get directOnly => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Head pointer of each directed (sender, recipient) history chain, used to
/// validate `chainLink` references and detect forked/fabulated histories.
class ConversationHeads extends Table {
  TextColumn get linkKey => text()();
  TextColumn get headId => text()();
  IntColumn get count => integer().withDefault(const Constant(0))();
  IntColumn get lastTs => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {linkKey};
}

/// Signed Merkle roots of pruned batches, kept for integrity proofs.
class PrunedRoots extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get cutoffTs => integer()();
  TextColumn get merkleRoot => text()();
  IntColumn get count => integer()();
  TextColumn get devicePubKey => text()();
  TextColumn get signature => text()();
}

/// Imported contacts (the peer book). Names and routing survive restarts;
/// `online` is a runtime flag and is deliberately not persisted.
class Peers extends Table {
  TextColumn get pubKey => text()();
  TextColumn get edPubKey => text().nullable()();
  TextColumn get displayName => text().withDefault(const Constant(''))();
  TextColumn get peerId => text().nullable()();
  TextColumn get addrsJson => text().withDefault(const Constant('[]'))();
  IntColumn get lastSeen => integer().withDefault(const Constant(0))();
  BoolColumn get isContact => boolean().withDefault(const Constant(false))();

  /// Ed25519 binding the user confirmed by comparing safety numbers. Kept
  /// across later upserts so a swapped key can be detected instead of trusted.
  TextColumn get verifiedEdPubKey => text().nullable()();

  /// When [verifiedEdPubKey] was confirmed, epoch milliseconds.
  IntColumn get verifiedAt => integer().nullable()();

  /// Local-only block: the processor drops this contact's envelopes after
  /// verification and never decrypts them. Kept across upserts.
  BoolColumn get blocked => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {pubKey};
}

/// Local identity persistence (keypairs, display name). Never synced.
class IdentityEntry extends Table {
  TextColumn get key => text().clientDefault(() => 'self')();
  TextColumn get edSeedHex => text()();
  TextColumn get xSeedHex => text()();
  TextColumn get displayName => text().withDefault(const Constant(''))();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {key};
}

/// Key-value app settings (app lock password record, biometric flag). Never
/// synced; the only table that is written through plain upsert.
class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

/// Chats. A 1:1 conversation uses [id] = the peer's X25519 address (same key
/// the account is addressed by); a group uses a random 32-byte hex id. [title]
/// is an optional user rename that never touches the peer-book display name.
class Conversations extends Table {
  TextColumn get id => text()();
  TextColumn get kind => text().withDefault(const Constant('dm'))();
  TextColumn get title => text().withDefault(const Constant(''))();
  IntColumn get createdTs => integer().withDefault(const Constant(0))();
  IntColumn get lastTs => integer().withDefault(const Constant(0))();

  /// Timestamp of the last time the user had this chat on screen. Unread is
  /// derived from the messages table (`timestamp > readAt`), so a count can
  /// never drift away from the messages it is counting.
  IntColumn get readAt => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Membership of [Conversations]: a 1:1 conversation has exactly one row
/// (the peer); every group participant incl. self gets a row.
class ConversationMembers extends Table {
  TextColumn get conversationId => text()();
  TextColumn get peerXKey => text()();

  /// `admin` may change the roster and title; `member` may only write.
  TextColumn get role => text().withDefault(const Constant('member'))();

  @override
  Set<Column> get primaryKey => {conversationId, peerXKey};
}

/// Local plaintext cache of this device's own sent messages, keyed by the
/// deterministic envelope id. Only populated while the user's
/// `soty.storeOutgoing` setting is on. Never synced or relayed; pruned
/// together with the matching envelope.
class OutgoingBodies extends Table {
  TextColumn get id => text()();
  TextColumn get plaintext => text()();
  IntColumn get timestamp => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Local cache of received (and optionally own) media blobs — the raw bytes
/// of a voice note or photo. Keyed by the content address [blobId] the
/// envelope carries, so two copies of the same file (a group fan-out, or a
/// resend) collapse into one row. Never synced or relayed: the wire envelope
/// still holds the encrypted copy, and this table only spares the device a
/// re-decrypt to re-render after the envelope itself is pruned.
class MediaBlobs extends Table {
  TextColumn get blobId => text()();

  /// `voice` or `photo`; stored as the wire tag so a value survives without
  /// depending on an enum ordinal.
  TextColumn get kind => text()();
  TextColumn get mime => text()();
  IntColumn get byteCount => integer()();
  IntColumn get durationMs => integer().withDefault(const Constant(0))();

  /// Base64 of the raw bytes for inline media (voice, photo). Empty for a
  /// chunked file stored on disk under [path].
  TextColumn get data => text()();
  IntColumn get timestamp => integer().withDefault(const Constant(0))();

  /// Relative path of the blob file for chunked media; empty for inline rows.
  TextColumn get path => text().withDefault(const Constant(''))();

  @override
  Set<Column> get primaryKey => {blobId};
}

/// An in-flight chunked file transfer (roadmap T-80).
///
/// The manifest arrives first and is stored as a chat message; this row keeps
/// the metadata a late or out-of-order chunk needs to be validated after a
/// restart. The row disappears together with its parts once the file is
/// assembled, or with the age policy if it never completes.
class Transfers extends Table {
  TextColumn get transferId => text()();
  TextColumn get blobId => text()();
  TextColumn get kind => text()();
  TextColumn get mime => text()();
  IntColumn get byteCount => integer()();
  IntColumn get chunkSize => integer()();
  IntColumn get chunkCount => integer()();
  TextColumn get sha256 => text()();
  IntColumn get durationMs => integer().withDefault(const Constant(0))();

  /// X25519 address of the sender, used for receipts and rendering.
  TextColumn get senderX => text()();

  /// Group the transfer belongs to (`''` for a 1:1 chat).
  TextColumn get conversationId => text().withDefault(const Constant(''))();

  /// Whether the download was started: automatic for files up to
  /// [autoDownloadBytes], explicit for larger ones.
  IntColumn get started => integer().withDefault(const Constant(0))();
  IntColumn get timestamp => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {transferId};
}

/// One received slice of an in-flight transfer. Keys are `(transferId, index)`
/// so a duplicate chunk is ignored and a resume after a restart continues from
/// what is already on disk. Deleted with the manifest once assembly succeeds.
class TransferParts extends Table {
  TextColumn get transferId => text()();
  IntColumn get index => integer()();
  IntColumn get byteCount => integer()();

  /// Legacy base64 slices from older builds; new slices are written to [path].
  TextColumn get data => text().withDefault(const Constant(''))();

  /// Relative path of one received slice under the media directory.
  TextColumn get path => text().withDefault(const Constant(''))();

  @override
  Set<Column> get primaryKey => {transferId, index};
}

/// Delivery lifecycle of this device's own outgoing envelopes. The envelope
/// itself stays immutable; this mutable side table is keyed by the envelope
/// [id] and only ever advances. Pruned together with the matching message.
class MessageStatuses extends Table {
  TextColumn get id => text()();
  IntColumn get status => integer().withDefault(const Constant(0))();
  IntColumn get updatedAt => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [
  Messages,
  PrunedRoots,
  IdentityEntry,
  AppSettings,
  ConversationHeads,
  Peers,
  Conversations,
  ConversationMembers,
  OutgoingBodies,
  MessageStatuses,
  MediaBlobs,
  Transfers,
  TransferParts,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 20;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(appSettings);
      }
      if (from < 3) {
        await m.createIndex(idxMessagesRecipientTs);
      }
      if (from < 4) {
        await m.addColumn(messages, messages.chainLink);
        await m.addColumn(messages, messages.forked);
        await m.createTable(conversationHeads);
      }
      if (from < 5) {
        await m.createTable(peers);
      }
      if (from < 6) {
        await m.createTable(conversations);
        await m.createTable(conversationMembers);
      }
      if (from < 7) {
        await m.createTable(outgoingBodies);
      }
      if (from < 8 && from >= 5) {
        await m.addColumn(peers, peers.isContact);
      }
      if (from < 9 && from >= 6) {
        await m.addColumn(conversations, conversations.readAt);
      }
      if (from < 9 && from >= 6) {
        await customStatement(
          'UPDATE conversations SET read_at = last_ts',
        );
      }
      if (from < 10) {
        await m.addColumn(messages, messages.control);
        await m.createTable(messageStatuses);
      }
      if (from < 11) {
        await m.addColumn(messages, messages.groupPayload);
      }
      if (from < 12) {
        await m.createTable(mediaBlobs);
      }
      if (from < 13) {
        await m.createIndex(idxMessagesSenderTs);
      }
      if (from < 16) {
        await m.addColumn(messages, messages.groupId);
        await m.createIndex(idxMessagesGroupTs);
      }
      if (from < 17) {
        await m.createTable(transfers);
        await m.createTable(transferParts);
        await m.addColumn(messages, messages.directOnly);
      }
      if (from < 18 && from >= 17) {
        await m.addColumn(transfers, transfers.started);
      }
      if (from < 19 && from >= 12) {
        await m.addColumn(mediaBlobs, mediaBlobs.path);
      }
      if (from < 19 && from >= 17) {
        await m.addColumn(transferParts, transferParts.path);
        // Slices from older builds live as base64 rows; their transfers simply
        // restart from zero rather than loading every part into memory.
        await customStatement('DELETE FROM transfer_parts');
      }
      if (from < 20) {
        // A v2/v3 database gets the peers table (with the column) from the
        // `from < 5` step above, and some legacy fixtures never had peers at
        // all, so add the column only when the table exists without it.
        final tables = await customSelect(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='peers'",
        ).get();
        if (tables.isNotEmpty) {
          final columns = await customSelect('PRAGMA table_info(peers)').get();
          final names = {
            for (final row in columns) row.read<String>('name'),
          };
          if (!names.contains('blocked')) {
            await m.addColumn(peers, peers.blocked);
          }
        }
      }
      if (from < 15) {
        final hasMembers = await customSelect(
          "SELECT name FROM sqlite_master WHERE type='table' "
          "AND name='conversation_members'",
        ).get();
        if (hasMembers.isEmpty) {
          await m.createTable(conversationMembers);
        } else if (from >= 6) {
          await m.addColumn(conversationMembers, conversationMembers.role);
          // Groups created before roles existed had no owner: every current
          // member keeps the ability to manage them instead of locking the
          // roster forever.
          await customStatement(
            "UPDATE conversation_members SET role = 'admin'",
          );
        }
      }
      if (from < 14) {
        // Old fixtures (and pre-v5 files) may not have a peers table yet;
        // createTable already includes the new columns, so only an existing
        // v5+ table needs them added.
        final hasPeers = await customSelect(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='peers'",
        ).get();
        if (hasPeers.isEmpty) {
          await m.createTable(peers);
        } else if (from >= 5) {
          await m.addColumn(peers, peers.verifiedEdPubKey);
          await m.addColumn(peers, peers.verifiedAt);
        }
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  /// Opens the app database at `$dir/dtm.sqlite`.
  static Future<AppDatabase> open(String dir) async {
    await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
    _resolveSqlite3();
    final file = File('$dir/dtm.sqlite');
    return AppDatabase(NativeDatabase(file));
  }

  /// In-memory database, used by tests.
  static AppDatabase inMemory() {
    _resolveSqlite3();
    return AppDatabase(NativeDatabase.memory());
  }

  /// The sqlite3 package defaults to loading `libsqlite3.so`, but some hosts
  /// (e.g. desktop Linux test images) only ship the versioned library. Falls
  /// back to `libsqlite3.so.0` so drift still opens.
  static void _resolveSqlite3() {
    try {
      // Triggers the package's default loader.
      sqlite3_pkg.sqlite3;
    } catch (_) {
      sqlite3_open.open.overrideForAll(
        () => DynamicLibrary.open('libsqlite3.so.0'),
      );
    }
  }
}

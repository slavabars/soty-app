import 'dart:async' show StreamIterator;
import 'dart:convert' show LineSplitter, jsonDecode, jsonEncode, utf8;
import 'dart:io' show File;

import 'package:drift/drift.dart' show OrderingTerm;

import '../../models/peer.dart';
import '../crypto/keypair.dart';
import '../security_limits.dart';
import '../storage/identity_dao.dart';
import '../storage/peer_dao.dart';
import 'backup_crypto.dart';
import 'backup_format.dart';
import 'backup_stream.dart';

/// Captures the local identity, contact book and message history into an
/// encrypted backup and puts them back on another device.
///
/// Envelopes travel as ciphertext; only this device's own outgoing plaintext
/// (when the user enabled `storeOutgoing`) is included as text. Media bytes are
/// not part of the backup: they are content-addressed caches that can be
/// re-rendered from the envelopes when the blob is still available.
class BackupService {
  final IdentityDao identityDao;
  final PeerDao peerDao;

  const BackupService({required this.identityDao, required this.peerDao});

  /// Reads the identity and peers and returns the sealed document.
  Future<String> exportBackup({required String password}) async {
    final stored = await identityDao.load();
    if (stored == null) {
      throw StateError('no identity to back up');
    }
    final peers = await peerDao.all();
    final payload = BackupPayload(
      identity: BackupIdentity(
        edSeedHex: await stored.keyPair.ed25519SeedHex,
        xSeedHex: await stored.keyPair.x25519SeedHex,
        displayName: stored.displayName,
      ),
      peers: [
        for (final peer in peers.take(maxBackupPeers))
          BackupPeer.fromPeer(peer),
      ],
      history: await _exportHistory(),
    );
    return BackupFile.seal(payload: payload.encode(), password: password);
  }

  /// Decrypts and validates a backup without touching any local state.
  Future<BackupPayload> readBackup({
    required String raw,
    required String password,
  }) async {
    final clear = await BackupFile.open(raw: raw, password: password);
    return BackupPayload.decode(clear);
  }

  /// Streams the same identity, contact book and history into an encrypted
  /// file without materializing the whole document. This is the path used by
  /// the Settings screen once a history can approach the 1 GiB cap.
  Future<void> exportBackupToFile({
    required String path,
    required String password,
  }) async {
    final stored = await identityDao.load();
    if (stored == null) {
      throw StateError('no identity to back up');
    }
    final peers = await peerDao.all();
    await BackupStream.write(
      path: path,
      password: password,
      plaintext: _exportRecords(stored, peers),
    );
  }

  /// The JSON-lines payload of a streaming backup: one header record followed
  /// by conversations, messages, statuses and outgoing bodies. Each line is
  /// bounded by one row, so the generator never holds the whole history.
  Stream<List<int>> _exportRecords(
    StoredIdentity stored,
    List<DtmPeer> peers,
  ) async* {
    final db = identityDao.attachedDatabase;
    final header = <String, Object?>{
      'type': 'header',
      'format': 'soty-backup-payload-3',
      'identity': BackupIdentity(
        edSeedHex: await stored.keyPair.ed25519SeedHex,
        xSeedHex: await stored.keyPair.x25519SeedHex,
        displayName: stored.displayName,
      ).toJson(),
      'peers': [
        for (final peer in peers.take(maxBackupPeers))
          BackupPeer.fromPeer(peer).toJson(),
      ],
    };
    yield utf8.encode('${jsonEncode(header)}\n');

    final conversationRows = await (db.select(db.conversations)
          ..orderBy([(c) => OrderingTerm.desc(c.lastTs)])
          ..limit(maxBackupConversations))
        .get();
    final memberRows = await db.select(db.conversationMembers).get();
    final membersByConversation = <String, List<({String key, String role})>>{};
    for (final row in memberRows) {
      (membersByConversation[row.conversationId] ??= []).add((
        key: row.peerXKey,
        role: row.role,
      ));
    }
    for (final row in conversationRows) {
      final conversation = BackupConversation(
        id: row.id,
        kind: row.kind,
        title: row.title,
        createdTs: row.createdTs,
        lastTs: row.lastTs,
        readAt: row.readAt,
        members: membersByConversation[row.id] ?? const [],
      );
      yield utf8.encode(
        '${jsonEncode({'type': 'conversation', 'v': conversation.toJson()})}\n',
      );
    }

    final ids = <String>{};
    for (var offset = 0; offset < maxBackupMessages; offset += 500) {
      final rows = await (db.select(db.messages)
            ..where((m) => m.control.equals(0))
            ..orderBy([
              (m) => OrderingTerm.desc(m.timestamp),
              (m) => OrderingTerm.desc(m.id),
            ])
            ..limit(500, offset: offset))
          .get();
      if (rows.isEmpty) break;
      for (final row in rows) {
        ids.add(row.id);
        final message = BackupMessage(
          id: row.id,
          senderPubKey: row.senderPubKey,
          recipientPubKey: row.recipientPubKey,
          timestamp: row.timestamp,
          ciphertext: row.ciphertext,
          ephemeralPubKey: row.ephemeralPubKey,
          signature: row.signature,
          source: row.source,
          hops: row.hops,
          chainLink: row.chainLink,
          forked: row.forked == 1,
          control: row.control == 1,
          groupPayload: row.groupPayload == 1,
          groupId: row.groupId,
        );
        yield utf8.encode(
          '${jsonEncode({'type': 'message', 'v': message.toJson()})}\n',
        );
      }
    }

    final statusRows = await db.select(db.messageStatuses).get();
    for (final row in statusRows) {
      if (!ids.contains(row.id)) continue;
      final status = BackupStatus(
        id: row.id,
        status: row.status,
        updatedAt: row.updatedAt,
      );
      yield utf8.encode(
        '${jsonEncode({'type': 'status', 'v': status.toJson()})}\n',
      );
    }

    final bodyRows = await db.select(db.outgoingBodies).get();
    for (final row in bodyRows) {
      if (!ids.contains(row.id)) continue;
      final body = BackupBody(
        id: row.id,
        plaintext: row.plaintext,
        timestamp: row.timestamp,
      );
      yield utf8.encode(
        '${jsonEncode({'type': 'body', 'v': body.toJson()})}\n',
      );
    }
  }

  /// Restores a file written by [exportBackupToFile]. A legacy
  /// `soty-backup-1`/`soty-backup-2` document is still accepted and read in
  /// one piece, because old backups predate streaming and are small.
  Future<void> restoreBackupFromFile({
    required String path,
    required String password,
    required bool replaceExisting,
  }) async {
    if (!await BackupStream.isStreamFile(path)) {
      final raw = await File(path).readAsString();
      final payload = await readBackup(raw: raw, password: password);
      await restore(payload, replaceExisting: replaceExisting);
      return;
    }
    if (!replaceExisting && await identityDao.hasIdentity()) {
      throw StateError(
        'restoring over an existing identity needs confirmation',
      );
    }
    final lines = BackupStream.read(path: path, password: password)
        .transform(utf8.decoder)
        .transform(const LineSplitter());
    final iterator = StreamIterator<String>(lines);
    try {
      if (!await iterator.moveNext()) {
        throw const FormatException('backup is empty');
      }
      final headerRaw = jsonDecode(iterator.current);
      if (headerRaw is! Map<String, dynamic> ||
          headerRaw['type'] != 'header' ||
          headerRaw['format'] != 'soty-backup-payload-3') {
        throw const FormatException('unsupported backup payload');
      }
      final identity = BackupIdentity.fromJson(headerRaw['identity']);
      final rawPeers = headerRaw['peers'];
      if (rawPeers is! List || rawPeers.length > maxBackupPeers) {
        throw const FormatException('too many peers in backup');
      }
      final keyPair = await DtmKeyPair.fromSeeds(
        ed25519SeedHex: identity.edSeedHex,
        x25519SeedHex: identity.xSeedHex,
      );
      await identityDao.save(keyPair, displayName: identity.displayName);
      for (final rawPeer in rawPeers) {
        await _restorePeer(BackupPeer.fromJson(rawPeer));
      }

      final db = identityDao.attachedDatabase;
      await db.transaction(() async {
        var conversations = 0;
        var messages = 0;
        while (await iterator.moveNext()) {
          final line = iterator.current;
          if (line.isEmpty) continue;
          final Object? decoded;
          try {
            decoded = jsonDecode(line);
          } on FormatException {
            throw const FormatException('backup record is not JSON');
          }
          if (decoded is! Map<String, dynamic>) {
            throw const FormatException('backup record must be an object');
          }
          switch (decoded['type']) {
            case 'conversation':
              conversations++;
              if (conversations > maxBackupConversations) {
                throw const FormatException('too many conversations');
              }
              await _applyConversation(
                BackupConversation.fromJson(decoded['v']),
              );
            case 'message':
              messages++;
              if (messages > maxBackupMessages) {
                throw const FormatException('too many messages');
              }
              await _applyMessage(BackupMessage.fromJson(decoded['v']));
            case 'status':
              await _applyStatus(BackupStatus.fromJson(decoded['v']));
            case 'body':
              await _applyBody(BackupBody.fromJson(decoded['v']));
            default:
              throw const FormatException('unknown backup record');
          }
        }
      });
    } finally {
      await iterator.cancel();
    }
  }

  /// Writes [payload] into this device.
  ///
  /// An existing identity is only replaced with [replaceExisting] true; the
  /// caller is expected to have shown the confirmation dialog first. Seeds go
  /// through [IdentityDao.save], so on Android they land in the Keystore and
  /// the database row keeps no secret.
  Future<void> restore(
    BackupPayload payload, {
    required bool replaceExisting,
  }) async {
    if (!replaceExisting && await identityDao.hasIdentity()) {
      throw StateError(
        'restoring over an existing identity needs confirmation',
      );
    }
    final keyPair = await DtmKeyPair.fromSeeds(
      ed25519SeedHex: payload.identity.edSeedHex,
      x25519SeedHex: payload.identity.xSeedHex,
    );
    await identityDao.save(
      keyPair,
      displayName: payload.identity.displayName,
    );
    for (final peer in payload.peers) {
      await _restorePeer(peer);
    }
    final history = payload.history;
    if (history != null) {
      await _restoreHistory(history);
    }
  }

  Future<BackupHistory> _exportHistory() async {
    final db = identityDao.attachedDatabase;
    final conversationRows = await (db.select(db.conversations)
          ..orderBy([(c) => OrderingTerm.desc(c.lastTs)])
          ..limit(maxBackupConversations))
        .get();
    // Control rows (receipts, media slices and slice requests) are transport
    // bookkeeping, not history. Excluding them keeps a backup with a large
    // media conversation from ballooning past the 1 GiB cap, and they would
    // render nothing after a restore anyway.
    final messageRows = await (db.select(db.messages)
          ..where((m) => m.control.equals(0))
          ..orderBy([(m) => OrderingTerm.desc(m.timestamp)])
          ..limit(maxBackupMessages))
        .get();
    final ids = {for (final row in messageRows) row.id};
    final statusRows = await db.select(db.messageStatuses).get();
    final bodyRows = await db.select(db.outgoingBodies).get();
    final memberRows = await db.select(db.conversationMembers).get();
    final membersByConversation = <String, List<({String key, String role})>>{};
    for (final row in memberRows) {
      (membersByConversation[row.conversationId] ??= []).add((
        key: row.peerXKey,
        role: row.role,
      ));
    }

    return BackupHistory(
      conversations: [
        for (final row in conversationRows)
          BackupConversation(
            id: row.id,
            kind: row.kind,
            title: row.title,
            createdTs: row.createdTs,
            lastTs: row.lastTs,
            readAt: row.readAt,
            members: membersByConversation[row.id] ?? const [],
          ),
      ],
      messages: [
        for (final row in messageRows)
          BackupMessage(
            id: row.id,
            senderPubKey: row.senderPubKey,
            recipientPubKey: row.recipientPubKey,
            timestamp: row.timestamp,
            ciphertext: row.ciphertext,
            ephemeralPubKey: row.ephemeralPubKey,
            signature: row.signature,
            source: row.source,
            hops: row.hops,
            chainLink: row.chainLink,
            forked: row.forked != 0,
            control: row.control != 0,
            groupPayload: row.groupPayload != 0,
            groupId: row.groupId,
          ),
      ],
      statuses: [
        for (final row in statusRows)
          if (ids.contains(row.id))
            BackupStatus(
              id: row.id,
              status: row.status,
              updatedAt: row.updatedAt,
            ),
      ],
      bodies: [
        for (final row in bodyRows)
          if (ids.contains(row.id))
            BackupBody(
              id: row.id,
              plaintext: row.plaintext,
              timestamp: row.timestamp,
            ),
      ],
    );
  }

  /// Restores history without deleting anything this device already knows:
  /// messages dedupe by id, conversations keep the newer `lastTs`/`read_at`,
  /// statuses only move forward. Re-running a restore is therefore safe.
  Future<void> _restoreHistory(BackupHistory history) async {
    final db = identityDao.attachedDatabase;
    await db.transaction(() async {
      for (final conversation in history.conversations) {
        await _applyConversation(conversation);
      }
      for (final message in history.messages) {
        await _applyMessage(message);
      }
      for (final status in history.statuses) {
        await _applyStatus(status);
      }
      for (final body in history.bodies) {
        await _applyBody(body);
      }
    });
  }

  Future<void> _applyConversation(BackupConversation conversation) async {
    final db = identityDao.attachedDatabase;
    await db.customStatement(
      'INSERT INTO conversations '
      '(id, kind, title, created_ts, last_ts, read_at) '
      'VALUES (?, ?, ?, ?, ?, ?) '
      'ON CONFLICT(id) DO UPDATE SET '
      'title = excluded.title, '
      'last_ts = MAX(conversations.last_ts, excluded.last_ts), '
      'read_at = MAX(conversations.read_at, excluded.read_at)',
      [
        conversation.id,
        conversation.kind,
        conversation.title,
        conversation.createdTs,
        conversation.lastTs,
        conversation.readAt,
      ],
    );
    await (db.delete(db.conversationMembers)
          ..where((m) => m.conversationId.equals(conversation.id)))
        .go();
    for (final member in conversation.members) {
      await db.customStatement(
        'INSERT OR REPLACE INTO conversation_members '
        '(conversation_id, peer_x_key, role) VALUES (?, ?, ?)',
        [conversation.id, member.key, member.role],
      );
    }
  }

  Future<void> _applyMessage(BackupMessage message) async {
    final db = identityDao.attachedDatabase;
    await db.customStatement(
      'INSERT OR IGNORE INTO messages '
      '(id, sender_pub_key, recipient_pub_key, timestamp, ciphertext, '
      'ephemeral_pub_key, signature, source, hops, chain_link, forked, '
      'control, group_payload, group_id) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [
        message.id,
        message.senderPubKey,
        message.recipientPubKey,
        message.timestamp,
        message.ciphertext,
        message.ephemeralPubKey,
        message.signature,
        message.source,
        message.hops,
        message.chainLink,
        message.forked ? 1 : 0,
        message.control ? 1 : 0,
        message.groupPayload ? 1 : 0,
        message.groupId,
      ],
    );
  }

  Future<void> _applyStatus(BackupStatus status) async {
    final db = identityDao.attachedDatabase;
    await db.customStatement(
      'INSERT INTO message_statuses (id, status, updated_at) '
      'VALUES (?, ?, ?) '
      'ON CONFLICT(id) DO UPDATE SET '
      'status = MAX(message_statuses.status, excluded.status), '
      'updated_at = MAX(message_statuses.updated_at, excluded.updated_at)',
      [status.id, status.status, status.updatedAt],
    );
  }

  Future<void> _applyBody(BackupBody body) async {
    final db = identityDao.attachedDatabase;
    await db.customStatement(
      'INSERT OR IGNORE INTO outgoing_bodies '
      '(id, plaintext, timestamp) VALUES (?, ?, ?)',
      [body.id, body.plaintext, body.timestamp],
    );
  }

  Future<void> _restorePeer(BackupPeer peer) async {
    await peerDao.upsert(peer.toPeer());
    final verified = peer.verifiedEdPubKey;
    // A backup cannot make a *different* key trusted: only a binding that
    // still matches what the file recorded is restored as verified.
    if (verified != null && verified == peer.edPubKey) {
      await peerDao.markVerified(peer.pubKey, verified);
    }
  }
}

/// Convenience for callers that hold raw [DtmPeer] objects (tests, tooling).
BackupPeer backupPeerOf(DtmPeer peer) => BackupPeer.fromPeer(peer);

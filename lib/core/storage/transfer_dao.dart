import 'dart:convert' show base64Decode;

import 'package:drift/drift.dart';

import '../../models/message_payload.dart' show MediaKind;
import '../media/media_store.dart';
import 'database.dart';

/// One in-flight chunked transfer as stored on this device.
class StoredTransfer {
  final String transferId;
  final String blobId;
  final MediaKind kind;
  final String mime;
  final int byteCount;
  final int chunkSize;
  final int chunkCount;
  final String sha256;
  final int durationMs;
  final String senderX;
  final String conversationId;
  final bool started;
  final bool completed;
  final int timestamp;

  const StoredTransfer({
    required this.transferId,
    required this.blobId,
    required this.kind,
    required this.mime,
    required this.byteCount,
    required this.chunkSize,
    required this.chunkCount,
    required this.sha256,
    required this.durationMs,
    required this.senderX,
    required this.conversationId,
    required this.started,
    this.completed = false,
    required this.timestamp,
  });
}

/// Persists chunked-transfer manifests and their received slices so an
/// interrupted file can be resumed after a restart instead of starting over.
/// Slices are files under [MediaStore]; the assembler streams them into one
/// blob and deletes the staging directory.
class TransferDao extends DatabaseAccessor<AppDatabase> {
  TransferDao(super.db, {MediaStore? store})
      : store = store ?? MediaStore.instance;

  final MediaStore store;

  /// Stores a manifest if it is new. A repeated manifest keeps the first copy,
  /// so a hostile resend cannot swap the file a bubble already points at.
  Future<void> putManifest(StoredTransfer transfer) async {
    await into(db.transfers).insert(
      TransfersCompanion.insert(
        transferId: transfer.transferId,
        blobId: transfer.blobId,
        kind: transfer.kind.name,
        mime: transfer.mime,
        byteCount: transfer.byteCount,
        chunkSize: transfer.chunkSize,
        chunkCount: transfer.chunkCount,
        sha256: transfer.sha256,
        durationMs: Value(transfer.durationMs),
        senderX: transfer.senderX,
        conversationId: Value(transfer.conversationId),
        started: Value(transfer.started ? 1 : 0),
        completed: Value(transfer.completed ? 1 : 0),
        timestamp: Value(transfer.timestamp),
      ),
      mode: InsertMode.insertOrIgnore,
    );
  }

  Future<StoredTransfer?> get(String transferId) async {
    final row = await (select(db.transfers)
          ..where((t) => t.transferId.equals(transferId)))
        .getSingleOrNull();
    return row == null ? null : _toStored(row, started: row.started == 1);
  }

  /// Marks a large transfer as explicitly started by the user.
  Future<void> setStarted(String transferId) async {
    await (update(db.transfers)
          ..where((t) => t.transferId.equals(transferId)))
        .write(const TransfersCompanion(started: Value(1)));
  }

  /// Stores one validated slice on disk. Returns `false` when the index is
  /// already present, so a duplicate chunk neither overwrites bytes nor
  /// inflates progress.
  Future<bool> putPart({
    required String transferId,
    required int index,
    required int byteCount,
    required Uint8List bytes,
  }) async {
    final path = await store.writePart(transferId, index, bytes);
    final inserted = await into(db.transferParts).insert(
      TransferPartsCompanion.insert(
        transferId: transferId,
        index: index,
        byteCount: byteCount,
        // A database upgraded from v18 has `data TEXT NOT NULL` without a
        // DEFAULT, while a fresh one gets Drift's default. Relying on that
        // default makes the insert violate NOT NULL on upgraded installs, and
        // insertOrIgnore then silently drops every slice row.
        data: const Value(''),
        path: Value(path),
      ),
      mode: InsertMode.insertOrIgnore,
    );
    return inserted > 0;
  }

  /// Bytes received so far for [transferId].
  Future<int> receivedBytes(String transferId) async {
    final sum = db.transferParts.byteCount.sum();
    final row = await (selectOnly(db.transferParts)
      ..addColumns([sum])
      ..where(db.transferParts.transferId.equals(transferId)))
        .getSingle();
    return row.read(sum) ?? 0;
  }

  Future<int> partCount(String transferId) async {
    final count = db.transferParts.transferId.count();
    final row = await (selectOnly(db.transferParts)
      ..addColumns([count])
      ..where(db.transferParts.transferId.equals(transferId)))
        .getSingle();
    return row.read(count) ?? 0;
  }

  /// Indices received so far, without reading the payload bytes.
  Future<Set<int>> partIndexes(String transferId) async {
    final rows = await (selectOnly(db.transferParts)
      ..addColumns([db.transferParts.index])
      ..where(db.transferParts.transferId.equals(transferId)))
        .get();
    return {
      for (final row in rows) row.read(db.transferParts.index)!,
    };
  }

  /// One slice, decoded, or `null` when it has not arrived. Used by the
  /// serving path and never larger than one chunk.
  Future<Uint8List?> part(String transferId, int index) async {
    final row = await (select(db.transferParts)
          ..where(
            (p) => p.transferId.equals(transferId) & p.index.equals(index),
          ))
        .getSingleOrNull();
    if (row == null) return null;
    if (row.path.isNotEmpty) {
      return store.readPart(transferId, index);
    }
    if (row.data.isEmpty) return null;
    return base64Decode(row.data);
  }

  /// Streams all slices into a completed blob and verifies its digest.
  Future<String?> assemble(StoredTransfer transfer) async {
    try {
      return await store.assemble(
        transferId: transfer.transferId,
        chunkCount: transfer.chunkCount,
        blobId: transfer.blobId,
        sha256: transfer.sha256,
      );
    } on MediaDigestMismatch {
      await remove(transfer.transferId);
      return null;
    }
  }

  /// Marks a fully assembled transfer as completed. The manifest row is kept
  /// (without slices) so `_acceptFileRequest` can still decide who is
  /// entitled to the blob after the staging area is gone.
  Future<void> markCompleted(String transferId) async {
    await (delete(db.transferParts)
          ..where((p) => p.transferId.equals(transferId)))
        .go();
    await (update(db.transfers)
          ..where((t) => t.transferId.equals(transferId)))
        .write(const TransfersCompanion(completed: Value(1)));
    await store.deleteTransfer(transferId);
  }

  /// Drops a completed (or abandoned) transfer and every slice it had.
  Future<void> remove(String transferId) async {
    await (delete(db.transferParts)
          ..where((p) => p.transferId.equals(transferId)))
        .go();
    await (delete(db.transfers)
          ..where((t) => t.transferId.equals(transferId)))
        .go();
    await store.deleteTransfer(transferId);
  }

  /// Drops manifests older than [cutoffTs]. Their slices go too.
  Future<int> pruneBefore(int cutoffTs) async {
    final stale = await (select(db.transfers)
          ..where((t) => t.timestamp.isSmallerThanValue(cutoffTs)))
        .get();
    for (final row in stale) {
      await remove(row.transferId);
    }
    return stale.length;
  }

  /// Transfers whose download was started, used to resume after a restart.
  Future<List<StoredTransfer>> startedTransfers() async {
    final rows = await (select(db.transfers)
          ..where((t) => t.started.equals(1) & t.completed.equals(0)))
        .get();
    return [for (final row in rows) _toStored(row, started: true)];
  }

  /// Active transfer count, for the retention cap.
  Future<int> count() async {
    final row = await (selectOnly(db.transfers)
          ..addColumns([db.transfers.transferId.count()])
          ..where(db.transfers.completed.equals(0)))
        .getSingle();
    return row.read(db.transfers.transferId.count()) ?? 0;
  }

  /// Oldest active transfer timestamp, used to bound the staging area.
  Future<StoredTransfer?> oldest() async {
    final row = await (select(db.transfers)
          ..where((t) => t.completed.equals(0))
          ..orderBy([(t) => OrderingTerm(expression: t.timestamp)])
          ..limit(1))
        .getSingleOrNull();
    if (row == null) return null;
    return _toStored(row, started: row.started == 1);
  }

  StoredTransfer _toStored(Transfer row, {required bool started}) =>
      StoredTransfer(
        transferId: row.transferId,
        blobId: row.blobId,
        kind: _kindFromTag(row.kind),
        mime: row.mime,
        byteCount: row.byteCount,
        chunkSize: row.chunkSize,
        chunkCount: row.chunkCount,
        sha256: row.sha256,
        durationMs: row.durationMs,
        senderX: row.senderX,
        conversationId: row.conversationId,
        started: started,
        completed: row.completed == 1,
        timestamp: row.timestamp,
      );
}

MediaKind _kindFromTag(String tag) => MediaKind.values.firstWhere(
      (kind) => kind.name == tag,
      orElse: () => MediaKind.photo,
    );

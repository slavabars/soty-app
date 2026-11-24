import 'dart:convert' show base64Decode, base64Encode;
import 'dart:io';

import 'package:drift/drift.dart';

import '../../models/message_payload.dart';
import '../media/media_store.dart';
import 'database.dart';

/// Storage for received and locally-sent media blobs (voice notes, photos and
/// assembled chunked files). Rows are immutable and keyed by the content
/// address, so a repeated file is stored once and pruning is a pure time/cap
/// decision. Inline media keeps its bytes as base64 in the row; a chunked file
/// points at a file under [MediaStore].
class MediaDao extends DatabaseAccessor<AppDatabase> {
  MediaDao(super.db, {MediaStore? store})
      : store = store ?? MediaStore.instance;

  final MediaStore store;

  /// Persists inline [dataBase64] under [blobId] if the id is not already
  /// stored; the first copy wins, so a later hostile overwrite can never swap
  /// the bytes a bubble already points at.
  Future<void> put({
    required String blobId,
    required MediaKind kind,
    required String mime,
    required int byteCount,
    required int durationMs,
    required String dataBase64,
    required int timestamp,
  }) async {
    await into(db.mediaBlobs).insert(
      MediaBlobsCompanion.insert(
        blobId: blobId,
        kind: kind.name,
        mime: mime,
        byteCount: byteCount,
        durationMs: Value(durationMs),
        data: dataBase64,
        timestamp: Value(timestamp),
      ),
      mode: InsertMode.insertOrIgnore,
    );
  }

  /// Persists a chunked file already written to the blob store.
  Future<void> putFile({
    required String blobId,
    required MediaKind kind,
    required String mime,
    required int byteCount,
    required int durationMs,
    required String path,
    required int timestamp,
  }) async {
    await into(db.mediaBlobs).insert(
      MediaBlobsCompanion.insert(
        blobId: blobId,
        kind: kind.name,
        mime: mime,
        byteCount: byteCount,
        durationMs: Value(durationMs),
        data: '',
        path: Value(path),
        timestamp: Value(timestamp),
      ),
      mode: InsertMode.insertOrIgnore,
    );
  }

  /// The blob stored under [blobId], or `null` when it was never cached or has
  /// been pruned.
  Future<StoredMedia?> get(String blobId) async {
    final row = await (select(db.mediaBlobs)
          ..where((b) => b.blobId.equals(blobId)))
        .getSingleOrNull();
    return row == null ? null : _toStored(row);
  }

  /// Blobs for a batch of content addresses; unknown ids are omitted so a
  /// conversation render stays one query.
  Future<Map<String, StoredMedia>> byIds(Iterable<String> blobIds) async {
    final list = blobIds.toList(growable: false);
    if (list.isEmpty) return const {};
    final rows = await (select(db.mediaBlobs)
          ..where((b) => b.blobId.isIn(list)))
        .get();
    return {for (final row in rows) row.blobId: _toStored(row)};
  }

  /// Deletes every blob stamped strictly before [cutoffTs]. Returns the number
  /// of rows removed. Never touches an envelope.
  Future<int> pruneBefore(int cutoffTs) async {
    final rows = await (select(db.mediaBlobs)
          ..where((b) => b.timestamp.isSmallerThanValue(cutoffTs)))
        .get();
    final removed = await (delete(db.mediaBlobs)
          ..where((b) => b.timestamp.isSmallerThanValue(cutoffTs)))
        .go();
    for (final row in rows) {
      if (row.path.isNotEmpty) await store.deleteBlob(row.blobId);
    }
    return removed;
  }

  /// Deletes exactly the listed content addresses. Returns the number of rows
  /// removed.
  Future<int> deleteIds(Iterable<String> blobIds) async {
    final list = blobIds.toList(growable: false);
    if (list.isEmpty) return 0;
    final removed = await (delete(db.mediaBlobs)
          ..where((b) => b.blobId.isIn(list)))
        .go();
    for (final id in list) {
      await store.deleteBlob(id);
    }
    return removed;
  }

  /// Total raw bytes represented by the cached blobs.
  Future<int> totalBytes() async {
    final sum = db.mediaBlobs.byteCount.sum();
    final row = await (selectOnly(db.mediaBlobs)..addColumns([sum]))
        .getSingle();
    return row.read(sum) ?? 0;
  }

  /// Drops the oldest blobs until the cache fits [maxBytes]. Returns the
  /// number of rows removed. Never touches an envelope.
  Future<int> pruneToBytes(int maxBytes) async {
    if (maxBytes <= 0) return 0;
    var remaining = await totalBytes();
    if (remaining <= maxBytes) return 0;
    final rows = await (select(db.mediaBlobs)
          ..orderBy([
            (b) => OrderingTerm(expression: b.timestamp),
          ]))
        .get();
    final ids = <String>[];
    for (final row in rows) {
      if (remaining <= maxBytes) break;
      ids.add(row.blobId);
      remaining -= row.byteCount;
    }
    return deleteIds(ids);
  }

  /// The number of stored blobs, for the retention policy.
  Future<int> count() async {
    final row = await (selectOnly(db.mediaBlobs)
          ..addColumns([db.mediaBlobs.blobId.count()]))
        .getSingle();
    return row.read(db.mediaBlobs.blobId.count()) ?? 0;
  }

  StoredMedia _toStored(MediaBlob row) => StoredMedia(
    blobId: row.blobId,
    kind: _kindFromTag(row.kind),
    mime: row.mime,
    byteCount: row.byteCount,
    durationMs: row.durationMs,
    dataBase64: row.data,
    filePath: row.path,
    timestamp: row.timestamp,
    store: store,
  );
}

/// Maps a stored wire tag back to a [MediaKind]; an unknown tag means the row
/// was written by a future version and is treated as a photo so it is still
/// listed rather than dropped.
MediaKind _kindFromTag(String tag) =>
    MediaKind.values.firstWhere(
      (kind) => kind.name == tag,
      orElse: () => MediaKind.photo,
    );

/// One cached media blob, decoded for rendering.
class StoredMedia {
  final String blobId;
  final MediaKind kind;
  final String mime;
  final int byteCount;
  final int durationMs;
  final String dataBase64;

  /// Relative path of a chunked file; empty for inline base64 media.
  final String filePath;
  final int timestamp;
  final MediaStore store;

  const StoredMedia({
    required this.blobId,
    required this.kind,
    required this.mime,
    required this.byteCount,
    required this.durationMs,
    required this.dataBase64,
    this.filePath = '',
    required this.timestamp,
    required this.store,
  });

  bool get hasFile => filePath.isNotEmpty;

  /// Absolute file for a chunked blob, or `null` for inline media.
  Future<File?> file() async {
    if (!hasFile) return null;
    return store.blobFile(blobId);
  }

  /// The raw bytes, whether the blob lives inline or on disk. Only call this
  /// for a bounded blob; a large file should be streamed through [file].
  Future<Uint8List> readBytes() async {
    if (hasFile) {
      final source = await file();
      if (source == null || !await source.exists()) return Uint8List(0);
      return source.readAsBytes();
    }
    return base64Decode(dataBase64);
  }

  Duration get duration => Duration(milliseconds: durationMs);

  String get asBase64 => dataBase64;

  /// Convenience for a test or a debug dump: the base64 form again.
  String reencode() => base64Encode(base64Decode(dataBase64));
}

import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart' show Sha256;
import 'package:path_provider/path_provider.dart';

import '../crypto/hex.dart' show isHexOfLength;
import '../security_limits.dart' show transferChunkBytes;

/// File-backed store for media blobs and in-flight transfer slices.
///
/// Small inline media (voice notes, photos) still travels base64 inside the
/// envelope and stays in SQLite. A chunked video or file is different: its
/// assembled bytes and every received slice live under this directory, so a
/// multi-gigabyte transfer never becomes one Dart string or byte array.
class MediaDigestMismatch implements Exception {
  const MediaDigestMismatch();
}

class MediaStore {
  /// Default instance used by the DAOs. Tests replace [overrideRoot] with a
  /// temporary directory.
  static MediaStore instance = MediaStore();

  static Directory? overrideRoot;

  Future<Directory>? _rootFuture;

  Future<Directory> _base() async {
    final overridden = overrideRoot;
    if (overridden != null) return overridden;
    return _rootFuture ??= _createRoot();
  }

  Future<Directory> _createRoot() async {
    Directory base;
    try {
      base = await getApplicationSupportDirectory();
    } catch (_) {
      base = await Directory.systemTemp.createTemp('soty_media_');
    }
    final root = Directory('${base.path}/media');
    await root.create(recursive: true);
    return root;
  }

  Future<Directory> _dir(String name) async {
    final root = await _base();
    final dir = Directory('${root.path}/$name');
    await dir.create(recursive: true);
    return dir;
  }

  /// Absolute file of a completed blob. [blobId] is a 32-byte hex digest.
  Future<File> blobFile(String blobId) async {
    if (!isHexOfLength(blobId, 32)) {
      throw ArgumentError.value(blobId, 'blobId', 'not a 32-byte hex id');
    }
    final dir = await _dir('blobs');
    return File('${dir.path}/$blobId');
  }

  Future<bool> hasBlob(String blobId) async =>
      (await blobFile(blobId)).existsSync();

  /// Copies [source] into the content-addressed store. The first copy wins:
  /// an existing blob is never overwritten by a later, potentially hostile,
  /// transfer with the same id.
  Future<File> importBlob(String blobId, File source) async {
    final target = await blobFile(blobId);
    if (await target.exists()) return target;
    final temp = await _tempFile('blob');
    try {
      final sink = temp.openWrite();
      try {
        await source.openRead().pipe(sink);
      } finally {
        await sink.close();
      }
      if (await target.exists()) {
        await temp.delete();
        return target;
      }
      return await temp.rename(target.path);
    } catch (_) {
      if (await temp.exists()) await temp.delete();
      rethrow;
    }
  }

  /// Writes a stream of bytes as [blobId], atomically and first-copy-wins.
  Future<File> writeBlob(
    String blobId,
    Stream<List<int>> bytes,
  ) async {
    final target = await blobFile(blobId);
    if (await target.exists()) return target;
    final temp = await _tempFile('blob');
    try {
      final sink = temp.openWrite();
      try {
        await bytes.pipe(sink);
      } finally {
        await sink.close();
      }
      if (await target.exists()) {
        await temp.delete();
        return target;
      }
      return await temp.rename(target.path);
    } catch (_) {
      if (await temp.exists()) await temp.delete();
      rethrow;
    }
  }

  /// Reads at most [length] bytes starting at [start]; an empty list when the
  /// slice lies past the end.
  Future<Uint8List> readSlice(
    String blobId,
    int start,
    int length,
  ) async {
    final file = await blobFile(blobId);
    if (!await file.exists() || start < 0 || length <= 0) {
      return Uint8List(0);
    }
    final raf = await file.open();
    try {
      final size = await file.length();
      if (start >= size) return Uint8List(0);
      final count = (start + length > size) ? size - start : length;
      await raf.setPosition(start);
      return await raf.read(count);
    } finally {
      await raf.close();
    }
  }

  Future<void> deleteBlob(String blobId) async {
    try {
      final file = await blobFile(blobId);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // A missing or unreadable blob is already as good as pruned.
    }
  }

  Future<File> _partFile(String transferId, int index) async {
    if (!isHexOfLength(transferId, 32)) {
      throw ArgumentError.value(
        transferId,
        'transferId',
        'not a 32-byte hex id',
      );
    }
    if (index < 0) {
      throw ArgumentError.value(index, 'index', 'must not be negative');
    }
    final root = await _dir('parts');
    final dir = Directory('${root.path}/$transferId');
    await dir.create(recursive: true);
    return File('${dir.path}/$index');
  }

  /// Stores one validated chunk. Returns the relative path saved in the DB.
  Future<String> writePart(
    String transferId,
    int index,
    Uint8List bytes,
  ) async {
    final file = await _partFile(transferId, index);
    await file.writeAsBytes(bytes, flush: true);
    final root = await _base();
    return file.path.substring(root.path.length + 1);
  }

  Future<String?> partPath(String transferId, int index) async {
    final file = await _partFile(transferId, index);
    return (await file.exists()) ? file.path : null;
  }

  Future<Uint8List?> readPart(String transferId, int index) async {
    final file = await _partFile(transferId, index);
    if (!await file.exists()) return null;
    return file.readAsBytes();
  }

  /// Streams every slice into a completed blob, verifies the whole-file digest
  /// and deletes the staging directory. Returns `null` when a slice is
  /// missing or the digest does not match; the caller then keeps the transfer
  /// so the missing slices can be requested again.
  Future<String?> assemble({
    required String transferId,
    required int chunkCount,
    required String blobId,
    required String sha256,
  }) async {
    final target = await blobFile(blobId);
    if (await target.exists()) {
      await deleteTransfer(transferId);
      return blobId;
    }
    final temp = await _tempFile('assemble');
    final sink = Sha256().newHashSink();
    IOSink? out;
    try {
      out = temp.openWrite();
      for (var index = 0; index < chunkCount; index++) {
        final part = await _partFile(transferId, index);
        if (!await part.exists()) {
          await out?.close();
          out = null;
          await temp.delete();
          return null;
        }
        await for (final chunk in part.openRead()) {
          sink.add(chunk);
          out!.add(chunk);
        }
      }
      await out!.flush();
      await out.close();
      out = null;
      sink.close();
      final digest = await sink.hash();
      final hex = digest.bytes
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();
      if (hex != sha256.toLowerCase()) {
        await temp.delete();
        await deleteTransfer(transferId);
        throw const MediaDigestMismatch();
      }
      final saved = await temp.rename(target.path);
      await deleteTransfer(transferId);
      return saved.path;
    } catch (_) {
      await out?.close();
      if (await temp.exists()) await temp.delete();
      rethrow;
    }
  }

  Future<void> deleteTransfer(String transferId) async {
    try {
      final root = await _dir('parts');
      final dir = Directory('${root.path}/$transferId');
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {
      // Already pruned.
    }
  }

  Future<File> _tempFile(String prefix) async {
    final dir = await _dir('tmp');
    return File(
      '${dir.path}/$prefix-${DateTime.now().microsecondsSinceEpoch}-'
      '${identityHashCode(this)}',
    );
  }

  /// The largest single read a slice request materializes.
  static int get sliceBytes => transferChunkBytes;
}

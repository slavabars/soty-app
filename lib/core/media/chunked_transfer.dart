import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart' show Sha256;

import '../crypto/hex.dart' show isHexOfLength;
import '../security_limits.dart';

/// Metadata of a chunked file transfer (roadmap T-80).
///
/// A file travels as one manifest plus [chunkCount] chunks. The manifest is
/// authenticated by the envelope that carries it; every chunk is checked
/// against its own digest, and the assembled bytes against [sha256]. Chunks may
/// arrive out of order and a retry may resend them: the assembler dedupes by
/// index and keeps the first copy.
class ChunkManifest {
  static const String format = 'soty-file-1';

  final String transferId;
  final String blobId;
  final String kind;
  final String mime;
  final int byteCount;
  final int chunkSize;
  final int chunkCount;
  final String sha256;
  final int durationMs;

  const ChunkManifest({
    required this.transferId,
    required this.blobId,
    required this.kind,
    required this.mime,
    required this.byteCount,
    required this.chunkSize,
    required this.chunkCount,
    required this.sha256,
    required this.durationMs,
  });

  Map<String, dynamic> toJson() => {
        'format': format,
        'transferId': transferId,
        'blobId': blobId,
        'kind': kind,
        'mime': mime,
        'byteCount': byteCount,
        'chunkSize': chunkSize,
        'chunkCount': chunkCount,
        'sha256': sha256,
        'durationMs': durationMs,
      };

  String encode() => jsonEncode(toJson());

  factory ChunkManifest.decode(String raw) {
    if (raw.length > 4096) {
      throw const FormatException('file manifest is too large');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      throw const FormatException('file manifest is not JSON');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('file manifest must be an object');
    }
    if (decoded['format'] != format) {
      throw const FormatException('unsupported file manifest');
    }
    final transferId = _hex(decoded, 'transferId');
    final blobId = _hex(decoded, 'blobId');
    final sha256 = _hex(decoded, 'sha256');
    final kind = _string(decoded, 'kind');
    if (kind != 'photo' &&
        kind != 'voice' &&
        kind != 'video' &&
        kind != 'file') {
      throw const FormatException('unknown file kind');
    }
    final mime = _string(decoded, 'mime');
    if (mime.isEmpty || mime.length > maxMediaMimeLength) {
      throw const FormatException('file mime is out of bounds');
    }
    final byteCount = _int(decoded, 'byteCount');
    final chunkSize = _int(decoded, 'chunkSize');
    final chunkCount = _int(decoded, 'chunkCount');
    final durationMs = _int(decoded, 'durationMs');
    if (byteCount <= 0 || byteCount > maxTransferBytes) {
      throw const FormatException('file size is out of bounds');
    }
    if (chunkSize <= 0 || chunkSize > transferChunkBytes) {
      throw const FormatException('chunk size is out of bounds');
    }
    if (chunkCount != (byteCount + chunkSize - 1) ~/ chunkSize ||
        chunkCount > maxTransferChunks) {
      throw const FormatException('chunk count does not match the size');
    }
    return ChunkManifest(
      transferId: transferId,
      blobId: blobId,
      kind: kind,
      mime: mime,
      byteCount: byteCount,
      chunkSize: chunkSize,
      chunkCount: chunkCount,
      sha256: sha256,
      durationMs: durationMs,
    );
  }
}

/// One slice of a transfer. [sha256] is the digest of the raw slice.
class FileChunk {
  final String transferId;
  final int index;
  final String dataBase64;
  final String sha256;

  const FileChunk({
    required this.transferId,
    required this.index,
    required this.dataBase64,
    required this.sha256,
  });

  Map<String, dynamic> toJson() => {
        'transferId': transferId,
        'index': index,
        'data': dataBase64,
        'sha256': sha256,
      };

  String encode() => jsonEncode(toJson());

  factory FileChunk.decode(String raw) {
    if (raw.length > transferChunkBytes * 2) {
      throw const FormatException('file chunk is too large');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      throw const FormatException('file chunk is not JSON');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('file chunk must be an object');
    }
    final transferId = _hex(decoded, 'transferId');
    final index = _int(decoded, 'index');
    final data = _string(decoded, 'data');
    final sha256 = _hex(decoded, 'sha256');
    if (index < 0 || index >= maxTransferChunks) {
      throw const FormatException('chunk index is out of bounds');
    }
    if (base64Decode(data).length > transferChunkBytes) {
      throw const FormatException('chunk payload is too large');
    }
    return FileChunk(
      transferId: transferId,
      index: index,
      dataBase64: data,
      sha256: sha256,
    );
  }
}

/// Reassembles a file from chunks, rejecting duplicates, tampering and
/// missing/extra slices. Supports out-of-order arrival and a resume: feeding
/// the same chunks again after a restart continues from what is present.
class ChunkAssembler {
  final ChunkManifest manifest;
  final Map<int, Uint8List> _chunks = {};
  int _receivedBytes = 0;

  ChunkAssembler(this.manifest);

  int get receivedBytes => _receivedBytes;
  int get receivedChunks => _chunks.length;
  double get progress => _receivedBytes / manifest.byteCount;
  bool get isComplete =>
      _chunks.length == manifest.chunkCount &&
      _receivedBytes == manifest.byteCount;

  /// Adds one chunk. Returns false for a duplicate that was already stored.
  /// Throws [FormatException] for a chunk that belongs to another transfer,
  /// has a wrong index/size or fails its digest.
  Future<bool> add(FileChunk chunk) async {
    if (chunk.transferId != manifest.transferId) {
      throw const FormatException('chunk belongs to another transfer');
    }
    if (chunk.index >= manifest.chunkCount) {
      throw const FormatException('chunk index outside the manifest');
    }
    if (_chunks.containsKey(chunk.index)) return false;
    final data = base64Decode(chunk.dataBase64);
    final expected = _expectedLength(chunk.index);
    if (data.length != expected) {
      throw const FormatException('chunk length does not match the manifest');
    }
    final digest = await Sha256().hash(data);
    final actual = digest.bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    if (actual != chunk.sha256) {
      throw const FormatException('chunk digest mismatch');
    }
    if (_receivedBytes + data.length > manifest.byteCount) {
      throw const FormatException('chunks exceed the declared size');
    }
    _chunks[chunk.index] = data;
    _receivedBytes += data.length;
    return true;
  }

  /// Assembles the file once every chunk is present; `null` while incomplete.
  /// Verifies the whole-file digest before returning.
  Future<Uint8List?> assemble() async {
    if (!isComplete) return null;
    final out = Uint8List(manifest.byteCount);
    var offset = 0;
    for (var i = 0; i < manifest.chunkCount; i++) {
      final data = _chunks[i];
      if (data == null) return null;
      out.setAll(offset, data);
      offset += data.length;
    }
    final digest = await Sha256().hash(out);
    final actual = digest.bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    if (actual != manifest.sha256) {
      throw const FormatException('file digest mismatch');
    }
    return out;
  }

  int _expectedLength(int index) {
    final start = index * manifest.chunkSize;
    final remaining = manifest.byteCount - start;
    return remaining < manifest.chunkSize ? remaining : manifest.chunkSize;
  }
}

/// Splits [bytes] into a manifest and chunks, sending each slice's digest.
Future<({ChunkManifest manifest, List<FileChunk> chunks})> splitFile({
  required Uint8List bytes,
  required String transferId,
  required String blobId,
  required String kind,
  required String mime,
  int durationMs = 0,
  int maxBytes = maxTransferBytes,
}) async {
  if (bytes.isEmpty || bytes.length > maxBytes) {
    throw const FormatException('file size is out of bounds');
  }
  final digest = await Sha256().hash(bytes);
  final sha = digest.bytes
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join();
  final chunkCount = (bytes.length + transferChunkBytes - 1) ~/
      transferChunkBytes;
  final manifest = ChunkManifest(
    transferId: transferId,
    blobId: blobId,
    kind: kind,
    mime: mime,
    byteCount: bytes.length,
    chunkSize: transferChunkBytes,
    chunkCount: chunkCount,
    sha256: sha,
    durationMs: durationMs,
  );
  final chunks = <FileChunk>[];
  for (var i = 0; i < chunkCount; i++) {
    final start = i * transferChunkBytes;
    final end = (start + transferChunkBytes) < bytes.length
        ? start + transferChunkBytes
        : bytes.length;
    final slice = Uint8List.sublistView(bytes, start, end);
    final chunkDigest = await Sha256().hash(slice);
    chunks.add(
      FileChunk(
        transferId: transferId,
        index: i,
        dataBase64: base64Encode(slice),
        sha256: chunkDigest.bytes
            .map((b) => b.toRadixString(16).padLeft(2, '0'))
            .join(),
      ),
    );
  }
  return (manifest: manifest, chunks: chunks);
}

String _string(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is! String) throw FormatException('$key must be a string');
  return value;
}

int _int(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is! int) throw FormatException('$key must be an integer');
  return value;
}

String _hex(Map<String, dynamic> map, String key) {
  final value = _string(map, key);
  if (!isHexOfLength(value, 32)) {
    throw FormatException('$key must be a 32-byte hex string');
  }
  return value.toLowerCase();
}

/// Cancels an in-flight send between two chunks. The chunks already handed to
/// the processor stay queued; the receiver keeps the slices it validated, so a
/// later re-send of the same transfer resumes instead of starting over.
class TransferCancel {
  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  void cancel() => _cancelled = true;
}

/// Thrown by the sender when [TransferCancel] was tripped.
class TransferCancelled implements Exception {
  const TransferCancelled();

  @override
  String toString() => 'transfer cancelled';
}

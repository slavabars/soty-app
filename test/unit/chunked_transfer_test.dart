import 'dart:convert';
import 'dart:typed_data';

import 'package:dtm_app/core/media/chunked_transfer.dart';
import 'package:dtm_app/core/security_limits.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List pattern(int length) =>
    Uint8List.fromList(List<int>.generate(length, (i) => (i * 7) % 251));

Future<({ChunkManifest manifest, List<FileChunk> chunks})> sample(
  int length,
) {
  return splitFile(
    bytes: pattern(length),
    transferId: '11' * 32,
    blobId: '22' * 32,
    kind: 'video',
    mime: 'video/mp4',
    durationMs: 1500,
  );
}

void main() {
  test('a file round-trips through manifest and chunks', () async {
    final parts = await sample(200 * 1024);
    expect(parts.manifest.chunkCount, greaterThan(1));
    expect(parts.manifest.byteCount, 200 * 1024);
    expect(parts.manifest.kind, 'video');

    final decoded = ChunkManifest.decode(parts.manifest.encode());
    expect(decoded.sha256, parts.manifest.sha256);

    final assembler = ChunkAssembler(decoded);
    for (final chunk in parts.chunks.reversed) {
      await assembler.add(FileChunk.decode(chunk.encode()));
    }
    final assembled = await assembler.assemble();
    expect(assembled, isNotNull);
    expect(assembled, pattern(200 * 1024));
    expect(assembler.progress, 1.0);
  });

  test('duplicate chunks are ignored and do not inflate progress', () async {
    final parts = await sample(3000);
    final assembler = ChunkAssembler(parts.manifest);
    expect(await assembler.add(parts.chunks.first), isTrue);
    expect(await assembler.add(parts.chunks.first), isFalse);
    expect(assembler.receivedChunks, 1);
    expect(assembler.receivedBytes, 3000 < transferChunkBytes ? 3000 : 3000);
  });

  test('a tampered chunk digest is rejected', () async {
    final parts = await sample(5000);
    final chunk = parts.chunks.first;
    final tampered = FileChunk(
      transferId: chunk.transferId,
      index: chunk.index,
      dataBase64: base64Encode(List<int>.filled(5000, 0)),
      sha256: chunk.sha256,
    );
    await expectLater(
      ChunkAssembler(parts.manifest).add(tampered),
      throwsFormatException,
    );
  });

  test('a file digest mismatch is refused at assemble time', () async {
    final bytes = pattern(1000);
    final parts = await splitFile(
      bytes: bytes,
      transferId: '33' * 32,
      blobId: '44' * 32,
      kind: 'file',
      mime: 'application/octet-stream',
    );
    final assembler = ChunkAssembler(parts.manifest);
    for (final chunk in parts.chunks) {
      await assembler.add(chunk);
    }
    // The declared whole-file hash does not match the bytes that arrived.
    final bogus = ChunkManifest(
      transferId: parts.manifest.transferId,
      blobId: parts.manifest.blobId,
      kind: parts.manifest.kind,
      mime: parts.manifest.mime,
      byteCount: parts.manifest.byteCount,
      chunkSize: parts.manifest.chunkSize,
      chunkCount: parts.manifest.chunkCount,
      sha256: 'ff' * 32,
      durationMs: 0,
    );
    final other = ChunkAssembler(bogus);
    for (final chunk in parts.chunks) {
      await other.add(chunk);
    }
    await expectLater(other.assemble(), throwsFormatException);
  });

  test('a chunk from another transfer or with a bad index is rejected',
      () async {
    final parts = await sample(4000);
    final assembler = ChunkAssembler(parts.manifest);
    final foreign = FileChunk(
      transferId: '55' * 32,
      index: 0,
      dataBase64: parts.chunks.first.dataBase64,
      sha256: parts.chunks.first.sha256,
    );
    await expectLater(assembler.add(foreign), throwsFormatException);

    final outOfRange = FileChunk(
      transferId: parts.manifest.transferId,
      index: parts.manifest.chunkCount,
      dataBase64: parts.chunks.first.dataBase64,
      sha256: parts.chunks.first.sha256,
    );
    await expectLater(assembler.add(outOfRange), throwsFormatException);
  });

  test('an incomplete transfer does not assemble', () async {
    final parts = await sample(200 * 1024);
    final assembler = ChunkAssembler(parts.manifest);
    await assembler.add(parts.chunks.first);
    expect(assembler.isComplete, isFalse);
    expect(await assembler.assemble(), isNull);
  });

  test('a fresh assembler resumes from the manifest and stored chunks',
      () async {
    final parts = await sample(300 * 1024);
    final first = ChunkAssembler(parts.manifest);
    for (final chunk in parts.chunks.take(2)) {
      await first.add(chunk);
    }
    expect(first.isComplete, isFalse);

    final resumed = ChunkAssembler(parts.manifest);
    for (final chunk in parts.chunks.take(2)) {
      await resumed.add(chunk);
    }
    for (final chunk in parts.chunks.skip(2)) {
      await resumed.add(chunk);
    }
    expect(await resumed.assemble(), pattern(300 * 1024));
  });

  test('sizes and chunk metadata are bounded', () async {
    expect(
      () => splitFile(
        bytes: Uint8List(2048),
        transferId: '66' * 32,
        blobId: '77' * 32,
        kind: 'file',
        mime: 'application/octet-stream',
        maxBytes: 1024,
      ),
      throwsFormatException,
    );

    final tooBig = {
      'format': ChunkManifest.format,
      'transferId': '66' * 32,
      'blobId': '77' * 32,
      'kind': 'file',
      'mime': 'application/octet-stream',
      'byteCount': maxTransferBytes + 1,
      'chunkSize': transferChunkBytes,
      'chunkCount': maxTransferChunks + 1,
      'sha256': '88' * 32,
      'durationMs': 0,
    };
    expect(
      () => ChunkManifest.decode(jsonEncode(tooBig)),
      throwsFormatException,
    );

    final badCount = Map<String, dynamic>.from(tooBig)
      ..['byteCount'] = 1000
      ..['chunkCount'] = 3;
    expect(
      () => ChunkManifest.decode(jsonEncode(badCount)),
      throwsFormatException,
    );
  });

  test('the chunk ceiling covers large files in 64 KiB slices', () {
    expect(maxTransferBytes, 2 * 1024 * 1024 * 1024);
    expect(transferChunkBytes, 64 * 1024);
    expect(
      maxTransferChunks,
      (2 * 1024 * 1024 * 1024 + 64 * 1024 - 1) ~/ (64 * 1024),
    );
  });
}

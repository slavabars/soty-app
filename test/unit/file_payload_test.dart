import 'dart:convert';

import 'package:dtm_app/core/media/chunked_transfer.dart';
import 'package:dtm_app/core/security_limits.dart'
    show maxTransferBytes, maxTransferChunks, transferChunkBytes;
import 'package:dtm_app/models/message_payload.dart';
import 'package:flutter_test/flutter_test.dart';

ChunkManifest manifest({int byteCount = 200000, int chunkCount = 0}) =>
    ChunkManifest(
      transferId: '11' * 32,
      blobId: '22' * 32,
      kind: 'video',
      mime: 'video/mp4',
      byteCount: byteCount,
      chunkSize: transferChunkBytes,
      chunkCount: chunkCount == 0
          ? (byteCount + transferChunkBytes - 1) ~/ transferChunkBytes
          : chunkCount,
      sha256: '33' * 32,
      durationMs: 7000,
    );

void main() {
  test('a direct file manifest round-trips', () {
    final raw = MessagePayload.composeFileManifestDirect(
      senderX: '44' * 32,
      manifest: manifest(),
      quote: QuoteRef(
        refId: '55' * 32,
        authorX: '66' * 32,
        preview: 'смотрите',
      ),
    );
    final parsed = MessagePayload.parse(raw);
    expect(parsed, isA<FileManifestPayload>());
    final payload = parsed as FileManifestPayload;
    expect(payload.senderX, '44' * 32);
    expect(payload.conversationId, '');
    expect(payload.kind, MediaKind.video);
    expect(payload.manifest.blobId, '22' * 32);
    expect(payload.manifest.byteCount, 200000);
    expect(payload.manifest.chunkCount, manifest().chunkCount);
    expect(payload.manifest.sha256, '33' * 32);
    expect(payload.quote!.preview, 'смотрите');
  });

  test('a group file manifest keeps its conversation and correlation id', () {
    final raw = MessagePayload.composeFileManifestGroup(
      conversationId: '77' * 32,
      corrId: '88' * 32,
      senderX: '44' * 32,
      manifest: manifest(),
    );
    final payload = MessagePayload.parse(raw) as FileManifestPayload;
    expect(payload.conversationId, '77' * 32);
    expect(payload.corrId, '88' * 32);
    expect(payload.quote, isNull);
  });

  test('a chunk round-trips in both variants', () {
    final chunk = FileChunk(
      transferId: '11' * 32,
      index: 3,
      dataBase64: base64Encode(List<int>.filled(1024, 7)),
      sha256: '99' * 32,
    );
    final direct = MessagePayload.parse(
      MessagePayload.composeFileChunkDirect(
        senderX: '44' * 32,
        chunk: chunk,
      ),
    );
    expect(direct, isA<FileChunkPayload>());
    expect((direct as FileChunkPayload).chunk.index, 3);
    expect(direct.chunk.dataBase64, chunk.dataBase64);

    final group = MessagePayload.parse(
      MessagePayload.composeFileChunkGroup(
        conversationId: '77' * 32,
        senderX: '44' * 32,
        chunk: chunk,
      ),
    );
    expect(group, isA<FileChunkPayload>());
    expect((group as FileChunkPayload).conversationId, '77' * 32);
  });

  test('a manifest over the transfer cap degrades to text', () {
    final over = manifest(byteCount: maxTransferBytes + 1);
    final raw = MessagePayload.composeFileManifestDirect(
      senderX: '44' * 32,
      manifest: over,
    );
    expect(MessagePayload.parse(raw), isA<DroppedPayload>());
  });

  test('a manifest with an inconsistent chunk count degrades to text', () {
    final bad = manifest(byteCount: 200000, chunkCount: 2);
    final raw = MessagePayload.composeFileManifestDirect(
      senderX: '44' * 32,
      manifest: bad,
    );
    expect(MessagePayload.parse(raw), isA<DroppedPayload>());
  });

  test('a manifest with a foreign mime degrades to text', () {
    final bad = ChunkManifest(
      transferId: '11' * 32,
      blobId: '22' * 32,
      kind: 'video',
      mime: 'image/png',
      byteCount: 1000,
      chunkSize: transferChunkBytes,
      chunkCount: 1,
      sha256: '33' * 32,
      durationMs: 0,
    );
    final raw = MessagePayload.composeFileManifestDirect(
      senderX: '44' * 32,
      manifest: bad,
    );
    expect(MessagePayload.parse(raw), isA<DroppedPayload>());
  });

  test('a long registered mime such as docx still parses', () {
    final docx = ChunkManifest(
      transferId: '11' * 32,
      blobId: '22' * 32,
      kind: 'file',
      mime: 'application/vnd.openxmlformats-officedocument.'
          'wordprocessingml.document',
      byteCount: 744617,
      chunkSize: transferChunkBytes,
      chunkCount: 12,
      sha256: '33' * 32,
      durationMs: 0,
    );
    final raw = MessagePayload.composeFileManifestDirect(
      senderX: '44' * 32,
      manifest: docx,
    );
    final parsed = MessagePayload.parse(raw);
    expect(parsed, isA<FileManifestPayload>());
    expect((parsed as FileManifestPayload).manifest.mime, docx.mime);
  });

  test('an oversized or malformed chunk degrades to text', () {
    final tooBig = FileChunk(
      transferId: '11' * 32,
      index: 0,
      dataBase64: base64Encode(List<int>.filled(transferChunkBytes + 1, 1)),
      sha256: '99' * 32,
    );
    expect(
      MessagePayload.parse(
        MessagePayload.composeFileChunkDirect(
          senderX: '44' * 32,
          chunk: tooBig,
        ),
      ),
      isA<DroppedPayload>(),
    );

    final outOfRange = FileChunk(
      transferId: '11' * 32,
      index: maxTransferChunks,
      dataBase64: base64Encode(const [1, 2, 3]),
      sha256: '99' * 32,
    );
    expect(
      MessagePayload.parse(
        MessagePayload.composeFileChunkDirect(
          senderX: '44' * 32,
          chunk: outOfRange,
        ),
      ),
      isA<DroppedPayload>(),
    );
  });
}

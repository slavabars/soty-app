import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart' show Sha256;
import 'package:dtm_app/core/media/media_store.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List block(int seed, int length) => Uint8List.fromList(
      List<int>.generate(length, (i) => (i * 31 + seed) % 251),
    );

String hex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

void main() {
  late Directory dir;
  late MediaStore store;
  final transferId = 'aa' * 32;
  final blobId = 'bb' * 32;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('soty_media_store');
    MediaStore.overrideRoot = dir;
    store = MediaStore();
  });

  tearDown(() async {
    MediaStore.overrideRoot = null;
    await dir.delete(recursive: true);
  });

  test('assembles slice files in index order without base64', () async {
    final chunks = [block(1, 70000), block(2, 70000), block(3, 1000)];
    final all = <int>[for (final c in chunks) ...c];
    final digest = hex((await Sha256().hash(all)).bytes);
    for (var i = 0; i < chunks.length; i++) {
      await store.writePart(transferId, i, chunks[i]);
    }

    final path = await store.assemble(
      transferId: transferId,
      chunkCount: chunks.length,
      blobId: blobId,
      sha256: digest,
    );

    expect(path, isNotNull);
    final file = await store.blobFile(blobId);
    expect(await file.readAsBytes(), all);
    expect(await store.readPart(transferId, 0), isNull);
  });

  test('a missing slice keeps the transfer and returns null', () async {
    await store.writePart(transferId, 0, block(1, 100));

    final path = await store.assemble(
      transferId: transferId,
      chunkCount: 2,
      blobId: blobId,
      sha256: 'cc' * 32,
    );

    expect(path, isNull);
    expect(await store.readPart(transferId, 0), isNotNull);
  });

  test('a wrong digest deletes the assembled temp file', () async {
    await store.writePart(transferId, 0, block(1, 100));

    await expectLater(
      store.assemble(
        transferId: transferId,
        chunkCount: 1,
        blobId: blobId,
        sha256: 'cc' * 32,
      ),
      throwsA(isA<MediaDigestMismatch>()),
    );

    expect((await store.blobFile(blobId)).existsSync(), isFalse);
  });

  test('reads a slice from a finished blob', () async {
    final bytes = block(7, 200000);
    final digest = hex((await Sha256().hash(bytes)).bytes);
    await store.writeBlob(blobId, Stream.value(bytes));
    expect(await store.hasBlob(blobId), isTrue);

    final slice = await store.readSlice(blobId, 65536, 1000);
    expect(slice, bytes.sublist(65536, 66536));
    expect((await store.readSlice(blobId, 200000, 10)), isEmpty);
    expect(digest, hasLength(64));
  });
}

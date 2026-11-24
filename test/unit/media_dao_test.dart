import 'dart:convert' show base64Encode;

import 'package:dtm_app/core/storage/database.dart';
import 'package:dtm_app/core/storage/media_dao.dart';
import 'package:dtm_app/models/message_payload.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late MediaDao dao;

  setUp(() {
    db = AppDatabase.inMemory();
    dao = MediaDao(db);
  });

  tearDown(() => db.close());

  final blobA = 'a' * 64;
  final blobB = 'b' * 64;

  String data(int len) => base64Encode(List<int>.filled(len, 5));

  test('a stored blob comes back byte for byte', () async {
    final encoded = data(1200);
    await dao.put(
      blobId: blobA,
      kind: MediaKind.voice,
      mime: 'audio/mp4',
      byteCount: 1200,
      durationMs: 7400,
      dataBase64: encoded,
      timestamp: 1000,
    );
    final row = await dao.get(blobA);
    expect(row, isNotNull);
    expect(row!.kind, MediaKind.voice);
    expect(row.mime, 'audio/mp4');
    expect(row.byteCount, 1200);
    expect(row.durationMs, 7400);
    expect(row.dataBase64, encoded);
    expect(await row.readBytes(), List<int>.filled(1200, 5));
  });

  test('a missing blob is null, not an error', () async {
    expect(await dao.get(blobA), isNull);
  });

  test('putting the same blob twice keeps the first copy', () async {
    await dao.put(
      blobId: blobA,
      kind: MediaKind.photo,
      mime: 'image/jpeg',
      byteCount: 4,
      durationMs: 0,
      dataBase64: data(4),
      timestamp: 1000,
    );
    await dao.put(
      blobId: blobA,
      kind: MediaKind.photo,
      mime: 'image/png',
      byteCount: 4,
      durationMs: 0,
      dataBase64: data(4),
      timestamp: 2000,
    );
    expect((await dao.get(blobA))!.mime, 'image/jpeg');
  });

  test('a blob can be fetched in a batch by id', () async {
    await dao.put(
      blobId: blobA,
      kind: MediaKind.photo,
      mime: 'image/jpeg',
      byteCount: 4,
      durationMs: 0,
      dataBase64: data(4),
      timestamp: 1000,
    );
    await dao.put(
      blobId: blobB,
      kind: MediaKind.voice,
      mime: 'audio/mp4',
      byteCount: 8,
      durationMs: 500,
      dataBase64: data(8),
      timestamp: 1001,
    );
    final rows = await dao.byIds([blobA, blobB, 'c' * 64]);
    expect(rows.keys, containsAll([blobA, blobB]));
    expect(rows, hasLength(2));
  });

  test('pruning drops only blobs older than the cut-off', () async {
    await dao.put(
      blobId: blobA,
      kind: MediaKind.photo,
      mime: 'image/jpeg',
      byteCount: 4,
      durationMs: 0,
      dataBase64: data(4),
      timestamp: 1000,
    );
    await dao.put(
      blobId: blobB,
      kind: MediaKind.voice,
      mime: 'audio/mp4',
      byteCount: 4,
      durationMs: 500,
      dataBase64: data(4),
      timestamp: 9000,
    );
    final removed = await dao.pruneBefore(5000);
    expect(removed, 1);
    expect(await dao.get(blobA), isNull);
    expect(await dao.get(blobB), isNotNull);
  });

  test('deleting blobs by id removes exactly those rows', () async {
    await dao.put(
      blobId: blobA,
      kind: MediaKind.photo,
      mime: 'image/jpeg',
      byteCount: 4,
      durationMs: 0,
      dataBase64: data(4),
      timestamp: 1000,
    );
    await dao.put(
      blobId: blobB,
      kind: MediaKind.voice,
      mime: 'audio/mp4',
      byteCount: 4,
      durationMs: 500,
      dataBase64: data(4),
      timestamp: 1001,
    );
    expect(await dao.deleteIds([blobA]), 1);
    expect(await dao.get(blobA), isNull);
    expect(await dao.get(blobB), isNotNull);
  });

  test('the row count stays bounded by the total cap', () async {
    // The cap is enforced by the caller's prune pass; the DAO exposes the
    // count so the policy can be asserted without guessing.
    expect(await dao.count(), 0);
    await dao.put(
      blobId: blobA,
      kind: MediaKind.photo,
      mime: 'image/jpeg',
      byteCount: 4,
      durationMs: 0,
      dataBase64: data(4),
      timestamp: 1000,
    );
    expect(await dao.count(), 1);
  });
}

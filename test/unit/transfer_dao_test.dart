import 'dart:io';
import 'dart:typed_data';

import 'package:dtm_app/core/media/media_store.dart';
import 'package:dtm_app/core/storage/database.dart';
import 'package:dtm_app/core/storage/transfer_dao.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;
  late AppDatabase db;
  late MediaStore store;
  final transferId = 'aa' * 32;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('soty_transfer_dao');
    MediaStore.overrideRoot = dir;
    store = MediaStore();
    db = AppDatabase.inMemory();
  });

  tearDown(() async {
    MediaStore.overrideRoot = null;
    await db.close();
    if (dir.existsSync()) await dir.delete(recursive: true);
  });

  test('putPart stores a slice on a database upgraded from v18', () async {
    // A v18 database already had transfer_parts, so adding the `path` column
    // in v19 left the legacy `data` column NOT NULL *without* a DEFAULT. A
    // Drift insert that relies on the default then violates NOT NULL, and
    // insertOrIgnore swallows it: the slice file is written but the row is
    // lost, so progress stays at zero forever.
    await db.customStatement(
      'ALTER TABLE transfer_parts RENAME TO transfer_parts_fresh',
    );
    await db.customStatement('''
      CREATE TABLE transfer_parts (
        transfer_id TEXT NOT NULL,
        "index" INTEGER NOT NULL,
        byte_count INTEGER NOT NULL,
        data TEXT NOT NULL,
        path TEXT NOT NULL DEFAULT '',
        PRIMARY KEY (transfer_id, "index")
      )
    ''');
    await db.customStatement('DROP TABLE transfer_parts_fresh');

    final dao = TransferDao(db, store: store);
    final bytes = Uint8List.fromList(List<int>.generate(32, (i) => i));
    final inserted = await dao.putPart(
      transferId: transferId,
      index: 0,
      byteCount: bytes.length,
      bytes: bytes,
    );

    expect(inserted, isTrue);
    expect(await dao.partCount(transferId), 1);
  });
}

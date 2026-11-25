import 'dart:io';

import 'package:dtm_app/core/storage/identity_reset.dart';
import 'package:dtm_app/core/storage/secure_identity_store.dart';
import 'package:flutter_test/flutter_test.dart';

class _Store implements SecureIdentityStore {
  int cleared = 0;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<SecureSeeds?> read() async => null;

  @override
  Future<void> write(SecureSeeds seeds) async {}

  @override
  Future<void> clear() async => cleared++;
}

void main() {
  late Directory dir;
  late _Store store;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('soty_reset');
    store = _Store();
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  test('deletes the database, its journals, media and the seed blob', () async {
    for (final name in ['dtm.sqlite', 'dtm.sqlite-wal', 'dtm.sqlite-shm']) {
      await File('${dir.path}/$name').writeAsString('x');
    }
    final media = Directory('${dir.path}/media/nested')..createSync(recursive: true);
    await File('${media.path}/blob.bin').writeAsString('x');
    await File('${dir.path}/unrelated.txt').writeAsString('keep');

    await eraseLocalIdentityData(support: dir, secure: store);

    expect(await File('${dir.path}/dtm.sqlite').exists(), isFalse);
    expect(await File('${dir.path}/dtm.sqlite-wal').exists(), isFalse);
    expect(await File('${dir.path}/dtm.sqlite-shm').exists(), isFalse);
    expect(await Directory('${dir.path}/media').exists(), isFalse);
    expect(store.cleared, 1);
    // Files the app does not own are left alone.
    expect(await File('${dir.path}/unrelated.txt').exists(), isTrue);
  });

  test('is safe to run when nothing was ever written', () async {
    await eraseLocalIdentityData(support: dir, secure: store);
    expect(store.cleared, 1);
  });
}

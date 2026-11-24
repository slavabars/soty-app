import 'package:dtm_app/core/storage/database.dart';
import 'package:dtm_app/core/storage/settings_dao.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late SettingsDao dao;

  setUp(() {
    db = AppDatabase.inMemory();
    dao = SettingsDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('missing keys read as null', () async {
    expect(await dao.get('nope'), isNull);
  });

  test('set then get round-trips a value', () async {
    await dao.set('app_lock_biometric', '1');
    expect(await dao.get('app_lock_biometric'), '1');
  });

  test('set overwrites an existing value', () async {
    await dao.set('k', 'v1');
    await dao.set('k', 'v2');
    expect(await dao.get('k'), 'v2');
  });

  test('remove deletes a key and keeps others', () async {
    await dao.set('a', '1');
    await dao.set('b', '2');
    await dao.remove('a');
    expect(await dao.get('a'), isNull);
    expect(await dao.get('b'), '2');
  });
}
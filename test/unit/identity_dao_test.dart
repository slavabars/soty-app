import 'package:drift/drift.dart' show Value;
import 'package:dtm_app/core/crypto/keypair.dart';
import 'package:dtm_app/core/storage/database.dart';
import 'package:dtm_app/core/storage/identity_dao.dart';
import 'package:dtm_app/core/storage/secure_identity_store.dart';
import 'package:flutter_test/flutter_test.dart';

/// In-memory stand-in for the platform keystore.
class _FakeStore implements SecureIdentityStore {
  bool available = true;
  bool failWrites = false;
  SecureSeeds? seeds;
  int writes = 0;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<SecureSeeds?> read() async => seeds;

  @override
  Future<void> write(SecureSeeds value) async {
    if (!available) throw StateError('unavailable');
    if (failWrites) throw StateError('write failed');
    writes++;
    seeds = value;
  }

  @override
  Future<void> clear() async => seeds = null;
}

void main() {
  late AppDatabase db;
  late _FakeStore store;
  late IdentityDao dao;

  setUp(() {
    db = AppDatabase.inMemory();
    store = _FakeStore();
    dao = IdentityDao(db, secureStore: store);
  });

  tearDown(() async {
    await db.close();
  });

  test('load returns null before any identity is stored', () async {
    expect(await dao.load(), isNull);
  });

  test('save then load round-trips the seeds and name', () async {
    final keyPair = await DtmKeyPair.generate();
    await dao.save(keyPair, displayName: 'Alice');

    final loaded = await dao.load();
    expect(loaded, isNotNull);
    expect(loaded!.displayName, 'Alice');
    expect(await loaded.keyPair.ed25519SeedHex, await keyPair.ed25519SeedHex);
    expect(await loaded.keyPair.x25519SeedHex, await keyPair.x25519SeedHex);
    expect(
      await loaded.keyPair.x25519PublicKeyHex,
      await keyPair.x25519PublicKeyHex,
    );
    expect(loaded.createdAt, greaterThan(0));
  });

  test('a second save replaces the previous identity', () async {
    final first = await DtmKeyPair.generate();
    final second = await DtmKeyPair.generate();

    await dao.save(first, displayName: 'First');
    await dao.save(second, displayName: 'Second');

    final rows = await db.select(db.identityEntry).get();
    expect(rows, hasLength(1));
    final loaded = await dao.load();
    expect(loaded!.displayName, 'Second');
    expect(await loaded.keyPair.ed25519SeedHex, await second.ed25519SeedHex);
  });

  test('an identity with no display name keeps an empty name', () async {
    await dao.save(await DtmKeyPair.generate());
    expect((await dao.load())!.displayName, '');
  });

  test('save keeps the seeds out of the database when a store exists',
      () async {
    final keyPair = await DtmKeyPair.generate();
    await dao.save(keyPair);

    final row = await db.select(db.identityEntry).getSingle();
    expect(row.edSeedHex, isEmpty);
    expect(row.xSeedHex, isEmpty);
    expect(store.seeds, isNotNull);
    expect(store.seeds!.edSeedHex, await keyPair.ed25519SeedHex);

    final loaded = await dao.load();
    expect(
      await loaded!.keyPair.ed25519SeedHex,
      await keyPair.ed25519SeedHex,
    );
  });

  test('without a platform store the seeds stay in the row', () async {
    store.available = false;
    final keyPair = await DtmKeyPair.generate();
    await dao.save(keyPair);

    final row = await db.select(db.identityEntry).getSingle();
    expect(row.edSeedHex, await keyPair.ed25519SeedHex);
    expect(row.xSeedHex, await keyPair.x25519SeedHex);
    expect(store.seeds, isNull);
    expect(await dao.load(), isNotNull);
  });

  test('load migrates a database-only identity into the store', () async {
    store.available = false;
    final keyPair = await DtmKeyPair.generate();
    await dao.save(keyPair, displayName: 'Legacy');
    store.available = true;
    store.failWrites = false;

    final loaded = await dao.load();
    expect(loaded!.displayName, 'Legacy');
    expect(await loaded.keyPair.ed25519SeedHex, await keyPair.ed25519SeedHex);
    expect(store.seeds!.edSeedHex, await keyPair.ed25519SeedHex);

    final row = await db.select(db.identityEntry).getSingle();
    expect(row.edSeedHex, isEmpty);
    expect(row.xSeedHex, isEmpty);
  });

  test('a failed store write keeps the database copy', () async {
    store.failWrites = true;
    final keyPair = await DtmKeyPair.generate();
    await dao.save(keyPair);

    final row = await db.select(db.identityEntry).getSingle();
    expect(row.edSeedHex, await keyPair.ed25519SeedHex);
    expect(row.xSeedHex, await keyPair.x25519SeedHex);
    expect(
      await (await dao.load())!.keyPair.ed25519SeedHex,
      await keyPair.ed25519SeedHex,
    );
  });

  test('a row without seeds and an empty store fails loudly', () async {
    await db.into(db.identityEntry).insert(
      IdentityEntryCompanion.insert(
        key: const Value('self'),
        edSeedHex: '',
        xSeedHex: '',
        createdAt: 1,
      ),
    );

    await expectLater(
      dao.load(),
      throwsA(isA<IdentityUnavailableException>()),
    );
  });

  test('a malformed seed in the row is rejected', () async {
    await db.into(db.identityEntry).insert(
      IdentityEntryCompanion.insert(
        key: const Value('self'),
        edSeedHex: 'zz',
        xSeedHex: 'zz',
        createdAt: 1,
      ),
    );

    await expectLater(dao.load(), throwsFormatException);
  });
}

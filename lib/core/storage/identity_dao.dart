import 'package:drift/drift.dart';

import '../crypto/hex.dart' show isHexOfLength;
import '../crypto/keypair.dart';
import 'database.dart';
import 'secure_identity_store.dart';

/// Stored identity record.
class StoredIdentity {
  final DtmKeyPair keyPair;
  final String displayName;
  final int createdAt;

  const StoredIdentity({
    required this.keyPair,
    required this.displayName,
    required this.createdAt,
  });
}

/// Persists the local identity (Ed25519 + X25519 seeds). Never synced.
///
/// Seeds live in the platform keystore whenever one exists, and the row then
/// keeps only public metadata. A row written by an older version still carries
/// the seeds: it is migrated on the first [load] and wiped afterwards. Without
/// a keystore (desktop, tests) the seeds stay in the row so no install can
/// lose its identity to a platform gap.
class IdentityDao extends DatabaseAccessor<AppDatabase> {
  final SecureIdentityStore _secure;

  IdentityDao(super.db, {SecureIdentityStore? secureStore})
    : _secure = secureStore ?? PlatformSecureIdentityStore();

  /// Whether a row exists, without touching the seeds (a restore decision
  /// must not fail on a row the keystore cannot satisfy yet).
  Future<bool> hasIdentity() async {
    final row = await (select(
      db.identityEntry,
    )..where((i) => i.key.equals('self'))).getSingleOrNull();
    return row != null;
  }

  Future<StoredIdentity?> load() async {
    final row = await (select(
      db.identityEntry,
    )..where((i) => i.key.equals('self'))).getSingleOrNull();
    if (row == null) return null;
    final seeds = await _seedsFor(row);
    final keyPair = await DtmKeyPair.fromSeeds(
      ed25519SeedHex: seeds.edSeedHex,
      x25519SeedHex: seeds.xSeedHex,
    );
    return StoredIdentity(
      keyPair: keyPair,
      displayName: row.displayName,
      createdAt: row.createdAt,
    );
  }

  Future<void> save(DtmKeyPair keyPair, {String displayName = ''}) async {
    final seeds = SecureSeeds(
      edSeedHex: await keyPair.ed25519SeedHex,
      xSeedHex: await keyPair.x25519SeedHex,
    );
    final inStore = await _writeToStore(seeds);
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await into(db.identityEntry).insert(
      IdentityEntryCompanion.insert(
        key: const Value('self'),
        edSeedHex: inStore ? '' : seeds.edSeedHex,
        xSeedHex: inStore ? '' : seeds.xSeedHex,
        displayName: Value(displayName),
        createdAt: now,
      ),
      mode: InsertMode.insertOrReplace,
    );
  }

  /// A row without seeds and an empty keystore means the identity cannot be
  /// reconstructed. Failing loudly is the only safe answer: generating a new
  /// identity here would silently break every existing conversation.
  Future<SecureSeeds> _seedsFor(IdentityEntryData row) async {
    final stored = await _secure.read();
    if (stored != null) return stored;
    final ed = row.edSeedHex;
    final x = row.xSeedHex;
    if (ed.isEmpty && x.isEmpty) {
      throw StateError('identity row has no seeds and no keystore copy');
    }
    if (!isHexOfLength(ed, 32) || !isHexOfLength(x, 32)) {
      throw const FormatException('identity row: malformed seed');
    }
    final seeds = SecureSeeds(
      edSeedHex: ed.toLowerCase(),
      xSeedHex: x.toLowerCase(),
    );
    if (await _writeToStore(seeds)) {
      await _wipeDatabaseSeeds();
    }
    return seeds;
  }

  Future<bool> _writeToStore(SecureSeeds seeds) async {
    try {
      await _secure.write(seeds);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _wipeDatabaseSeeds() async {
    await (update(
      db.identityEntry,
    )..where((i) => i.key.equals('self'))).write(
      const IdentityEntryCompanion(
        edSeedHex: Value(''),
        xSeedHex: Value(''),
      ),
    );
  }
}

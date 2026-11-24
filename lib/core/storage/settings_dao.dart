import 'package:drift/drift.dart';

import 'database.dart';

/// Key-value persistence for app settings, owned by this DAO and never synced.
class SettingsDao extends DatabaseAccessor<AppDatabase> {
  SettingsDao(super.db);

  Future<String?> get(String key) async {
    final row = await (select(
      db.appSettings,
    )..where((s) => s.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> set(String key, String value) async {
    await into(db.appSettings).insert(
      AppSettingsCompanion.insert(key: key, value: value),
      mode: InsertMode.insertOrReplace,
    );
  }

  Future<void> remove(String key) async {
    await (delete(db.appSettings)..where((s) => s.key.equals(key))).go();
  }
}
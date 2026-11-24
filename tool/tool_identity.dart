// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:sqlite3/open.dart';
import 'package:sqlite3/sqlite3.dart';

/// Identity seeds for the offline e2e tools.
///
/// Since T-72 the Android app keeps the seeds in the Android Keystore, so a
/// pulled `dtm.sqlite` row has none. `tool/identity_probe.dart` fetches them
/// from the debug-only dev server and writes `DIR/identity.json`; these tools
/// prefer that file and keep the database path for older builds.
class ToolIdentity {
  final String edSeedHex;
  final String xSeedHex;
  final String displayName;

  const ToolIdentity({
    required this.edSeedHex,
    required this.xSeedHex,
    required this.displayName,
  });
}

ToolIdentity? _fromJson(String dir) {
  final file = File('$dir/identity.json');
  if (!file.existsSync()) return null;
  final decoded = jsonDecode(file.readAsStringSync());
  if (decoded is! Map) return null;
  final ed = decoded['edSeedHex'];
  final x = decoded['xSeedHex'];
  final name = decoded['displayName'];
  if (ed is! String || x is! String || ed.isEmpty || x.isEmpty) return null;
  return ToolIdentity(
    edSeedHex: ed,
    xSeedHex: x,
    displayName: name is String ? name : '',
  );
}

ToolIdentity? identityFromDirectory(String dir) {
  final fromJson = _fromJson(dir);
  if (fromJson != null) return fromJson;

  open.overrideFor(
    OperatingSystem.linux,
    () => DynamicLibrary.open('libsqlite3.so.0'),
  );
  final db = sqlite3.open('$dir/dtm.sqlite');
  try {
    final rows = db.select(
      "select ed_seed_hex, x_seed_hex, display_name "
      "from identity_entry where key = 'self'",
    );
    if (rows.isEmpty) {
      print('no identity row');
      return null;
    }
    final row = rows.first;
    final ed = row['ed_seed_hex'] as String;
    final x = row['x_seed_hex'] as String;
    if (ed.isEmpty || x.isEmpty) {
      print('identity seeds live in the Android Keystore, not in the DB.');
      print('fetch them first:');
      print('  adb -s <serial> forward tcp:4701 tcp:4701');
      print('  dart run tool/identity_probe.dart $dir');
      return null;
    }
    return ToolIdentity(
      edSeedHex: ed,
      xSeedHex: x,
      displayName: row['display_name'] as String,
    );
  } finally {
    db.dispose();
  }
}

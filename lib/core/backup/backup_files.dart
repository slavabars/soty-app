import 'dart:io' show File, Platform;
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Saves and reads the encrypted backup document.
///
/// On Android both directions go through the system document picker, so the
/// file lives where the user chose and survives an app reinstall. Desktop has
/// no picker wired up: export writes into the app documents directory and
/// restore reports that picking is unavailable.
class BackupFiles {
  static const MethodChannel _channel = MethodChannel('ru.dcns.soty/backup');

  /// Only Android can hand a picked file back to Dart right now.
  static bool get canPick => Platform.isAndroid;

  /// Proposed file name, never containing secrets.
  static String defaultName() {
    final day = DateTime.now().toUtc().toIso8601String().substring(0, 10);
    return 'soty-backup-$day.soty';
  }

  /// Writes [bytes] and returns a user-facing location, or `null` when the
  /// user cancelled the picker.
  static Future<String?> save(Uint8List bytes, {String? name}) async {
    final fileName = name ?? defaultName();
    if (Platform.isAndroid) {
      return _channel.invokeMethod<String>('save', {
        'bytes': bytes,
        'name': fileName,
      });
    }
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  /// Copies an already-written backup file to a user-chosen location. This is
  /// the streaming export path: the platform copies the file chunk by chunk,
  /// so a 1 GiB backup never becomes a Dart byte array.
  static Future<String?> savePath(String path, {String? name}) async {
    final fileName = name ?? defaultName();
    if (Platform.isAndroid) {
      return _channel.invokeMethod<String>('savePath', {
        'path': path,
        'name': fileName,
      });
    }
    final dir = await getApplicationDocumentsDirectory();
    final target = File('${dir.path}/$fileName');
    await File(path).copy(target.path);
    return target.path;
  }

  /// Picks a backup and copies it into a private temp file, returning that
  /// path. Streaming restore reads the temp file chunk by chunk.
  static Future<String?> pickPath() async {
    if (!Platform.isAndroid) return null;
    return _channel.invokeMethod<String>('pickPath');
  }

  /// Reads the picked backup, or `null` when cancelled.
  ///
  /// Throws [PlatformException] when the platform refuses the file, so the
  /// caller can tell a cancelled picker from a failed read.
  static Future<Uint8List?> pick() async {
    if (!Platform.isAndroid) return null;
    return _channel.invokeMethod<Uint8List>('pick');
  }
}

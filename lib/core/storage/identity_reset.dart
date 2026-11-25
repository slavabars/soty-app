import 'dart:io';

import 'secure_identity_store.dart';

/// Deletes everything that belongs to the local identity after its key is
/// lost: the encrypted seed blob, the database (history, contacts, settings)
/// and the media cache. Irreversible by design — the app calls this only from
/// the recovery screen, after the user confirmed.
///
/// Files the app does not own are left alone, so a shared support directory
/// never loses unrelated data.
Future<void> eraseLocalIdentityData({
  required Directory support,
  required SecureIdentityStore secure,
}) async {
  await secure.clear();
  for (final name in const ['dtm.sqlite', 'dtm.sqlite-wal', 'dtm.sqlite-shm']) {
    final file = File('${support.path}/$name');
    if (await file.exists()) {
      await file.delete();
    }
  }
  final media = Directory('${support.path}/media');
  if (await media.exists()) {
    await media.delete(recursive: true);
  }
}

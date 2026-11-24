import 'dart:io';
import 'dart:typed_data';

import 'package:dtm_app/core/backup/backup_crypto.dart';
import 'package:dtm_app/core/backup/backup_stream.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List block(int seed, int length) => Uint8List.fromList(
      List<int>.generate(length, (i) => (i * 31 + seed) % 251),
    );

void main() {
  late Directory dir;
  late String path;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('soty_backup_stream');
    path = '${dir.path}/backup.soty';
  });

  tearDown(() async {
    await dir.delete(recursive: true);
  });

  test('a streaming backup round-trips without holding the file in memory',
      () async {
    final chunks = [for (var i = 0; i < 80; i++) block(i, 64 * 1024)];
    await BackupStream.write(
      path: path,
      password: 'correct horse',
      plaintext: Stream.fromIterable(chunks),
    );
    expect(await BackupStream.isStreamFile(path), isTrue);

    final received = <int>[];
    await for (final piece in BackupStream.read(
      path: path,
      password: 'correct horse',
    )) {
      received.addAll(piece);
    }
    expect(received.length, 80 * 64 * 1024);
    final expected = [for (final chunk in chunks) ...chunk];
    expect(received, expected);
  });

  test('a trailing short chunk is preserved', () async {
    await BackupStream.write(
      path: path,
      password: 'pw',
      plaintext: Stream.fromIterable([
        block(1, 1000),
        block(2, 70000),
        block(3, 17),
      ]),
    );
    final received = <int>[];
    await for (final piece in BackupStream.read(path: path, password: 'pw')) {
      received.addAll(piece);
    }
    expect(received.length, 1000 + 70000 + 17);
  });

  test('a wrong password cannot open the stream', () async {
    await BackupStream.write(
      path: path,
      password: 'right',
      plaintext: Stream.value(block(1, 4096)),
    );
    await expectLater(
      BackupStream.read(path: path, password: 'wrong').toList(),
      throwsA(isA<BackupAuthFailure>()),
    );
  });

  test('a tampered chunk is rejected', () async {
    await BackupStream.write(
      path: path,
      password: 'pw',
      plaintext: Stream.value(block(1, 4096)),
    );
    final bytes = await File(path).readAsBytes();
    bytes[bytes.length - 40] ^= 0x01;
    await File(path).writeAsBytes(bytes, flush: true);
    await expectLater(
      BackupStream.read(path: path, password: 'pw').toList(),
      throwsA(isA<BackupAuthFailure>()),
    );
  });

  test('a truncated file is rejected even at a chunk boundary', () async {
    await BackupStream.write(
      path: path,
      password: 'pw',
      plaintext: Stream.fromIterable([
        block(1, 64 * 1024),
        block(2, 64 * 1024),
      ]),
    );
    final bytes = await File(path).readAsBytes();
    await File(path).writeAsBytes(
      bytes.sublist(0, bytes.length - 40),
      flush: true,
    );
    await expectLater(
      BackupStream.read(path: path, password: 'pw').toList(),
      throwsA(isA<BackupAuthFailure>()),
    );
  });

  test('a legacy document is not mistaken for a streaming backup', () async {
    await File(path).writeAsString('{"format":"soty-backup-1"}');
    expect(await BackupStream.isStreamFile(path), isFalse);
  });
}

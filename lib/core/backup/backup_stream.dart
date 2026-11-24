import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../security_limits.dart';
import 'backup_crypto.dart';

/// Streaming counterpart of [BackupFile].
///
/// The legacy `soty-backup-1` document is one JSON object and therefore has to
/// be materialized twice (payload + ciphertext) before it can be written. A
/// 1 GiB history would need gigabytes of RAM. This format keeps the same
/// Argon2id key derivation but encrypts the payload as a sequence of 64 KiB
/// AES-256-GCM chunks, so memory stays bounded by one chunk no matter how
/// large the backup is.
///
/// Layout:
///
///     "SOTYBAK2\n"
///     u32 headerLength
///     header (UTF-8 JSON: KDF params, nonce prefix, chunk size)
///     repeated records:
///       u8  flag (0 = data, 1 = final)
///       u32 ciphertextLength (ciphertext + 16-byte tag)
///       ciphertext + tag
///
/// Every chunk uses a 12-byte nonce made from a random 4-byte prefix and the
/// 8-byte chunk index; the header is the AEAD associated data. The final
/// record carries the total plaintext length, so truncation is detected even
/// when the attacker cuts the file at a chunk boundary.
class BackupStream {
  static const String magic = 'SOTYBAK2\n';
  static const String format = 'soty-backup-2';
  static const int chunkBytes = 64 * 1024;
  static const int _tagBytes = 16;
  static const int _headerMaxBytes = 16 * 1024;
  static const int _finalIndex = -1;

  /// Whether [path] starts with the streaming magic. Reads only 9 bytes, so a
  /// multi-gigabyte legacy file is never loaded to make this decision.
  static Future<bool> isStreamFile(String path) async {
    final file = File(path);
    if (!await file.exists()) return false;
    final raf = await file.open();
    try {
      final head = await raf.read(magic.length);
      return utf8.decode(head, allowMalformed: true) == magic;
    } finally {
      await raf.close();
    }
  }

  /// Encrypts [plaintext] into [path]. The stream is consumed chunk by chunk;
  /// the caller may generate it from the database without building the whole
  /// backup in memory.
  static Future<void> write({
    required String path,
    required String password,
    required Stream<List<int>> plaintext,
  }) async {
    BackupFile.validatePassword(password);
    final salt = BackupFile.randomBytes(backupSaltBytes);
    final prefix = BackupFile.randomBytes(4);
    final key = await BackupFile.deriveKey(password, salt);
    final headerBytes = utf8.encode(
      jsonEncode({
        'format': format,
        'createdAt': DateTime.now().toUtc().millisecondsSinceEpoch,
        'kdf': {
          'algo': 'argon2id',
          'salt': base64Encode(salt),
          'memoryKib': backupKdfMemoryKib,
          'iterations': backupKdfIterations,
          'parallelism': backupKdfParallelism,
          'keyLength': 32,
        },
        'cipher': {
          'algo': 'aes-256-gcm-chunked',
          'noncePrefix': base64Encode(prefix),
          'chunkSize': chunkBytes,
        },
      }),
    );
    if (headerBytes.length > _headerMaxBytes) {
      throw const FormatException('backup header is too large');
    }

    final sink = File(path).openWrite();
    try {
      sink.add(utf8.encode(magic));
      sink.add(_u32(headerBytes.length));
      sink.add(headerBytes);

      var index = 0;
      var total = 0;
      var written = 0;
      final pending = BytesBuilder(copy: true);

      Future<void> emit(Uint8List data, {required bool finalChunk}) async {
        final box = await AesGcm.with256bits().encrypt(
          data,
          secretKey: key,
          nonce: _nonce(prefix, finalChunk ? _finalIndex : index),
          aad: headerBytes,
        );
        final body = Uint8List(box.cipherText.length + box.mac.bytes.length)
          ..setAll(0, box.cipherText)
          ..setAll(box.cipherText.length, box.mac.bytes);
        sink.add([finalChunk ? 1 : 0]);
        sink.add(_u32(body.length));
        sink.add(body);
        written += body.length + 5;
        if (written > maxBackupBytes + 64 * 1024 * 1024) {
          throw const FormatException('backup is too large');
        }
        if (!finalChunk) index++;
      }

      await for (final piece in plaintext) {
        pending.add(piece);
        while (pending.length >= chunkBytes) {
          final all = pending.takeBytes();
          var offset = 0;
          while (all.length - offset >= chunkBytes) {
            await emit(
              Uint8List.sublistView(all, offset, offset + chunkBytes),
              finalChunk: false,
            );
            offset += chunkBytes;
            total += chunkBytes;
          }
          if (offset < all.length) {
            pending.add(Uint8List.sublistView(all, offset));
          }
        }
      }
      if (pending.length > 0) {
        final tail = pending.takeBytes();
        await emit(tail, finalChunk: false);
        total += tail.length;
      }
      final footer = ByteData(8)..setUint64(0, total);
      await emit(footer.buffer.asUint8List(), finalChunk: true);
      await sink.flush();
    } finally {
      await sink.close();
    }
  }

  /// Decrypts [path] into a stream of plaintext chunks. Throws
  /// [BackupAuthFailure] for a wrong password, tampering, truncation or a
  /// reordered stream; [FormatException] for a malformed header.
  static Stream<List<int>> read({
    required String path,
    required String password,
  }) async* {
    BackupFile.validatePassword(password);
    final file = File(path);
    final length = await file.length();
    if (length > maxBackupBytes + 64 * 1024 * 1024) {
      throw const FormatException('backup is too large');
    }
    final raf = await file.open();
    try {
      final head = await raf.read(magic.length);
      if (utf8.decode(head, allowMalformed: true) != magic) {
        throw const FormatException('not a streaming backup');
      }
      final headerLength = _readU32(await _readExact(raf, 4));
      if (headerLength <= 0 || headerLength > _headerMaxBytes) {
        throw const FormatException('backup header is out of bounds');
      }
      final headerBytes = await _readExact(raf, headerLength);
      final Object? decoded;
      try {
        decoded = jsonDecode(utf8.decode(headerBytes));
      } on FormatException {
        throw const FormatException('backup header is not JSON');
      }
      if (decoded is! Map<String, dynamic> || decoded['format'] != format) {
        throw const FormatException('unsupported backup format');
      }
      final kdf = decoded['kdf'];
      if (kdf is! Map<String, dynamic> ||
          kdf['algo'] != 'argon2id' ||
          kdf['memoryKib'] != backupKdfMemoryKib ||
          kdf['iterations'] != backupKdfIterations ||
          kdf['parallelism'] != backupKdfParallelism ||
          kdf['keyLength'] != 32) {
        throw const FormatException('unsupported kdf parameters');
      }
      final salt = _bytes(kdf['salt'], backupSaltBytes);
      final cipher = decoded['cipher'];
      if (cipher is! Map<String, dynamic> ||
          cipher['algo'] != 'aes-256-gcm-chunked' ||
          cipher['chunkSize'] != chunkBytes) {
        throw const FormatException('unsupported cipher');
      }
      final prefix = _bytes(cipher['noncePrefix'], 4);
      final key = await BackupFile.deriveKey(password, salt);

      var expected = 0;
      var total = 0;
      var sawFinal = false;
      while (true) {
        final flagBytes = await raf.read(1);
        if (flagBytes.isEmpty) break;
        final flag = flagBytes[0];
        if (flag != 0 && flag != 1) {
          throw const FormatException('unknown backup record');
        }
        final bodyLength = _readU32(await _readExact(raf, 4));
        if (bodyLength < _tagBytes ||
            bodyLength > chunkBytes + _tagBytes) {
          throw const FormatException('backup record is out of bounds');
        }
        final body = await _readExact(raf, bodyLength);
        final cipherText = body.sublist(0, bodyLength - _tagBytes);
        final tag = body.sublist(bodyLength - _tagBytes);
        final nonce = _nonce(prefix, flag == 1 ? _finalIndex : expected);
        final List<int> clear;
        try {
          clear = await AesGcm.with256bits().decrypt(
            SecretBox(cipherText, nonce: nonce, mac: Mac(tag)),
            secretKey: key,
            aad: headerBytes,
          );
        } on SecretBoxAuthenticationError {
          throw const BackupAuthFailure();
        }
        if (flag == 1) {
          if (clear.length != 8) {
            throw const BackupAuthFailure();
          }
          final declared = ByteData.sublistView(
            Uint8List.fromList(clear),
          ).getUint64(0);
          if (declared != total) throw const BackupAuthFailure();
          sawFinal = true;
          break;
        }
        expected++;
        total += clear.length;
        if (total > maxBackupBytes) {
          throw const FormatException('backup is too large');
        }
        yield clear;
      }
      if (!sawFinal) {
        throw const BackupAuthFailure();
      }
    } finally {
      await raf.close();
    }
  }

  static Uint8List _nonce(Uint8List prefix, int index) {
    final out = Uint8List(12)..setAll(0, prefix);
    final view = ByteData.sublistView(out);
    if (index == _finalIndex) {
      view.setUint64(4, 0xFFFFFFFFFFFFFFFF);
    } else {
      view.setUint64(4, index);
    }
    return out;
  }

  static Uint8List _u32(int value) {
    final out = Uint8List(4);
    ByteData.sublistView(out).setUint32(0, value);
    return out;
  }

  static int _readU32(Uint8List bytes) =>
      ByteData.sublistView(bytes).getUint32(0);

  static Future<Uint8List> _readExact(RandomAccessFile raf, int count) async {
    final out = BytesBuilder(copy: true);
    var left = count;
    while (left > 0) {
      final piece = await raf.read(left);
      if (piece.isEmpty) {
        throw const BackupAuthFailure();
      }
      out.add(piece);
      left -= piece.length;
    }
    return out.takeBytes();
  }

  static Uint8List _bytes(Object? raw, int exact) {
    if (raw is! String) throw const FormatException('field must be base64');
    final Uint8List bytes;
    try {
      bytes = base64Decode(raw);
    } on FormatException {
      throw const FormatException('field is not base64');
    }
    if (bytes.length != exact) {
      throw const FormatException('field has the wrong length');
    }
    return bytes;
  }
}

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../security_limits.dart';

/// A backup that cannot be authenticated: wrong password, truncated
/// ciphertext or a tampered file. Deliberately one type, so a caller cannot
/// tell a wrong password from a damaged file (and neither can an attacker).
class BackupAuthFailure implements Exception {
  const BackupAuthFailure();

  @override
  String toString() => 'BackupAuthFailure';
}

/// Seals and opens the encrypted backup document.
///
/// Layout: JSON with fixed Argon2id parameters and an AES-256-GCM box. The
/// parameters are validated against [backupKdfMemoryKib] and friends *before*
/// deriving a key, so a hostile file cannot ask for gigabytes of memory.
class BackupFile {
  const BackupFile._();

  static const String format = 'soty-backup-1';

  static final Random _random = Random.secure();

  static Uint8List randomBytes(int count) {
    final out = Uint8List(count);
    for (var i = 0; i < count; i++) {
      out[i] = _random.nextInt(256);
    }
    return out;
  }

  /// Encrypts [payload] with a key derived from [password].
  static Future<String> seal({
    required String payload,
    required String password,
  }) async {
    validatePassword(password);
    final salt = randomBytes(backupSaltBytes);
    final nonce = randomBytes(backupNonceBytes);
    final key = await deriveKey(password, salt);
    final box = await AesGcm.with256bits().encrypt(
      utf8.encode(payload),
      secretKey: key,
      nonce: nonce,
    );
    return jsonEncode({
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
        'algo': 'aes-256-gcm',
        'nonce': base64Encode(nonce),
        'tag': base64Encode(box.mac.bytes),
        'ciphertext': base64Encode(box.cipherText),
      },
    });
  }

  /// Authenticates and decrypts [raw]; returns the payload string.
  static Future<String> open({
    required String raw,
    required String password,
  }) async {
    validatePassword(password);
    if (raw.length > maxBackupBytes) {
      throw const FormatException('backup is too large');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      throw const FormatException('backup is not JSON');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('backup must be an object');
    }
    if (decoded['format'] != format) {
      throw const FormatException('unsupported backup format');
    }
    final kdf = decoded['kdf'];
    if (kdf is! Map<String, dynamic>) {
      throw const FormatException('kdf must be an object');
    }
    if (kdf['algo'] != 'argon2id') {
      throw const FormatException('unsupported kdf');
    }
    if (kdf['memoryKib'] != backupKdfMemoryKib ||
        kdf['iterations'] != backupKdfIterations ||
        kdf['parallelism'] != backupKdfParallelism ||
        kdf['keyLength'] != 32) {
      throw const FormatException('unsupported kdf parameters');
    }
    final salt = _bytes(kdf['salt'], backupSaltBytes, 'salt');

    final cipher = decoded['cipher'];
    if (cipher is! Map<String, dynamic>) {
      throw const FormatException('cipher must be an object');
    }
    if (cipher['algo'] != 'aes-256-gcm') {
      throw const FormatException('unsupported cipher');
    }
    final nonce = _bytes(cipher['nonce'], backupNonceBytes, 'nonce');
    final tag = _bytes(cipher['tag'], backupTagBytes, 'tag');
    final cipherText = _bytes(cipher['ciphertext'], null, 'ciphertext');
    if (cipherText.isEmpty) {
      throw const FormatException('ciphertext is empty');
    }

    final key = await deriveKey(password, salt);
    try {
      final clear = await AesGcm.with256bits().decrypt(
        SecretBox(cipherText, nonce: nonce, mac: Mac(tag)),
        secretKey: key,
      );
      return utf8.decode(clear);
    } on SecretBoxAuthenticationError {
      throw const BackupAuthFailure();
    } on FormatException {
      throw const BackupAuthFailure();
    }
  }

  static Future<SecretKey> deriveKey(String password, Uint8List salt) {
    final kdf = Argon2id(
      parallelism: backupKdfParallelism,
      memory: backupKdfMemoryKib,
      iterations: backupKdfIterations,
      hashLength: 32,
    );
    return kdf.deriveKeyFromPassword(password: password, nonce: salt);
  }

  static void validatePassword(String password) {
    if (password.isEmpty) {
      throw const FormatException('password is required');
    }
    if (password.length > maxBackupPasswordLength) {
      throw const FormatException('password is too long');
    }
  }

  static Uint8List _bytes(Object? raw, int? exact, String what) {
    if (raw is! String) throw FormatException('$what must be base64');
    final Uint8List bytes;
    try {
      bytes = base64Decode(raw);
    } on FormatException {
      throw FormatException('$what is not base64');
    }
    if (exact != null && bytes.length != exact) {
      throw FormatException('$what has the wrong length');
    }
    return bytes;
  }
}

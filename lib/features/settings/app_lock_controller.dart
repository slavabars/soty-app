import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

import '../../core/crypto/hex.dart';
import '../../core/security_limits.dart';
import '../../core/storage/settings_dao.dart';

/// Platform biometric prompt abstraction. Injected so the controller stays
/// host-testable; the app wires [LocalBiometricAuth] (biometric_auth.dart).
abstract class BiometricAuth {
  Future<bool> isSupported();

  Future<bool> authenticate({required String reason});
}

/// Biometric auth that always fails; used on hosts without local_auth.
class UnavailableBiometricAuth implements BiometricAuth {
  const UnavailableBiometricAuth();

  @override
  Future<bool> isSupported() async => false;

  @override
  Future<bool> authenticate({required String reason}) async => false;
}

/// Derives a PBKDF2-HMAC-SHA256 verifier hash for [password].
typedef PasswordDeriver = Future<Uint8List> Function(
  String password,
  Uint8List salt,
  int iterations,
);

/// App-lock: a password verifier (PBKDF2-HMAC-SHA256) plus an optional
/// biometric gate on top. The verifier record is stored as
/// `pbkdf2-sha256|<iterations>|<saltHex>|<hashHex>` in the settings table,
/// so it never holds the password itself.
class AppLockController {
  static const String _verifierKey = 'app_lock_password';
  static const String _biometricKey = 'app_lock_biometric';

  final SettingsDao _dao;
  final BiometricAuth _biometric;
  final int _iterations;
  final PasswordDeriver _deriver;

  _PasswordRecord? _record;
  bool _biometricEnabled = false;
  bool _recoveredFromCorruptVerifier = false;

  /// Set when a biometric unlock succeeds. Lets the app resume without
  /// immediately re-locking, because the biometric prompt briefly backgrounds
  /// the activity and the lifecycle `resumed` event lands right after.
  DateTime? lastBiometricUnlockAt;

  AppLockController(
    this._dao, {
    BiometricAuth? biometric,
    int? iterations,
    PasswordDeriver? deriver,
  }) : _biometric = biometric ?? const UnavailableBiometricAuth(),
       _iterations = iterations ?? appLockPbkdf2Iterations,
       _deriver = deriver ?? _defaultDeriver;

  bool get isEnabled => _record != null;

  bool get isBiometricEnabled => _biometricEnabled && _record != null;

  /// True when [load] found a verifier it could not parse and dropped it. The
  /// app then boots unlocked and the UI tells the user to set the lock again:
  /// a corrupt record can never be verified, so refusing to start would lock
  /// the owner out of their own device for good.
  bool get recoveredFromCorruptVerifier => _recoveredFromCorruptVerifier;

  BiometricAuth get biometricAuth => _biometric;

  Future<void> load() async {
    final raw = await _dao.get(_verifierKey);
    _record = null;
    _recoveredFromCorruptVerifier = false;
    if (raw != null) {
      try {
        _record = _decodeRecord(raw);
      } on FormatException {
        _recoveredFromCorruptVerifier = true;
        await _dao.remove(_verifierKey);
        await _dao.remove(_biometricKey);
      }
    }
    _biometricEnabled =
        _record != null && await _dao.get(_biometricKey) == '1';
  }

  /// Stores a fresh verifier for [password] with a new random salt. The work
  /// factor is the controller's configured [iterations]. Throws
  /// [ArgumentError] when [password] is outside the legal length bounds.
  Future<void> setPassword(String password) async {
    _checkPasswordLength(password);
    final salt = _randomSalt();
    final hash = await _deriver(password, salt, _iterations);
    final record = _PasswordRecord(
      iterations: _iterations,
      saltHex: bytesToHex(salt),
      hashHex: bytesToHex(hash),
    );
    await _dao.set(_verifierKey, _encodeRecord(record));
    _record = record;
    _recoveredFromCorruptVerifier = false;
  }

  /// Constant-time password check against the stored verifier.
  Future<bool> verify(String password) async {
    if (password.length < minAppLockPasswordLength ||
        password.length > maxAppLockPasswordLength) {
      return false;
    }
    final record = _record;
    if (record == null) return false;
    final candidate = await _deriver(
      password,
      hexToBytes(record.saltHex),
      record.iterations,
    );
    return _constantTimeEquals(candidate, hexToBytes(record.hashHex));
  }

  /// Removes the verifier (and the biometric flag) only after [password]
  /// verifies. Returns `false` when the password is wrong.
  Future<bool> disable(String password) async {
    if (!await verify(password)) return false;
    await _dao.remove(_verifierKey);
    await _dao.remove(_biometricKey);
    _record = null;
    _biometricEnabled = false;
    return true;
  }

  /// Replaces the verifier after the current password verifies. Throws
  /// [ArgumentError] on a wrong [current] or an illegal [next].
  Future<void> changePassword({
    required String current,
    required String next,
  }) async {
    if (!await verify(current)) {
      throw ArgumentError('Current password is incorrect');
    }
    await setPassword(next);
  }

  /// Flips the biometric flag. Enabling requires [confirmPassword] to verify;
  /// disabling is gated by the lock itself. Throws [StateError] when no
  /// verifier exists yet.
  Future<void> setBiometricEnabled({
    required bool enabled,
    String? confirmPassword,
  }) async {
    if (_record == null) {
      throw StateError('App lock is not enabled');
    }
    if (enabled &&
        (confirmPassword == null || !await verify(confirmPassword))) {
      throw ArgumentError('Password confirmation failed');
    }
    await _dao.set(_biometricKey, enabled ? '1' : '0');
    _biometricEnabled = enabled;
  }

  /// Biometric unlock: only when a verifier and the biometric flag exist.
  Future<bool> unlockWithBiometric({required String reason}) async {
    if (_record == null || !_biometricEnabled) return false;
    final ok = await _biometric.authenticate(reason: reason);
    if (ok) lastBiometricUnlockAt = DateTime.now();
    return ok;
  }

  /// Runs the derivation off the UI isolate so a high iteration count does not
  /// freeze the frame; the work factor stays in [iterations].
  static Future<Uint8List> _defaultDeriver(
    String password,
    Uint8List salt,
    int iterations,
  ) {
    return Isolate.run(() => _derive(password, salt, iterations));
  }

  static Uint8List _derive(String password, Uint8List salt, int iterations) {
    final derivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
      ..init(Pbkdf2Parameters(salt, iterations, appLockHashBytes));
    return derivator.process(utf8.encode(password));
  }

  static Uint8List _randomSalt() {
    final rng = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(appLockSaltBytes, (_) => rng.nextInt(256)),
    );
  }

  static void _checkPasswordLength(String password) {
    if (password.length < minAppLockPasswordLength ||
        password.length > maxAppLockPasswordLength) {
      throw ArgumentError(
        'Password must be $minAppLockPasswordLength–'
        '$maxAppLockPasswordLength characters',
      );
    }
  }

  static String _encodeRecord(_PasswordRecord record) =>
      'pbkdf2-sha256|${record.iterations}|${record.saltHex}|${record.hashHex}';

  static _PasswordRecord _decodeRecord(String raw) {
    final parts = raw.split('|');
    if (parts.length != 4 || parts[0] != 'pbkdf2-sha256') {
      throw const FormatException('Malformed app lock verifier');
    }
    final iterations = int.tryParse(parts[1]);
    if (iterations == null ||
        iterations < minAppLockPbkdf2Iterations ||
        iterations > maxAppLockPbkdf2Iterations) {
      throw const FormatException('Malformed app lock iterations');
    }
    if (!isHexOfLength(parts[2], appLockSaltBytes) ||
        !isHexOfLength(parts[3], appLockHashBytes)) {
      throw const FormatException('Malformed app lock verifier bytes');
    }
    return _PasswordRecord(
      iterations: iterations,
      saltHex: parts[2],
      hashHex: parts[3],
    );
  }

  static bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}

class _PasswordRecord {
  final int iterations;
  final String saltHex;
  final String hashHex;

  const _PasswordRecord({
    required this.iterations,
    required this.saltHex,
    required this.hashHex,
  });
}
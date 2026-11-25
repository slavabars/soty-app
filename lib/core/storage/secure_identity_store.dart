import 'dart:io' show Platform;

import 'package:flutter/services.dart';

import '../crypto/hex.dart' show isHexOfLength;

/// The identity cannot be reconstructed: the stored ciphertext is unreadable
/// or the seed is gone. Usually this means Android restored the app's data from
/// a system backup while the Keystore key that decrypts the seeds stayed on the
/// old device. Nothing in the app can repair this; the user has to restore a
/// Soty backup or start over.
class IdentityUnavailableException implements Exception {
  final String detail;

  const IdentityUnavailableException([this.detail = '']);

  @override
  String toString() => 'IdentityUnavailableException($detail)';
}

/// The two 32-byte private seeds that make up a DTM identity.
class SecureSeeds {
  final String edSeedHex;
  final String xSeedHex;

  const SecureSeeds({required this.edSeedHex, required this.xSeedHex});

  /// Strict parse of platform output. A malformed record is a corrupt store,
  /// never something to "repair" by generating a fresh identity.
  factory SecureSeeds.fromPlatform(Object? raw) {
    if (raw is! Map) {
      throw const FormatException('secure identity: not a map');
    }
    final ed = raw['edSeedHex'];
    final x = raw['xSeedHex'];
    if (ed is! String || x is! String) {
      throw const FormatException('secure identity: missing seed');
    }
    if (!isHexOfLength(ed, 32) || !isHexOfLength(x, 32)) {
      throw const FormatException('secure identity: malformed seed');
    }
    return SecureSeeds(edSeedHex: ed.toLowerCase(), xSeedHex: x.toLowerCase());
  }

  Map<String, String> toPlatform() =>
      {'edSeedHex': edSeedHex, 'xSeedHex': xSeedHex};
}

/// Platform-backed storage for the identity seeds.
///
/// The seeds are the device's whole identity: whoever copies them can read and
/// send as its owner. On Android they are encrypted with an AES-256-GCM key
/// that never leaves the Android Keystore; the database then holds no secret.
/// Desktop and tests have no such keystore and report [isAvailable] false, in
/// which case the DAO keeps the seeds in the local database (documented
/// fallback — see `docs/threat_model.md`).
abstract class SecureIdentityStore {
  Future<bool> isAvailable();

  Future<SecureSeeds?> read();

  Future<void> write(SecureSeeds seeds);

  Future<void> clear();
}

/// [SecureIdentityStore] over `ru.dcns.soty/secure_identity`.
class PlatformSecureIdentityStore implements SecureIdentityStore {
  /// [supported] overrides the platform probe; tests pass `true` so the
  /// channel contract can be exercised on a Linux host.
  PlatformSecureIdentityStore({bool? supported}) : _supported = supported;

  static const MethodChannel _channel = MethodChannel(
    'ru.dcns.soty/secure_identity',
  );

  final bool? _supported;
  bool? _available;

  bool get _onAndroid => _supported ?? Platform.isAndroid;

  @override
  Future<bool> isAvailable() async {
    final cached = _available;
    if (cached != null) return cached;
    // Only Android has the channel. Touching it anywhere else (desktop, widget
    // tests) would hang or throw instead of reporting "not available".
    if (!_onAndroid) return _available = false;
    try {
      final available = await _channel.invokeMethod<bool>('available') ?? false;
      return _available = available;
    } on MissingPluginException {
      return _available = false;
    } on PlatformException {
      return _available = false;
    }
  }

  @override
  Future<SecureSeeds?> read() async {
    if (!await isAvailable()) return null;
    final Object? raw;
    try {
      raw = await _channel.invokeMethod<Object?>('read');
    } on PlatformException catch (error) {
      // The Kotlin side reports every keystore failure as code `keystore`.
      // A failed AEAD tag, a missing alias and a corrupt blob all mean the
      // same thing to the Dart layer: the identity cannot be read, and the
      // app must offer recovery instead of crashing on a raw error.
      if (error.code == 'keystore') {
        throw IdentityUnavailableException('${error.message}');
      }
      rethrow;
    }
    if (raw == null) return null;
    return SecureSeeds.fromPlatform(raw);
  }

  @override
  Future<void> write(SecureSeeds seeds) async {
    if (!await isAvailable()) {
      throw StateError('secure identity store is unavailable');
    }
    await _channel.invokeMethod<void>('write', seeds.toPlatform());
  }

  @override
  Future<void> clear() async {
    if (!await isAvailable()) return;
    await _channel.invokeMethod<void>('clear');
  }
}

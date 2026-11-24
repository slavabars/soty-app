import 'dart:async';

import '../../core/crypto/identity_claim.dart';
import '../../core/crypto/keypair.dart';
import '../../core/security_limits.dart' show maxDisplayNameLength;
import '../../core/storage/identity_dao.dart';

/// Owns the local identity lifecycle.
class IdentityController {
  final IdentityDao _dao;

  DtmKeyPair? _keyPair;
  String _displayName = '';

  IdentityController(this._dao);

  DtmKeyPair? get keyPair => _keyPair;

  String get displayName => _displayName;

  bool get hasIdentity => _keyPair != null;

  /// A signed invite others can import to reach us. `null` before an
  /// identity exists.
  Future<String?> invitePayload() async {
    final kp = _keyPair;
    if (kp == null) return null;
    return (await IdentityClaim.forIdentity(
      identity: kp,
      displayName: _displayName,
    )).encode();
  }

  Future<void> load() async {
    final stored = await _dao.load();
    if (stored != null) {
      _keyPair = stored.keyPair;
      _displayName = stored.displayName;
    }
  }

  Future<void> createNew({String displayName = ''}) async {
    final kp = await DtmKeyPair.generate();
    final clamped = _clampName(displayName);
    await _dao.save(kp, displayName: clamped);
    _keyPair = kp;
    _displayName = clamped;
  }

  Future<String?> edPublicKeyHex() async => _keyPair?.ed25519PublicKeyHex;

  Future<String?> xPublicKeyHex() async => _keyPair?.x25519PublicKeyHex;

  Future<void> setDisplayName(String name) async {
    final kp = _keyPair;
    if (kp == null) return;
    final clamped = _clampName(name);
    await _dao.save(kp, displayName: clamped);
    _displayName = clamped;
  }

  static String _clampName(String name) => name.length > maxDisplayNameLength
      ? name.substring(0, maxDisplayNameLength)
      : name;
}

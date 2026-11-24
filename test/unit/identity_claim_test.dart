import 'dart:convert';

import 'package:dtm_app/core/crypto/identity_claim.dart';
import 'package:dtm_app/core/crypto/keypair.dart';
import 'package:dtm_app/core/security_limits.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DtmKeyPair identity;

  setUp(() async {
    identity = await DtmKeyPair.generate();
  });

  Future<IdentityClaim> claimed({String name = 'Alice', int? createdAt}) =>
      IdentityClaim.forIdentity(
        identity: identity,
        displayName: name,
        createdAt: createdAt,
      );

  group('IdentityClaim signing', () {
    test('a freshly signed claim is valid', () async {
      final claim = await claimed();
      expect(await claim.check(), ClaimStatus.valid);
      expect(await claim.isValid(), isTrue);
    });

    test('claim binds the advertised X25519 key', () async {
      final claim = await claimed();
      expect(claim.xPubKey, await identity.x25519PublicKeyHex);
      expect(claim.edPubKey, await identity.ed25519PublicKeyHex);
    });

    test('tampering the display name breaks the signature', () async {
      final claim = await claimed();
      final forged = IdentityClaim(
        edPubKey: claim.edPubKey,
        xPubKey: claim.xPubKey,
        displayName: 'Mallory',
        createdAt: claim.createdAt,
        signature: claim.signature,
      );
      expect(await forged.check(), ClaimStatus.badSignature);
    });

    test('swapping the X25519 key breaks the signature', () async {
      final other = await DtmKeyPair.generate();
      final claim = await claimed();
      final forged = IdentityClaim(
        edPubKey: claim.edPubKey,
        xPubKey: await other.x25519PublicKeyHex,
        displayName: claim.displayName,
        createdAt: claim.createdAt,
        signature: claim.signature,
      );
      expect(await forged.check(), ClaimStatus.badSignature);
    });

    test('reusing a signature under another identity fails', () async {
      final attacker = await DtmKeyPair.generate();
      final claim = await claimed();
      final forged = IdentityClaim(
        edPubKey: await attacker.ed25519PublicKeyHex,
        xPubKey: claim.xPubKey,
        displayName: claim.displayName,
        createdAt: claim.createdAt,
        signature: claim.signature,
      );
      expect(await forged.check(), ClaimStatus.badSignature);
    });

    test('malformed key lengths and names are rejected structurally', () async {
      final claim = await claimed();
      final short = IdentityClaim(
        edPubKey: 'ab',
        xPubKey: claim.xPubKey,
        displayName: claim.displayName,
        createdAt: claim.createdAt,
        signature: claim.signature,
      );
      expect(await short.check(), ClaimStatus.malformed);

      final longName = IdentityClaim(
        edPubKey: claim.edPubKey,
        xPubKey: claim.xPubKey,
        displayName: 'x' * (maxDisplayNameLength + 1),
        createdAt: claim.createdAt,
        signature: claim.signature,
      );
      expect(await longName.check(), ClaimStatus.malformed);
    });

    test('future-dated claims are rejected', () async {
      final future = DateTime.now()
          .toUtc()
          .add(maxClockSkew + const Duration(minutes: 1))
          .millisecondsSinceEpoch;
      final claim = await claimed(createdAt: future);
      expect(await claim.check(), ClaimStatus.future);
    });

    test('claims older than maxClaimAge expire', () async {
      final past = DateTime.now()
          .toUtc()
          .subtract(maxClaimAge + const Duration(days: 1))
          .millisecondsSinceEpoch;
      final claim = await claimed(createdAt: past);
      expect(await claim.check(), ClaimStatus.expired);
    });

    test('an over-long display name cannot be signed', () async {
      await expectLater(
        claimed(name: 'x' * (maxDisplayNameLength + 1)),
        throwsArgumentError,
      );
    });
  });

  group('IdentityClaim serialization', () {
    test('encode/decode round-trips and still verifies', () async {
      final claim = await claimed();
      final restored = IdentityClaim.decode(claim.encode());
      expect(await restored.check(), ClaimStatus.valid);
      expect(restored.displayName, claim.displayName);
    });

    test('decode rejects non-object JSON', () {
      expect(() => IdentityClaim.decode('[]'), throwsFormatException);
      expect(() => IdentityClaim.decode('not json'), throwsFormatException);
    });

    test('fromJson rejects missing and mistyped fields', () {
      expect(
        () => IdentityClaim.fromJson(const {'edPubKey': 'aa'}),
        throwsFormatException,
      );
      final decoded = jsonDecode(
        '{"edPubKey":"aa","xPubKey":"bb","displayName":"n",'
        '"createdAt":"soon","signature":"cc"}',
      );
      expect(
        () => IdentityClaim.fromJson((decoded as Map).cast<String, dynamic>()),
        throwsFormatException,
      );
    });

    test('toString tolerates truncated keys', () {
      const claim = IdentityClaim(
        edPubKey: 'ab',
        xPubKey: 'cd',
        displayName: '',
        createdAt: 0,
        signature: 'ef',
      );
      expect(claim.toString(), contains('?'));
    });
  });
}

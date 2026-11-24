import 'package:dtm_app/core/crypto/identity_claim.dart';
import 'package:dtm_app/core/crypto/keypair.dart';
import 'package:dtm_app/core/invite_link.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('InviteLink', () {
    test('round-trips a real signed claim', () async {
      final kp = await DtmKeyPair.generate();
      final claim = await IdentityClaim.forIdentity(
        identity: kp,
        displayName: 'Alice <&"',
      );
      final link = InviteLink.encode(claim.encode());
      expect(link, startsWith('soty://invite?claim='));

      final json = InviteLink.claimFromRoute(link);
      expect(json, isNotNull);
      final decoded = IdentityClaim.decode(json!);
      expect(await decoded.check(), ClaimStatus.valid);
      expect(decoded.displayName, 'Alice <&"');
      expect(decoded.xPubKey, claim.xPubKey);
      expect(decoded.edPubKey, claim.edPubKey);
    });

    test('claimFromRoute returns null for non-invite routes', () {
      expect(InviteLink.claimFromRoute('/'), isNull);
      expect(InviteLink.claimFromRoute('soty://chats'), isNull);
      expect(InviteLink.claimFromRoute('https://example.com/x'), isNull);
      expect(InviteLink.claimFromRoute('soty://invite'), isNull);
      expect(InviteLink.claimFromRoute(''), isNull);
    });

    test('claimFromRoute throws FormatException on corrupt claims', () {
      expect(
        () => InviteLink.claimFromRoute('soty://invite?claim=!!!not-base64'),
        throwsFormatException,
      );
      expect(
        () => InviteLink.claimFromRoute('soty://invite?claim=%00'),
        throwsFormatException,
      );
    });
  });
}
import 'package:dtm_app/core/crypto/keypair.dart';
import 'package:dtm_app/core/storage/database.dart';
import 'package:dtm_app/core/storage/message_dao.dart';
import 'package:dtm_app/models/message_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late MessageDao dao;

  const myEd = 'e';
  const myX = 'x';
  const peerX = 'p';
  const peerEd = 'q';

  setUp(() {
    db = AppDatabase.inMemory();
    dao = MessageDao(db);
  });

  tearDown(() => db.close());

  Future<void> seedMessage(
    String id, {
    required int ts,
    String sender = peerEd,
    String recipient = myX,
  }) async {
    await db.into(db.messages).insert(
      MessagesCompanion.insert(
        id: id,
        senderPubKey: sender,
        recipientPubKey: recipient,
        timestamp: ts,
        ciphertext: 'c',
        ephemeralPubKey: 'e',
        signature: 's',
        source: 'seed',
      ),
    );
  }

  group('delivery status', () {
    test('an unknown id has no status', () async {
      expect(await dao.statusFor('a' * 64), isNull);
    });

    test('a status is inserted and read back', () async {
      await seedMessage('a' * 64, ts: 1);
      await dao.setStatus('a' * 64, MessageStatus.sent);
      expect(await dao.statusFor('a' * 64), MessageStatus.sent);
    });

    test('status only ever moves forward', () async {
      await seedMessage('a' * 64, ts: 1);
      await dao.setStatus('a' * 64, MessageStatus.read);
      await dao.setStatus('a' * 64, MessageStatus.sent);
      await dao.setStatus('a' * 64, MessageStatus.delivered);
      expect(await dao.statusFor('a' * 64), MessageStatus.read);
    });

    test('the same status applied twice is idempotent', () async {
      await seedMessage('a' * 64, ts: 1);
      await dao.setStatus('a' * 64, MessageStatus.delivered);
      await dao.setStatus('a' * 64, MessageStatus.delivered);
      expect(await dao.statusFor('a' * 64), MessageStatus.delivered);
    });

    test('statusesFor returns only the ids that have a status', () async {
      await seedMessage('a' * 64, ts: 1);
      await seedMessage('b' * 64, ts: 2);
      await dao.setStatus('a' * 64, MessageStatus.sent);

      final map = await dao.statusesFor(['a' * 64, 'b' * 64, 'c' * 64]);
      expect(map, {'a' * 64: MessageStatus.sent});
    });

    test('pendingOutboundIds lists unsent ids in timestamp order', () async {
      await seedMessage('a' * 64, ts: 30);
      await seedMessage('b' * 64, ts: 10);
      await seedMessage('c' * 64, ts: 20);
      await dao.setStatus('a' * 64, MessageStatus.queued);
      await dao.setStatus('b' * 64, MessageStatus.queued);
      await dao.setStatus('c' * 64, MessageStatus.sent);

      expect(await dao.pendingOutboundIds(), ['b' * 64, 'a' * 64]);
      expect(await dao.pendingOutboundIds(limit: 1), ['b' * 64]);
    });

    test('a message without a status row is never pending', () async {
      await seedMessage('a' * 64, ts: 1);
      expect(await dao.pendingOutboundIds(), isEmpty);
    });
  });

  group('control flag', () {
    test('an ordinary message is not control', () async {
      await seedMessage('a' * 64, ts: 1);
      expect(await dao.isControl('a' * 64), isFalse);
    });

    test('markControl flags the row', () async {
      await seedMessage('a' * 64, ts: 1);
      await dao.markControl('a' * 64);
      expect(await dao.isControl('a' * 64), isTrue);
    });

    test('a control message never shows in a dm conversation', () async {
      await seedMessage('a' * 64, ts: 1, sender: peerEd, recipient: myX);
      await seedMessage('b' * 64, ts: 2, sender: peerEd, recipient: myX);
      await dao.markControl('b' * 64);

      final messages = await dao.messagesFor(
        peerX,
        myXPubKey: myX,
        myEdPubKey: myEd,
        peerEdPubKey: peerEd,
      );
      expect(messages.map((m) => m.id), ['a' * 64]);
    });
  });

  group('pruning', () {
    test('pruning deletes the matching status rows', () async {
      final deviceKey = await DtmKeyPair.generate();
      await seedMessage('a' * 64, ts: 1, sender: myEd, recipient: peerX);
      await dao.setStatus('a' * 64, MessageStatus.sent);

      await dao.pruneOlderThan(
        Duration.zero,
        deviceKey: deviceKey,
      );

      expect(await dao.statusFor('a' * 64), isNull);
    });
  });
}

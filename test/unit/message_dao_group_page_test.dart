import 'package:dtm_app/core/storage/database.dart';
import 'package:dtm_app/core/storage/message_dao.dart';
import 'package:flutter_test/flutter_test.dart';

MessagesCompanion _row({
  required String id,
  required String sender,
  required String recipient,
  required int timestamp,
}) =>
    MessagesCompanion.insert(
      id: id,
      senderPubKey: sender,
      recipientPubKey: recipient,
      timestamp: timestamp,
      ciphertext: 'ciphertext',
      ephemeralPubKey: 'ee' * 32,
      signature: 'ff' * 64,
      source: 'mesh',
    );

void main() {
  late AppDatabase db;
  late MessageDao dao;
  final meX = 'aa' * 32;
  final meEd = 'bb' * 32;
  final peerX = 'cc' * 32;
  final peerEd = 'dd' * 32;

  setUp(() {
    db = AppDatabase.inMemory();
    dao = MessageDao(db);
  });

  tearDown(() => db.close());

  test('a group page reads only the newest slice of a huge history', () async {
    await db.batch((batch) {
      batch.insertAll(db.messages, [
        for (var i = 0; i < 5000; i++)
          _row(
            id: '1${i.toRadixString(16).padLeft(63, '0')}',
            sender: peerEd,
            recipient: meX,
            timestamp: 1000 + i,
          ),
      ]);
    });

    final page = await dao.messagesForGroup(
      myXPubKey: meX,
      myEdPubKey: meEd,
      memberXKeys: [peerX],
      memberEdKeys: [peerEd],
      limit: 50,
    );

    expect(page, hasLength(50));
    expect(page.first.timestamp, 5950);
    expect(page.last.timestamp, 5999);
  });

  test('without a limit the group page still returns the whole pool', () async {
    await db.batch((batch) {
      batch.insertAll(db.messages, [
        for (var i = 0; i < 120; i++)
          _row(
            id: '2${i.toRadixString(16).padLeft(63, '0')}',
            sender: meEd,
            recipient: peerX,
            timestamp: 2000 + i,
          ),
      ]);
    });

    final all = await dao.messagesForGroup(
      myXPubKey: meX,
      myEdPubKey: meEd,
      memberXKeys: [peerX],
      memberEdKeys: [peerEd],
    );

    expect(all, hasLength(120));
    expect(all.first.timestamp, 2000);
    expect(all.last.timestamp, 2119);
  });

  test('a dm page also stays bounded on a huge history', () async {
    await db.batch((batch) {
      batch.insertAll(db.messages, [
        for (var i = 0; i < 5000; i++)
          _row(
            id: '3${i.toRadixString(16).padLeft(63, '0')}',
            sender: peerEd,
            recipient: meX,
            timestamp: 3000 + i,
          ),
      ]);
    });

    final page = await dao.messagesFor(
      peerX,
      myXPubKey: meX,
      myEdPubKey: meEd,
      peerEdPubKey: peerEd,
      limit: 50,
    );

    expect(page, hasLength(50));
    expect(page.last.timestamp, 7999);
  });
}

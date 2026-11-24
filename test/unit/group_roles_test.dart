import 'package:dtm_app/core/security_limits.dart';
import 'package:dtm_app/core/storage/conversation_dao.dart';
import 'package:dtm_app/core/storage/database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late ConversationDao dao;
  final me = 'aa' * 32;
  final other = 'bb' * 32;
  final third = 'cc' * 32;
  final groupId = 'dd' * 32;

  setUp(() async {
    db = AppDatabase.inMemory();
    dao = ConversationDao(db);
    await dao.createGroup(
      id: groupId,
      memberKeys: [me, other],
      title: 'Team',
      ts: 1,
      adminKeys: [me],
    );
  });

  tearDown(() => db.close());

  test('the creator is admin and the invitee is a member', () async {
    final members = await dao.membersWithRoles(groupId);
    expect(
      {for (final m in members) m.key: m.role},
      {me: ConversationDao.adminRole, other: ConversationDao.memberRole},
    );
    expect(await dao.isAdmin(groupId, me), isTrue);
    expect(await dao.isAdmin(groupId, other), isFalse);
  });

  test('an admin can add a member up to the cap', () async {
    await dao.addMember(groupId, third);
    expect((await dao.memberKeys(groupId)), contains(third));
    expect(await dao.roleOf(groupId, third), ConversationDao.memberRole);

    // Idempotent: adding twice does not duplicate or throw.
    await dao.addMember(groupId, third);
    expect(
      (await dao.memberKeys(groupId)).where((k) => k == third),
      hasLength(1),
    );
  });

  test('bad keys and rosters beyond the cap are refused', () async {
    await expectLater(dao.addMember(groupId, 'nope'), throwsArgumentError);

    final fillers = [
      for (var i = 0; i < maxGroupMembers; i++)
        i.toRadixString(16).padLeft(64, '0'),
    ];
    await expectLater(
      () async {
        for (final key in fillers) {
          await dao.addMember(groupId, key);
        }
      }(),
      throwsArgumentError,
    );
  });

  test('removing a member drops the role row', () async {
    await dao.addMember(groupId, third);
    expect(await dao.removeMember(groupId, third), isTrue);
    expect(await dao.roleOf(groupId, third), isNull);
    expect(await dao.removeMember(groupId, third), isFalse);
  });

  test('the last admin cannot be removed', () async {
    await expectLater(
      dao.removeMember(groupId, me),
      throwsStateError,
    );
  });

  test('roles are validated and can change both ways', () async {
    await dao.setRole(groupId, other, ConversationDao.adminRole);
    expect(await dao.isAdmin(groupId, other), isTrue);
    await dao.setRole(groupId, other, ConversationDao.memberRole);
    expect(await dao.isAdmin(groupId, other), isFalse);
    await expectLater(
      dao.setRole(groupId, other, 'owner'),
      throwsArgumentError,
    );
    await expectLater(
      dao.setRole(groupId, 'nope', ConversationDao.memberRole),
      throwsArgumentError,
    );
  });

  test('a roster replacement keeps roles of surviving members', () async {
    await dao.setRole(groupId, other, ConversationDao.adminRole);
    await dao.replaceMembers(groupId, [me, other, third]);

    expect(await dao.memberKeys(groupId), [me, other, third]);
    expect(await dao.isAdmin(groupId, other), isTrue);
    expect(await dao.roleOf(groupId, third), ConversationDao.memberRole);

    await dao.replaceMembers(groupId, [me, third]);
    expect(await dao.memberKeys(groupId), [me, third]);
    expect(await dao.roleOf(groupId, other), isNull);
  });
}

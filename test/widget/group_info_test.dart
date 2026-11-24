import 'package:dtm_app/core/storage/conversation_dao.dart';
import 'package:dtm_app/features/messenger/group_info_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'chat_fixture.dart';

Future<String> makeGroup(Fixture f) {
  return f.controller.createGroup(
    title: 'Team',
    memberPeerKeys: [f.peerX],
    ts: 1,
  );
}

Widget screen(Fixture f, String groupId) => GroupInfoScreen(
      messenger: f.controller,
      conversationId: groupId,
    );

void main() {
  testWidgets('an admin sees roles and can add a member', (tester) async {
    final f = await makeFixture();
    final groupId = await makeGroup(f);

    await tester.pumpWidget(wrap(screen(f, groupId)));
    await tester.pumpAndSettle();

    expect(find.text('Zora'), findsOneWidget);
    expect(find.text('You'), findsOneWidget);
    expect(find.text('Admin'), findsOneWidget);
    expect(find.text('Member'), findsOneWidget);

    await tester.tap(find.text('Add member').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).last,
      '77' * 32,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Add member'));
    await tester.pumpAndSettle();

    final members = await f.controller.groupMembers(groupId);
    expect(members.map((m) => m.key), contains('77' * 32));
  });

  testWidgets('a plain member sees the read-only roster', (tester) async {
    final f = await makeFixture();
    final groupId = await makeGroup(f);
    await f.controller.addGroupMember(groupId, '66' * 32);
    await f.controller.setGroupMemberRole(
      groupId,
      '66' * 32,
      ConversationDao.adminRole,
    );
    await f.controller.setGroupMemberRole(
      groupId,
      f.controller.myXPubKey,
      ConversationDao.memberRole,
    );

    await tester.pumpWidget(wrap(screen(f, groupId)));
    await tester.pumpAndSettle();

    expect(
      find.text('Only admins can change this group.'),
      findsOneWidget,
    );
    expect(find.text('Add member'), findsNothing);
    expect(find.byType(PopupMenuButton<String>), findsNothing);
  });
}

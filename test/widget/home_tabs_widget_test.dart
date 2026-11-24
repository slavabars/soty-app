import 'package:dtm_app/core/crypto/envelope_crypto.dart';
import 'package:dtm_app/core/crypto/identity_claim.dart';
import 'package:dtm_app/core/crypto/keypair.dart';
import 'package:dtm_app/core/i18n/app_prefs.dart';
import 'package:dtm_app/core/i18n/soty_l10n.dart';
import 'package:dtm_app/core/storage/conversation_dao.dart';
import 'package:dtm_app/core/storage/database.dart';
import 'package:dtm_app/core/storage/message_dao.dart';
import 'package:dtm_app/core/storage/peer_dao.dart';
import 'package:dtm_app/core/storage/pruned_roots_dao.dart';
import 'package:dtm_app/core/sync/envelope_processor.dart';
import 'package:dtm_app/core/transport/transport.dart';
import 'package:dtm_app/features/messenger/chats_tab.dart';
import 'package:dtm_app/features/messenger/home_screen.dart';
import 'package:dtm_app/features/messenger/messenger_controller.dart';
import 'package:dtm_app/features/messenger/unread_badge.dart';
import 'package:dtm_app/models/peer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<(MessengerController, DtmKeyPair, EnvelopeProcessor)>
makeMessenger() async {
  final db = AppDatabase.inMemory();
  final dao = MessageDao(db);
  final keyPair = await DtmKeyPair.generate();
  final processor = EnvelopeProcessor(identity: keyPair, dao: dao);
  final controller = MessengerController(
    processor: processor,
    dao: dao,
    peerDao: PeerDao(db),
    conversationDao: ConversationDao(db),
    prunedRootsDao: PrunedRootsDao(db),
    identity: keyPair,
    transports: const <Transport>[],
    storeOutgoing: () => false,
  );
  addTearDown(() async {
    await controller.dispose();
    await processor.dispose();
    await db.close();
  });
  await controller.init();
  return (controller, keyPair, processor);
}

Widget wrap(Widget child) {
  return MaterialApp(
    builder: (context, w) =>
        SotyL10n(locale: const Locale('en'), child: w ?? const SizedBox()),
    home: child,
  );
}

Widget homeScreen(
  MessengerController controller,
  GlobalKey<ChatsTabState> key,
) {
  return HomeScreen(
    messenger: controller,
    prefs: AppPrefs(),
    chatsTabKey: key,
    onIdentity: () {},
    onSettings: () {},
  );
}

void main() {
  testWidgets('chats/peers tabs navigate to the peer chat from the lists', (
    tester,
  ) async {
    final (controller, _, _) = await makeMessenger();
    Future<void> import(String name) async {
      final remote = await DtmKeyPair.generate();
      await controller.importPeer(
        DtmPeer(
          pubKey: await remote.x25519PublicKeyHex,
          displayName: name,
          lastSeen: DateTime.now(),
        ),
      );
    }

    final remote = await DtmKeyPair.generate();
    final x = await remote.x25519PublicKeyHex;
    await controller.importPeer(
      DtmPeer(pubKey: x, displayName: 'Zora', lastSeen: DateTime.now()),
    );
    await import('Alan');

    await tester.pumpWidget(wrap(homeScreen(controller, GlobalKey())));
    await tester.pumpAndSettle();

    // Default tab is Chats (empty) -> hint shown; tabs are visible.
    expect(find.textContaining('No conversations yet.'), findsOneWidget);
    expect(find.text('Chats'), findsOneWidget);
    expect(find.text('Peers'), findsOneWidget);

    await tester.tap(find.text('Peers'));
    await tester.pumpAndSettle();

    expect(find.text('Alan'), findsOneWidget);
    expect(find.text('Zora'), findsOneWidget);

    await tester.tap(find.text('Zora'));
    await tester.pumpAndSettle();

    expect(find.byType(AppBar), findsOneWidget);
    expect(find.text('Zora'), findsOneWidget);
    expect(find.byIcon(Icons.drive_file_rename_outline), findsOneWidget);
  });

  testWidgets('an unread chat is badged and opening it clears the badge', (
    tester,
  ) async {
    final (controller, _, processor) = await makeMessenger();
    controller.startListening();
    final remote = await DtmKeyPair.generate();
    final x = await remote.x25519PublicKeyHex;
    await controller.importPeer(
      DtmPeer(
        pubKey: x,
        edPubKey: await remote.ed25519PublicKeyHex,
        displayName: 'Zora',
        lastSeen: DateTime.now(),
      ),
    );
    final inbound = await createEnvelopeForPubKey(
      sender: remote,
      recipientX25519PubKeyHex: controller.myXPubKey,
      plaintext: 'unread',
    );
    await processor.process(inbound, source: TransportSource.mesh, hops: 0);

    await tester.pumpWidget(wrap(homeScreen(controller, GlobalKey())));
    await tester.pumpAndSettle();

    expect(controller.unreadTotal, 1);
    expect(find.byType(UnreadBadge), findsNWidgets(2));
    expect(find.text('1'), findsNWidgets(2));

    await tester.tap(find.text('Zora'));
    await tester.pumpAndSettle();

    expect(controller.visibleConversationId, x);
    expect(controller.conversationView(x)?.unreadCount, 0);
    expect(find.byType(UnreadBadge), findsNothing);
  });

  testWidgets(
    'chat rename sets a chat title without touching the contact name',
    (tester) async {
      final (controller, _, _) = await makeMessenger();
      final remote = await DtmKeyPair.generate();
      final x = await remote.x25519PublicKeyHex;
      await controller.importPeer(
        DtmPeer(pubKey: x, displayName: 'Zora', lastSeen: DateTime.now()),
      );
      await controller.sendText(recipientPubKey: x, plaintext: 'first');

      await tester.pumpWidget(wrap(homeScreen(controller, GlobalKey())));
      await tester.pumpAndSettle();

      expect(find.text('Zora'), findsOneWidget);
      await tester.tap(find.text('Zora'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.drive_file_rename_outline));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        'Zorita',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Zorita'), findsOneWidget);
      expect(controller.peers[x]!.displayName, 'Zora');
      expect(controller.conversationList.single.title, 'Zorita');
    },
  );

  testWidgets('long press on a peer renames the contact', (tester) async {
    final (controller, _, _) = await makeMessenger();
    final remote = await DtmKeyPair.generate();
    final x = await remote.x25519PublicKeyHex;
    await controller.importPeer(
      DtmPeer(pubKey: x, displayName: 'Old', lastSeen: DateTime.now()),
    );

    await tester.pumpWidget(wrap(homeScreen(controller, GlobalKey())));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Peers'));
    await tester.pumpAndSettle();

    await tester.longPress(find.text('Old'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      'New',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('New'), findsOneWidget);
    expect(find.text('Old'), findsNothing);
    expect(controller.peers[x]!.displayName, 'New');
  });

  testWidgets('a chat appears on the Chats tab once a message is sent', (
    tester,
  ) async {
    final (controller, _, _) = await makeMessenger();
    final remote = await DtmKeyPair.generate();
    final x = await remote.x25519PublicKeyHex;
    await controller.importPeer(
      DtmPeer(pubKey: x, displayName: 'Zora', lastSeen: DateTime.now()),
    );

    await tester.pumpWidget(wrap(homeScreen(controller, GlobalKey())));
    await tester.pumpAndSettle();
    expect(find.textContaining('No conversations yet.'), findsOneWidget);
    expect(find.text('Zora'), findsNothing);

    await controller.sendText(recipientPubKey: x, plaintext: 'hi');

    await tester.pumpAndSettle();
    expect(find.text('Zora'), findsOneWidget);
    expect(find.textContaining('No conversations yet.'), findsNothing);
  });

  testWidgets('openInvite imports the signed claim and opens the chat', (
    tester,
  ) async {
    final (controller, _, _) = await makeMessenger();
    final remote = await DtmKeyPair.generate();
    final claim = await IdentityClaim.forIdentity(
      identity: remote,
      displayName: 'Selina',
    );

    final chatsKey = GlobalKey<ChatsTabState>();
    await tester.pumpWidget(wrap(homeScreen(controller, chatsKey)));
    await tester.pumpAndSettle();

    final state = chatsKey.currentState!;
    await state.openInvite(claim);
    await tester.pumpAndSettle();

    final x = await remote.x25519PublicKeyHex;
    final peer = controller.peers[x]!;
    expect(peer.displayName, 'Selina');
    expect(peer.edPubKey, await remote.ed25519PublicKeyHex);
    expect(find.text('Selina'), findsOneWidget);
  });

  testWidgets('openInvite upgrades a peer that lacks the identity binding', (
    tester,
  ) async {
    final (controller, _, _) = await makeMessenger();
    final remote = await DtmKeyPair.generate();
    final x = await remote.x25519PublicKeyHex;
    await controller.importPeer(
      DtmPeer(pubKey: x, displayName: 'Old', lastSeen: DateTime.now()),
    );
    final claim = await IdentityClaim.forIdentity(
      identity: remote,
      displayName: 'Selina',
    );

    final chatsKey = GlobalKey<ChatsTabState>();
    await tester.pumpWidget(wrap(homeScreen(controller, chatsKey)));
    await tester.pumpAndSettle();

    final state = chatsKey.currentState!;
    await state.openInvite(claim);
    await tester.pumpAndSettle();

    final peer = controller.peers[x]!;
    expect(peer.displayName, 'Selina');
    expect(peer.edPubKey, await remote.ed25519PublicKeyHex);
    expect(find.text('Selina'), findsOneWidget);
  });

  testWidgets('new-chat menu grows from the FAB and is right-aligned', (
    tester,
  ) async {
    final (controller, _, _) = await makeMessenger();
    await tester.pumpWidget(wrap(homeScreen(controller, GlobalKey())));
    await tester.pumpAndSettle();

    final fab = find.byType(FloatingActionButton);
    await tester.tap(fab);
    await tester.pumpAndSettle();

    final menu = find.byKey(const Key('home-new-menu'));
    expect(menu, findsOneWidget);
    expect(find.text('New chat'), findsOneWidget);
    expect(find.text('New group'), findsOneWidget);

    final fabRect = tester.getRect(fab);
    final menuRect = tester.getRect(menu);
    expect(menuRect.right, moreOrLessEquals(fabRect.right, epsilon: 0.5));
    expect(menuRect.bottom, lessThan(fabRect.top));

    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();
    expect(menu, findsNothing);
  });

  testWidgets('new-chat menu opens the new-chat dialog', (tester) async {
    final (controller, _, _) = await makeMessenger();
    await tester.pumpWidget(wrap(homeScreen(controller, GlobalKey())));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home-new-chat')));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('empty device shows the no-conversations hint', (tester) async {
    final (controller, _, _) = await makeMessenger();
    await tester.pumpWidget(wrap(homeScreen(controller, GlobalKey())));
    await tester.pumpAndSettle();

    expect(find.textContaining('No conversations yet.'), findsOneWidget);
  });
}

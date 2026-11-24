import 'package:dtm_app/core/i18n/app_prefs.dart';
import 'package:dtm_app/core/i18n/soty_l10n.dart';
import 'package:dtm_app/core/storage/identity_dao.dart';
import 'package:dtm_app/core/storage/settings_dao.dart';
import 'package:dtm_app/features/identity/identity_controller.dart';
import 'package:dtm_app/features/identity/onboarding_screen.dart';
import 'package:dtm_app/features/messenger/group_info_screen.dart';
import 'package:dtm_app/features/messenger/home_screen.dart';
import 'package:dtm_app/features/messenger/search_screen.dart';
import 'package:dtm_app/features/settings/app_lock_controller.dart';
import 'package:dtm_app/features/settings/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'chat_fixture.dart';

/// Phone-sized surface, Arabic-capable localization, and the 200% text scale
/// the accessibility budget requires.
Widget app(
  Widget home, {
  double scale = 2,
  Locale locale = const Locale('en'),
}) {
  return MaterialApp(
    locale: locale,
    supportedLocales: supportedLocales,
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    builder: (context, child) => SotyL10n(
      locale: locale,
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
        ),
        child: child ?? const SizedBox(),
      ),
    ),
    home: home,
  );
}

Future<void> sizePhone(WidgetTester tester) async {
  tester.view.physicalSize = const Size(400, 820);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Scrolls a list to build every tile, collecting any layout error.
Future<void> scrollThrough(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.drag(find.byType(ListView).first, const Offset(0, -400));
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  testWidgets('the chat list survives a 200% text scale and Arabic RTL',
      (tester) async {
    await sizePhone(tester);
    final f = await makeFixture();
    await sendInbound(f, 'a rather long message for the preview line');
    final prefs = AppPrefs()..attach(SettingsDao(f.db));

    await tester.pumpWidget(
      app(
        HomeScreen(
          messenger: f.controller,
          prefs: prefs,
          onIdentity: () {},
          onSettings: () {},
        ),
        locale: const Locale('ar'),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final context = tester.element(find.byType(Scaffold).first);
    expect(Directionality.of(context), TextDirection.rtl);
  });

  testWidgets('the chat view survives a 200% text scale', (tester) async {
    await sizePhone(tester);
    final f = await makeFixture();
    await sendInbound(
      f,
      'An extremely long incoming message that has to wrap far beyond the '
      'width of the phone so the bubble is exercised at a double text size.',
    );

    await tester.pumpWidget(app(chat(f)));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.enterText(find.byType(TextField), 'reply at double size');
    await tester.pump(const Duration(milliseconds: 450));
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings survive a 200% text scale while scrolling',
      (tester) async {
    await sizePhone(tester);
    final f = await makeFixture();
    final identity = IdentityController(IdentityDao(f.db));
    await identity.createNew(displayName: 'Me');

    await tester.pumpWidget(
      app(
        SettingsScreen(
          identity: identity,
          messenger: f.controller,
          appLock: AppLockController(SettingsDao(f.db)),
          prefs: AppPrefs()..attach(SettingsDao(f.db)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await scrollThrough(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('search results survive a 200% text scale', (tester) async {
    await sizePhone(tester);
    final f = await makeFixture();
    await sendInbound(f, 'searchable text at double size');

    await tester.pumpWidget(
      app(
        SearchScreen(
          messenger: f.controller,
          prefs: AppPrefs()..attach(SettingsDao(f.db)),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'searchable');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('group info survives a 200% text scale', (tester) async {
    await sizePhone(tester);
    final f = await makeFixture();
    final groupId = await f.controller.createGroup(
      title: 'A fairly long group title for scaling',
      memberPeerKeys: [f.peerX],
      ts: 1,
    );

    await tester.pumpWidget(
      app(
        GroupInfoScreen(
          messenger: f.controller,
          conversationId: groupId,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('key controls expose semantics labels', (tester) async {
    final handle = tester.ensureSemantics();
    await sizePhone(tester);
    final f = await makeFixture();
    final prefs = AppPrefs()..attach(SettingsDao(f.db));

    await tester.pumpWidget(
      app(
        HomeScreen(
          messenger: f.controller,
          prefs: prefs,
          onIdentity: () {},
          onSettings: () {},
        ),
        scale: 1,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('Search'), findsOneWidget);
    expect(find.byTooltip('Settings'), findsOneWidget);
    expect(find.byTooltip('New chat'), findsOneWidget);

    await tester.pumpWidget(app(chat(f), scale: 1));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Send'), findsOneWidget);
    expect(find.byTooltip('Rename chat'), findsOneWidget);
    expect(find.byTooltip('Safety number'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('onboarding survives a 200% text scale', (tester) async {
    await sizePhone(tester);
    final f = await makeFixture();
    final identity = IdentityController(IdentityDao(f.db));

    await tester.pumpWidget(
      app(OnboardingScreen(identity: identity, onContinue: () {})),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

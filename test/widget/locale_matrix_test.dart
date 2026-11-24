import 'package:dtm_app/core/i18n/app_prefs.dart';
import 'package:dtm_app/core/i18n/soty_l10n.dart';
import 'package:dtm_app/core/storage/settings_dao.dart';
import 'package:dtm_app/features/messenger/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'chat_fixture.dart';

void main() {
  for (final locale in supportedLocales) {
    testWidgets(
        'the chat list renders in ${locale.languageCode} without overflow',
        (tester) async {
      tester.view.physicalSize = const Size(400, 820);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final f = await makeFixture();
      await sendInbound(f, 'A preview line for ${locale.languageCode}');
      final prefs = AppPrefs()..attach(SettingsDao(f.db));

      await tester.pumpWidget(
        MaterialApp(
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
                textScaler: const TextScaler.linear(1.6),
              ),
              child: child ?? const SizedBox(),
            ),
          ),
          home: HomeScreen(
            messenger: f.controller,
            prefs: prefs,
            onIdentity: () {},
            onSettings: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final context = tester.element(find.byType(Scaffold).first);
      expect(
        Directionality.of(context),
        locale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr,
      );
    });
  }
}

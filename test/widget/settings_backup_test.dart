import 'package:dtm_app/core/i18n/app_prefs.dart';
import 'package:dtm_app/core/i18n/soty_l10n.dart';
import 'package:dtm_app/core/storage/identity_dao.dart';
import 'package:dtm_app/core/storage/settings_dao.dart';
import 'package:dtm_app/features/identity/identity_controller.dart';
import 'package:dtm_app/features/settings/app_lock_controller.dart';
import 'package:dtm_app/features/settings/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'chat_fixture.dart';

void main() {
  testWidgets('settings shows the backup section with both actions',
      (tester) async {
    final f = await makeFixture();
    final identity = IdentityController(IdentityDao(f.db));
    await identity.createNew(displayName: 'Me');
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, w) =>
            SotyL10n(locale: const Locale('en'), child: w ?? const SizedBox()),
        home: SettingsScreen(
          identity: identity,
          messenger: f.controller,
          appLock: AppLockController(SettingsDao(f.db)),
          prefs: AppPrefs(),
          backup: null,
          onIdentityRestored: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Export backup'), 400);
    expect(find.text('Export backup'), findsOneWidget);
    expect(
      find.text(
        'Encrypted file with your identity, contacts and messages.',
      ),
      findsOneWidget,
    );

    await tester.scrollUntilVisible(find.text('Restore backup'), 200);
    expect(find.text('Restore backup'), findsOneWidget);
  });
}

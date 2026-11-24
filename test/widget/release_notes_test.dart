import 'dart:io';

import 'package:dtm_app/core/build_info.dart';
import 'package:dtm_app/core/i18n/app_prefs.dart';
import 'package:dtm_app/core/storage/identity_dao.dart';
import 'package:dtm_app/core/storage/settings_dao.dart';
import 'package:dtm_app/features/identity/identity_controller.dart';
import 'package:dtm_app/features/settings/app_lock_controller.dart';
import 'package:dtm_app/features/settings/settings_screen.dart';
import 'package:dtm_app/features/update/release_notes_view.dart';
import 'package:dtm_app/features/update/update_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'chat_fixture.dart';
import 'update_fixture.dart';

const _sha =
    '4bc10cd01b743e7b27bc3bc5a99a37479227856c4bd97083982fe2e5042dee53';

const _notes = '''
## Soty 1.7.0+18 — тест

## Что нового

- Новая подпись production-ключом.
- Кнопка «Повторить» в баннере.

## Файлы

| Файл | SHA-256 |
| --- | --- |
| soty-release.apk | $_sha |
| dtm_host.bin | 0420f2d4b259780795fe455883530700a61df41a98a9ec6aea18031ea37c4fcc |
''';

Widget wrap(Widget child) => MaterialApp(home: child);

void main() {
  testWidgets('a release-notes table renders as a table, not raw pipes',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        const Scaffold(
          body: SingleChildScrollView(child: ReleaseNotesView(_notes)),
        ),
      ),
    );

    expect(find.text('Файл'), findsOneWidget);
    expect(find.text('SHA-256'), findsOneWidget);
    expect(find.text('soty-release.apk'), findsOneWidget);
    expect(find.textContaining(_sha.substring(0, 12)), findsOneWidget);
    expect(find.textContaining('|'), findsNothing);
    expect(find.textContaining('soty-release.apk.'), findsNothing);
  });

  testWidgets('the update dialog shows the new build notes formatted',
      (tester) async {
    final f = await makeFixture();
    // check() never touches the cache directory; creating one with real IO
    // inside a widget test would block the fake-async zone.
    final cache = Directory('${Directory.systemTemp.path}/soty-notes-dialog');
    final feed = FakeFeed(fakeRelease('9.9.9+99', notes: _notes));
    final update = updateController(feed, SettingsDao(f.db), cache);
    addTearDown(update.dispose);
    await update.check();

    await tester.pumpWidget(
      wrap(
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showUpdateDialog(context, update),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    // The dialog embeds the update banner, whose progress visuals keep
    // animating: bounded pumps instead of pumpAndSettle.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      find.textContaining('Новая подпись production-ключом.'),
      findsOneWidget,
    );
    expect(find.text('soty-release.apk'), findsOneWidget);
    expect(find.textContaining('|'), findsNothing);
  });

  testWidgets('the version dialog shows that build\'s notes, not just a number',
      (tester) async {
    final f = await makeFixture();
    final cache = Directory('${Directory.systemTemp.path}/soty-version-notes');
    final feed = FakeFeed(fakeRelease('9.9.9+99'))
      ..tagNotes = '## Что нового\n\n- Исправление из этой версии\n';
    final update = updateController(feed, SettingsDao(f.db), cache);
    addTearDown(update.dispose);
    await update.check();

    tester.view.physicalSize = const Size(600, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final identity = IdentityController(IdentityDao(f.db));
    await identity.createNew(displayName: 'Me');
    await tester.pumpWidget(
      wrap(
        SettingsScreen(
          identity: identity,
          messenger: f.controller,
          appLock: AppLockController(SettingsDao(f.db)),
          prefs: AppPrefs()..attach(SettingsDao(f.db)),
          update: update,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Version').first);
    await tester.pumpAndSettle();

    expect(find.textContaining('Исправление из этой версии'), findsOneWidget);
    expect(find.text(kSotyVersion), findsWidgets);
  });
}

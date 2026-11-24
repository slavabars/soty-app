import 'dart:io';

import 'package:dtm_app/core/build_info.dart';
import 'package:dtm_app/core/i18n/soty_l10n.dart';
import 'package:dtm_app/core/storage/database.dart';
import 'package:dtm_app/core/storage/settings_dao.dart';
import 'package:dtm_app/core/update/update_controller.dart';
import 'package:dtm_app/core/update/update_installer.dart';
import 'package:dtm_app/features/update/update_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'update_fixture.dart';

void main() {
  late AppDatabase db;
  late Directory cache;
  late FakeFeed feed;
  late FakeInstaller installer;
  late UpdateController controller;

  setUp(() async {
    db = AppDatabase.inMemory();
    cache = await Directory.systemTemp.createTemp('soty-update-widget');
    feed = FakeFeed(fakeRelease('9.9.9+99'));
    installer = FakeInstaller();
    controller = updateController(
      feed,
      SettingsDao(db),
      cache,
      installer: installer,
    );
  });

  tearDown(() async {
    controller.dispose();
    await cache.delete(recursive: true);
    await db.close();
  });

  /// Lets the real file I/O of a fake download finish; `pumpAndSettle` alone
  /// can return before an awaited `writeAsBytes` completes.
  Future<void> finish(WidgetTester tester) async {
    for (var i = 0; i < 200; i++) {
      if (controller.phase != UpdatePhase.downloading) break;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
    }
    // The install path also stats the downloaded file, which is real I/O.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pumpBanner(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => SotyL10n(
          locale: const Locale('en'),
          child: child ?? const SizedBox.shrink(),
        ),
        home: Scaffold(
          body: Column(children: [UpdateBanner(controller: controller)]),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('no update means no banner', (tester) async {
    feed.release = null;
    await controller.check();
    await pumpBanner(tester);

    expect(find.textContaining('is available'), findsNothing);
    expect(find.text('Download'), findsNothing);
  });

  testWidgets('a newer release shows its version and Download',
      (tester) async {
    await controller.check();
    await pumpBanner(tester);

    expect(find.text('Version 9.9.9+99 is available'), findsOneWidget);
    expect(find.text('Download'), findsOneWidget);
    expect(find.text('Hide'), findsOneWidget);
    expect(find.text('Remind later'), findsOneWidget);
  });

  testWidgets('after downloading the button turns into Install',
      (tester) async {
    await controller.check();
    await pumpBanner(tester);

    await tester.tap(find.text('Download'));
    await finish(tester);

    expect(feed.downloads, 1);
    expect(find.text('Install'), findsOneWidget);
    expect(find.text('Download'), findsNothing);

    await tester.tap(find.text('Install'));
    await finish(tester);
    expect(installer.paths, hasLength(1));
    expect(installer.paths.single, endsWith('soty-update.apk'));
  });

  testWidgets('Hide removes the banner for this version', (tester) async {
    await controller.check();
    await pumpBanner(tester);

    await tester.tap(find.text('Hide'));
    await tester.pumpAndSettle();

    expect(find.textContaining('is available'), findsNothing);
    expect(controller.hasUpdate, isTrue);
  });

  testWidgets('Remind later removes the banner', (tester) async {
    await controller.check();
    await pumpBanner(tester);

    await tester.tap(find.text('Remind later'));
    await tester.pumpAndSettle();

    expect(find.textContaining('is available'), findsNothing);
  });

  testWidgets('a failed download is reported in place', (tester) async {
    feed.failDownload = true;
    await controller.check();
    await pumpBanner(tester);

    await tester.tap(find.text('Download'));
    await finish(tester);

    expect(find.text('Download failed'), findsOneWidget);
    expect(find.text('Download'), findsOneWidget);
  });

  testWidgets('a blocked install explains what to do next', (tester) async {
    installer.result = InstallLaunch.needsPermission;
    await controller.check();
    await pumpBanner(tester);
    await tester.tap(find.text('Download'));
    await finish(tester);

    await tester.tap(find.text('Install'));
    await finish(tester);

    expect(
      find.text('Allow Soty to install apps, then tap Install again.'),
      findsOneWidget,
    );
  });

  testWidgets('the dialog still offers the actions after Hide', (tester) async {
    await controller.check();
    await controller.hideBanner();
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => SotyL10n(
          locale: const Locale('en'),
          child: child ?? const SizedBox.shrink(),
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showUpdateDialog(context, controller),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Update available'), findsOneWidget);
    expect(find.text('Download'), findsOneWidget);
    expect(find.text('Install'), findsNothing);
  });

  testWidgets('the dialog shows the version and the release notes',
      (tester) async {
    await controller.check();
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => SotyL10n(
          locale: const Locale('en'),
          child: child ?? const SizedBox.shrink(),
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showUpdateDialog(context, controller),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Update available'), findsOneWidget);
    expect(
      find.text('Current version: $kSotyVersion'),
      findsOneWidget,
    );
    expect(find.text('Release notes'), findsOneWidget);
    expect(find.text('Что нового: исправления'), findsOneWidget);
    expect(find.text('Download'), findsOneWidget);
  });
}

import 'package:dtm_app/core/i18n/soty_l10n.dart';
import 'package:dtm_app/features/settings/backup_dialogs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget wrap(Widget child) => MaterialApp(
      builder: (context, w) =>
          SotyL10n(locale: const Locale('en'), child: w ?? const SizedBox()),
      home: child,
    );

Widget opener(void Function(String?) onResult, {required bool confirm}) {
  return Builder(
    builder: (context) => Scaffold(
      body: TextButton(
        onPressed: () async {
          onResult(
            await showBackupPasswordDialog(context, confirm: confirm),
          );
        },
        child: const Text('open'),
      ),
    ),
  );
}

void main() {
  testWidgets('a short password is refused with the minimum length',
      (tester) async {
    String? result;
    await tester.pumpWidget(wrap(opener((v) => result = v, confirm: true)));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'short');
    await tester.enterText(find.byType(TextField).at(1), 'short');
    await tester.tap(find.text('Export'));
    await tester.pump();

    expect(
      find.text('Password must be at least 8 characters'),
      findsOneWidget,
    );
    expect(result, isNull);
  });

  testWidgets('mismatched passwords are refused', (tester) async {
    String? result;
    await tester.pumpWidget(wrap(opener((v) => result = v, confirm: true)));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'longenough');
    await tester.enterText(find.byType(TextField).at(1), 'different');
    await tester.tap(find.text('Export'));
    await tester.pump();

    expect(find.text('Passwords do not match'), findsOneWidget);
    expect(result, isNull);
  });

  testWidgets('a matching password is returned and the dialog closes',
      (tester) async {
    String? result;
    await tester.pumpWidget(wrap(opener((v) => result = v, confirm: true)));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'correct horse');
    await tester.enterText(find.byType(TextField).at(1), 'correct horse');
    await tester.tap(find.text('Export'));
    await tester.pumpAndSettle();

    expect(result, 'correct horse');
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('restore requires an explicit confirmation', (tester) async {
    bool? result;
    await tester.pumpWidget(
      wrap(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showRestoreConfirmation(context);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Restore this backup?'), findsOneWidget);
    expect(
      find.text(
        'This replaces your identity, contacts and messages and restarts '
        'Soty.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(result, isFalse);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Restore'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('restore asks for one password only', (tester) async {
    await tester.pumpWidget(wrap(opener((_) {}, confirm: false)));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Restore'), findsWidgets);
  });
}

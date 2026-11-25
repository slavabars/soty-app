import 'package:dtm_app/features/identity/identity_recovery_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('explains the lost key and offers both ways out',
      (tester) async {
    var retries = 0;
    var resets = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: IdentityRecoveryScreen(
          onRetry: () => retries++,
          onStartOver: () async => resets++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Keys cannot be read'), findsOneWidget);
    expect(
      find.textContaining('restored from a system backup'),
      findsOneWidget,
    );

    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(retries, 1);
    expect(resets, 0);
  });

  testWidgets('starting over asks first and can be cancelled', (tester) async {
    var resets = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: IdentityRecoveryScreen(
          onRetry: () {},
          onStartOver: () async => resets++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Start over'));
    await tester.pumpAndSettle();
    expect(find.text('Delete local data'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(resets, 0);

    await tester.tap(find.text('Start over'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Start over'));
    await tester.pumpAndSettle();
    expect(resets, 1);
  });
}

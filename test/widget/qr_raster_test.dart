import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

void main() {
  final invite =
      '{"edPubKey":"50bce3810d847ec1b9aa1c76f9ccf0da257c'
      '7bf5711eb97f31298baf615f9947",'
      '"xPubKey":"7db22a61d5c8f6aab164849902fe7ac81695751b3'
      '8da240e94990a75a316ac7f",'
      '"displayName":"Soty kind puma","createdAt":1789904820279,'
      '"signature":"65f9df73b51b7633047ce3f12ffc82bfe498c064'
      '8af395af6913f3eb0cc64fe12a5e2d107039ca7b22989bfd96e8'
      'a52e0480ef38038571f4b4d64f3ce3cddb0a"}';

  Widget build() {
    final theme = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00897B)),
    );
    return MaterialApp(
      theme: theme,
      home: Scaffold(
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Soty kind puma', style: theme.textTheme.headlineSmall!),
                const SizedBox(height: 8),
                Text(
                  'Others add you by scanning this code from '
                  'Settings → Scan QR code.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: QrImageView(
                      data: invite,
                      version: QrVersions.auto,
                      size: 280,
                      gapless: true,
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('same TreeStructure as MyQrScreen renders a non-blank QR',
      (tester) async {
    await tester.pumpWidget(build());
    await tester.pumpAndSettle();

    final boundary = find
        .byWidgetPredicate((w) => w is CustomPaint)
        .evaluate()
        .map((e) => e.renderObject)
        .whereType<RenderCustomPaint>()
        .firstWhere(
          (r) => r.painter is QrPainter,
        );
    expect(boundary.size.width, greaterThan(0));
    expect(boundary.size.height, greaterThan(0));

    await expectLater(
      find.byType(QrImageView),
      matchesGoldenFile('goldens/qr_screen_golden.png'),
    );
  });
}
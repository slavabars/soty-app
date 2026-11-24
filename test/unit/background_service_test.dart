import 'package:dtm_app/core/background/background_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BackgroundService', () {
    // No Android channel handler exists under flutter_test: every call must
    // degrade to a silent no-op instead of breaking the caller.
    test('start and stop do not throw without the platform channel', () async {
      final service = BackgroundService();
      await service.start();
      await service.stop();
    });

    test('battery status reads false without the platform channel', () async {
      final service = BackgroundService();
      expect(await service.isIgnoringBatteryOptimizations(), isFalse);
      await service.requestIgnoreBatteryOptimizations();
    });
  });
}
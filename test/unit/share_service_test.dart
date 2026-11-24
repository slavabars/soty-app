import 'package:dtm_app/core/share/share_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('ru.dcns.soty/share');
  final calls = <MethodCall>[];

  void mock(PlatformException? error) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (error != null) throw error;
      return null;
    });
  }

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('an empty or blank message is never shared', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    mock(null);
    expect(await ShareService.shareText(''), isFalse);
    expect(await ShareService.shareText('   '), isFalse);
    expect(calls, isEmpty);
  });

  test('on Android the text reaches the channel and reports success',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    mock(null);
    expect(await ShareService.shareText('hello'), isTrue);
    expect(calls.single.method, 'shareText');
    expect(calls.single.arguments, {'text': 'hello'});
  });

  test('a channel failure reports false so the caller falls back', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    mock(PlatformException(code: 'unavailable'));
    expect(await ShareService.shareText('hello'), isFalse);
  });

  test('a non-Android target never reaches the channel', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    mock(null);
    expect(await ShareService.shareText('hello'), isFalse);
    expect(calls, isEmpty);
  });
}

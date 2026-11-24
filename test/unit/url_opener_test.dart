import 'package:dtm_app/core/net/url_opener.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('ru.dcns.soty/url');
  final calls = <MethodCall>[];

  void mock(Object? Function(MethodCall call)? handler) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return handler?.call(call);
    });
  }

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('only http and https are openable', () {
    expect(UrlOpener.isOpenable('https://example.com'), isTrue);
    expect(UrlOpener.isOpenable('http://example.com/a?b=1'), isTrue);
    for (final url in const [
      'javascript:alert(1)',
      'file:///etc/passwd',
      'data:text/html,x',
      'intent://scan#Intent;end',
      'tel:+70000000000',
      'not a url',
      '',
    ]) {
      expect(UrlOpener.isOpenable(url), isFalse, reason: url);
    }
  });

  test('a non-web scheme never reaches the channel', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    mock((_) => true);
    expect(await UrlOpener.open('javascript:alert(1)'), isFalse);
    expect(calls, isEmpty);
  });

  test('on Android a web url reaches the channel and opens', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    mock((_) => true);
    expect(await UrlOpener.open('https://example.com/x'), isTrue);
    expect(calls.single.method, 'openUrl');
    expect(calls.single.arguments, {'url': 'https://example.com/x'});
  });

  test('a channel failure reports false so the caller can copy', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    mock((_) => throw PlatformException(code: 'unavailable'));
    expect(await UrlOpener.open('https://example.com'), isFalse);
  });

  test('a false result reports false', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    mock((_) => false);
    expect(await UrlOpener.open('https://example.com'), isFalse);
  });

  test('a non-Android target never reaches the channel', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    mock((_) => true);
    expect(await UrlOpener.open('https://example.com'), isFalse);
    expect(calls, isEmpty);
  });
}

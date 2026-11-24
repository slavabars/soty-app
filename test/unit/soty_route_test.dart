import 'package:dtm_app/core/soty_route.dart';
import 'package:flutter_test/flutter_test.dart';

bool _route(String raw) => isSotyRoute(Uri.parse(raw));

void main() {
  test('an invite with a claim is handled', () {
    expect(_route('soty://invite?claim=eyJhIjoxfQ'), isTrue);
  });

  test('a host with an address is handled', () {
    expect(
      _route('soty://host?addr=wss%3A%2F%2Fexample.org%2Fsoty-ws'),
      isTrue,
    );
  });

  test('an invite or host with an empty parameter is not handled', () {
    expect(_route('soty://invite?claim='), isFalse);
    expect(_route('soty://invite'), isFalse);
    expect(_route('soty://host?addr='), isFalse);
    expect(_route('soty://host'), isFalse);
  });

  test('other soty hosts are not handled', () {
    for (final raw in const [
      'soty://settings',
      'soty://evil?claim=x',
      'soty://invite?other=1',
      'soty://',
    ]) {
      expect(_route(raw), isFalse, reason: raw);
    }
  });

  test('other schemes are not handled', () {
    for (final raw in const [
      'https://example.com/?claim=x',
      'javascript:alert(1)',
      'file:///etc/passwd',
      'sotyx://invite?claim=x',
      'SOTY://invitex?claim=x',
    ]) {
      expect(_route(raw), isFalse, reason: raw);
    }
  });

  test('scheme and host case do not matter', () {
    expect(_route('SOTY://INVITE?claim=1'), isTrue);
    expect(_route('Soty://Host?addr=ws%3A%2F%2Fa'), isTrue);
  });

  test('a claim with extra parameters is still handled', () {
    expect(_route('soty://invite?x=1&claim=abc'), isTrue);
  });
}

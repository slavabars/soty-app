import 'dart:io';

import 'package:dtm_app/core/net/optional_bind.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a free port is bound and yielded to the caller', () async {
    final server = await bindOptional(InternetAddress.loopbackIPv4, 0);
    expect(server, isNotNull);
    addTearDown(() => server!.close(force: true));
    expect(server!.port, greaterThan(0));
  });

  test('a busy port warns instead of throwing', () async {
    final first = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => first.close(force: true));

    final warnings = <Object>[];
    final second = await bindOptional(
      InternetAddress.loopbackIPv4,
      first.port,
      onWarning: warnings.add,
    );

    expect(second, isNull, reason: 'the caller keeps working without it');
    expect(warnings, hasLength(1));
    expect(warnings.single, isA<SocketException>());
  });

  test('a second bind after the first one closed succeeds', () async {
    final first = await bindOptional(InternetAddress.loopbackIPv4, 0);
    final port = first!.port;
    await first.close(force: true);

    final warnings = <Object>[];
    final second = await bindOptional(
      InternetAddress.loopbackIPv4,
      port,
      onWarning: warnings.add,
    );
    addTearDown(() => second?.close(force: true));
    expect(second, isNotNull);
    expect(warnings, isEmpty);
  });
}

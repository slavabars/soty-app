import 'dart:convert';

import 'package:dtm_app/core/host/host_link.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final hex64 = List.filled(64, 'a').join();

  group('HostEndpoint', () {
    test('strict parsing rejects a missing or mistyped addr', () {
      expect(
        () => HostEndpoint.fromJson(const {'edPubKey': ''}),
        throwsFormatException,
      );
      expect(
        () => HostEndpoint.fromJson(const {'addr': '', 'edPubKey': ''}),
        throwsFormatException,
      );
      expect(
        () => HostEndpoint.fromJson(const {'addr': 42, 'edPubKey': ''}),
        throwsFormatException,
      );
      expect(
        () => HostEndpoint.fromJson(const {
          'addr': 'http://host/ws',
          'edPubKey': '',
        }),
        throwsFormatException,
      );
    });

    test('strict parsing rejects a mistyped or malformed edPubKey', () {
      expect(
        () => HostEndpoint.fromJson(const {'addr': 'ws://h/ws', 'edPubKey': 7}),
        throwsFormatException,
      );
      expect(
        () => HostEndpoint.fromJson(const {
          'addr': 'ws://h/ws',
          'edPubKey': 'nothex',
        }),
        throwsFormatException,
      );
    });

    test('an empty edPubKey becomes null; wss:// and ws:// are accepted', () {
      expect(
        HostEndpoint.fromJson(const {'addr': 'wss://h/ws', 'edPubKey': ''})
            .edPubKey,
        isNull,
      );
      expect(
        HostEndpoint.fromJson(const {'addr': 'ws://h/ws', 'edPubKey': ''}).addr,
        'ws://h/ws',
      );
    });

    test('an oversized addr is rejected at the boundary', () {
      final tooLong = 'ws://${'a' * (256 * 1024)}/ws';
      expect(
        () => HostEndpoint.fromJson({'addr': tooLong, 'edPubKey': hex64}),
        throwsFormatException,
      );
      expect(HostEndpoint.isValidAddr(tooLong), isFalse);
      expect(
        HostEndpoint.isValidAddr('ws://${'a' * 100000}/ws'),
        isFalse,
      );
    });

    test('a hardened build refuses a plaintext ws:// endpoint', () {
      expect(
        HostEndpoint.isValidAddr('ws://relay.example/ws', allowInsecure: false),
        isFalse,
      );
      expect(
        HostEndpoint.isValidAddr('wss://relay.example/ws', allowInsecure: false),
        isTrue,
      );
      // The deployed plain-ws relay must keep working in the default build.
      expect(HostEndpoint.isValidAddr('wss://soty.su/soty-ws'), isTrue);
    });

    test('an endpoint without a host or with another scheme is invalid', () {
      expect(HostEndpoint.isValidAddr('ws:///ws'), isFalse);
      expect(HostEndpoint.isValidAddr('http://relay.example/ws'), isFalse);
      expect(HostEndpoint.isValidAddr(''), isFalse);
      expect(HostEndpoint.isValidAddr('wss://relay.example/ws'), isTrue);
    });
  });

  group('HostLink', () {
    final endpoint = HostEndpoint(
      addr: 'ws://relay.example:3000/ws',
      edPubKey: List.filled(64, 'b').join(),
    );

    test('encode → fromRoute round-trips both fields', () {
      final link = HostLink.encode(endpoint);
      expect(link, startsWith('soty://host?'));
      final restored = HostLink.fromRoute(link)!;
      expect(restored.addr, endpoint.addr);
      expect(restored.edPubKey, endpoint.edPubKey);
    });

    test('omit pk when the endpoint is not pinned', () {
      final link = HostLink.encode(
        const HostEndpoint(addr: 'ws://relay.example:3000/ws'),
      );
      expect(link, isNot(contains('pk=')));
      expect(HostLink.fromRoute(link)!.edPubKey, isNull);
    });

    test('non-host routes are not host links', () {
      expect(HostLink.fromRoute('soty://invite?x=1'), isNull);
      expect(HostLink.fromRoute('not a uri'), isNull);
    });

    test('corrupt host links throw FormatException', () {
      expect(() => HostLink.fromRoute('soty://host'), throwsFormatException);
      expect(
        () => HostLink.fromRoute('soty://host?addr=ftp://nope'),
        throwsFormatException,
      );
    });
  });

  group('HostLink.decodeStoredList', () {
    test('keeps valid entries and drops corrupt ones', () {
      final raw = jsonEncode([
        1,
        'not an endpoint',
        {
          'addr': 'ws://h/ws',
          'edPubKey': hex64,
        },
        {
          'addr': 'ws://h/ws',
          'edPubKey': 'zz',
        },
      ]);
      final hosts = HostLink.decodeStoredList(raw);
      expect(hosts.length, 1);
      expect(hosts.single.addr, 'ws://h/ws');
    });

    test('non-list payload yields no hosts', () {
      expect(HostLink.decodeStoredList('{"k":1}'), isEmpty);
      expect(HostLink.decodeStoredList('garbage'), isEmpty);
    });
  });
}
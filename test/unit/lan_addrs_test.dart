import 'dart:io';

import 'package:dtm_app/core/net/lan_addrs.dart';
import 'package:dtm_app/core/security_limits.dart' as limits;
import 'package:dtm_app/core/transport/p2p/p2p_transport.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  LanInterface iface(String name, List<InternetAddress> addrs) =>
      LanInterface(name: name, addresses: addrs);

  final v4 = InternetAddress('192.168.1.5');
  final linkLocal = InternetAddress('169.254.3.4');
  final loopback = InternetAddress('127.0.0.1');
  final multicast = InternetAddress('224.1.2.3');
  final any = InternetAddress('0.0.0.0');
  final v6 = InternetAddress('fe80::1', type: InternetAddressType.IPv6);

  group('lanMultiaddrs', () {
    test('advertises a plain home Wi-Fi IPv4 address', () {
      final out = lanMultiaddrs(interfaces: [iface('wlan0', [v4])]);
      expect(out, ['/ip4/192.168.1.5/tcp/$p2pListenPort']);
    });

    test('skips loopback, any, link-local, multicast and IPv6', () {
      final out = lanMultiaddrs(
        interfaces: [
          iface('lo', [loopback]),
          iface('wlan0', [v4, any, linkLocal, multicast, v6]),
        ],
      );
      expect(out, ['/ip4/192.168.1.5/tcp/$p2pListenPort']);
    });

    test('skips tunnel and virtual interfaces', () {
      final out = lanMultiaddrs(
        interfaces: [
          iface('tun0', [v4]),
          iface('ppp0', [v4]),
          iface('vethA1b2', [v4]),
          iface('docker0', [v4]),
          iface('br-abc123', [v4]),
          iface('virbr0', [v4]),
          iface('lo', [loopback]),
          iface('wlan0', [v4]),
        ],
      );
      expect(out, ['/ip4/192.168.1.5/tcp/$p2pListenPort']);
    });

    test('skips the cellular data interface', () {
      final out = lanMultiaddrs(
        interfaces: [
          iface('rmnet_data0', [InternetAddress('10.5.6.7')]),
          iface('rmnet0', [InternetAddress('10.5.6.8')]),
          iface('ccmni0', [InternetAddress('10.9.9.9')]),
          iface('pdp_ip0', [InternetAddress('10.1.2.3')]),
          iface('clat4', [InternetAddress('192.0.0.4')]),
          iface('wlan0', [v4]),
        ],
      );
      expect(out, ['/ip4/192.168.1.5/tcp/$p2pListenPort']);
    });

    test('deduplicates the same address across interfaces', () {
      final out = lanMultiaddrs(
        interfaces: [
          iface('wlan0', [v4, InternetAddress('192.168.1.10')]),
          iface('eth0', [v4, InternetAddress('192.168.1.10')]),
        ],
      );
      expect(out, [
        '/ip4/192.168.1.10/tcp/$p2pListenPort',
        '/ip4/192.168.1.5/tcp/$p2pListenPort',
      ]);
    });

    test('caps the result at the limit, keeping the smallest addresses', () {
      final addrs = [
        for (var i = 1; i <= 20; i++) InternetAddress('10.0.$i.$i'),
      ];
      final out = lanMultiaddrs(interfaces: [iface('wlan0', addrs)], max: 3);
      expect(out.length, 3);
      expect(out.first, '/ip4/10.0.1.1/tcp/$p2pListenPort');
    });

    test('returns an empty list for no usable interfaces', () {
      expect(lanMultiaddrs(interfaces: const []), isEmpty);
      expect(
        lanMultiaddrs(
          interfaces: [iface('wlan0', [linkLocal, loopback, any, v6])],
        ),
        isEmpty,
      );
    });
  });

  group('LanAddrs', () {
    test('refresh publishes the enumerated addresses', () async {
      final cache = LanAddrs(
        listInterfaces: () async => [iface('wlan0', [v4])],
      );
      expect(cache.current, isEmpty);
      await cache.refresh();
      expect(cache.current, ['/ip4/192.168.1.5/tcp/$p2pListenPort']);
    });

    test('a failed enumeration keeps the previous result', () async {
      final cache = LanAddrs(
        listInterfaces: () async => throw StateError('no permission'),
      );
      await cache.refresh();
      expect(cache.current, isEmpty);
    });

    test('refresh replaces, not appends', () async {
      var last = 1;
      final cache = LanAddrs(
        listInterfaces: () async => [
          iface('wlan0', [InternetAddress('10.0.0.$last')]),
        ],
      );
      await cache.refresh();
      last = 2;
      await cache.refresh();
      expect(cache.current, ['/ip4/10.0.0.2/tcp/$p2pListenPort']);
    });
  });

  group('mergeAdvertisedAddrs', () {
    test('merges auto LAN with an explicit define address', () {
      final out = mergeAdvertisedAddrs(
        ['/ip4/192.168.1.5/tcp/$p2pListenPort'],
        ['/ip4/10.0.2.2/tcp/5011'],
      );
      expect(out, [
        '/ip4/192.168.1.5/tcp/$p2pListenPort',
        '/ip4/10.0.2.2/tcp/5011',
      ]);
    });

    test('deduplicates when the define collides with a LAN addr', () {
      final out = mergeAdvertisedAddrs(
        ['/ip4/192.168.1.5/tcp/$p2pListenPort'],
        ['/ip4/192.168.1.5/tcp/$p2pListenPort'],
      );
      expect(out, ['/ip4/192.168.1.5/tcp/$p2pListenPort']);
    });

    test('honors the cap and skips empty strings', () {
      final lan = [
        for (var i = 1; i <= 10; i++) '/ip4/10.0.$i.1/tcp/$p2pListenPort',
      ];
      final out = mergeAdvertisedAddrs(
        lan,
        ['', '/ip4/10.9.9.9/tcp/$p2pListenPort'],
        max: 3,
      );
      expect(out.length, 3);
    });

    test('never exceeds the wire limit by default', () {
      final lan = [
        for (var i = 1; i <= 20; i++) '/ip4/10.0.$i.1/tcp/$p2pListenPort',
      ];
      final out = mergeAdvertisedAddrs(lan, const []);
      expect(out.length, lessThanOrEqualTo(limits.maxPeerAddrs));
    });
  });
}
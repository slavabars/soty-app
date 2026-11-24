import 'dart:io';

import 'package:flutter/foundation.dart';

import '../security_limits.dart' as limits;
import '../transport/p2p/p2p_transport.dart' show p2pListenPort;

/// Interface names that never expose a fellow-LAN peer: tunnels, VPNs, host
/// bridges, docker, loopback and the cellular data interface. A device on the
/// same home network would not be reachable through them, so advertising them
/// only wastes dial time — a carrier's CGNAT address in particular is
/// unreachable from every peer, LAN or not.
const Set<String> _nonLanInterfacePrefixes = {
  'br-',
  'ccmni',
  'clat',
  'docker',
  'lo',
  'pdp',
  'ppp',
  'rmnet',
  'tap',
  'tun',
  'utun',
  'veth',
  'virbr',
  'vmnet',
};

bool _isNonLanInterface(String name) =>
    _nonLanInterfacePrefixes.any((prefix) => name.startsWith(prefix));

/// A minimal view of a network interface, decoupled from `dart:io`'s
/// [NetworkInterface] (which is abstract and cannot be faked) so the address
/// selection logic stays unit-testable.
class LanInterface {
  const LanInterface({required this.name, required this.addresses});

  final String name;
  final List<InternetAddress> addresses;
}

/// Builds `/ip4/<addr>/tcp/<port>` multiaddrs from site-local IPv4 addresses
/// of [interfaces], skipping loopback, any (0.0.0.0), link-local, multicast
/// and tunnel/virtual interfaces. Deduplicated, deterministically sorted and
/// bounded by [max].
List<String> lanMultiaddrs({
  required List<LanInterface> interfaces,
  int port = p2pListenPort,
  int max = limits.maxAdvertisedLanAddrs,
}) {
  final found = <String>{};
  for (final iface in interfaces) {
    if (_isNonLanInterface(iface.name)) continue;
    for (final addr in iface.addresses) {
      if (addr.type != InternetAddressType.IPv4) continue;
      if (addr.isLoopback || addr.isLinkLocal || addr.isMulticast) continue;
      final raw = addr.address;
      if (raw.isEmpty || raw == '0.0.0.0' || !raw.contains('.')) continue;
      found.add('/ip4/$raw/tcp/$port');
    }
  }
  final sorted = found.toList(growable: false)..sort();
  return sorted.length <= max ? sorted : sorted.sublist(0, max);
}

/// Merges the auto-detected [lan] addresses with explicitly configured
/// [extra] ones (e.g. a `SOTY_ADVERTISE_ADDR` dart-define). Deduplicated,
/// bounded by [max] and never returns an empty string.
List<String> mergeAdvertisedAddrs(
  List<String> lan,
  List<String> extra, {
  int max = limits.maxPeerAddrs,
}) {
  final out = <String>[];
  final seen = <String>{};
  for (final addr in [...lan, ...extra]) {
    if (addr.isEmpty || out.length >= max) continue;
    if (!seen.add(addr)) continue;
    out.add(addr);
  }
  return out;
}

/// Caches the last enumerated LAN multiaddrs so the wire never blocks on
/// interface enumeration, and re-runs enumeration when the network layout may
/// have changed (startup, lifecycle resume, periodic timer).
class LanAddrs {
  LanAddrs({
    Future<List<LanInterface>> Function()? listInterfaces,
    this.port = p2pListenPort,
    this.max = limits.maxAdvertisedLanAddrs,
  }) : _listInterfaces = listInterfaces ?? _defaultList;

  final Future<List<LanInterface>> Function() _listInterfaces;
  final int port;
  final int max;

  List<String> _current = const [];

  List<String> get current => _current;

  static Future<List<LanInterface>> _defaultList() async {
    final raw = await NetworkInterface.list(
      includeLoopback: false,
      includeLinkLocal: false,
      type: InternetAddressType.IPv4,
    );
    return [
      for (final iface in raw)
        LanInterface(name: iface.name, addresses: iface.addresses),
    ];
  }

  /// Re-enumerates the local interfaces and publishes the new set. On failure
  /// (e.g. the platform refused the query) the previous result stays valid —
  /// a transient error must not clear what we already know how to reach.
  Future<List<String>> refresh() async {
    List<String> addrs;
    try {
      final interfaces = await _listInterfaces();
      addrs = lanMultiaddrs(interfaces: interfaces, port: port, max: max);
    } catch (_) {
      debugPrint('[lan] refresh failed, keeping ${_current.length} addr(s)');
      return _current;
    }
    _current = addrs;
    final label = addrs.isEmpty ? '(none)' : addrs.join(', ');
    debugPrint('[lan] advertise $label');
    return _current;
  }
}
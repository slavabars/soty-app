import 'dart:convert';
import 'dart:io' show InternetAddress;

import '../crypto/hex.dart' show isHexOfLength;
import '../security_limits.dart' show maxAddrLength;

/// Whether this build accepts plain `ws://` relay endpoints.
///
/// A plain WebSocket is readable and rewritable by anyone on the path, so a
/// hardened build sets `SOTY_ALLOW_INSECURE_RELAY=false` and only trusts
/// `wss://`. It stays opt-out because an existing relay may be served over
/// plain `ws://` on a private address.
const bool allowInsecureRelay = bool.fromEnvironment(
  'SOTY_ALLOW_INSECURE_RELAY',
  defaultValue: true,
);

/// A relay host a client subscribes to.
///
/// [addr] is the WebSocket endpoint (`ws://host:port/ws`); [edPubKey] is the
/// host's optional Ed25519 identity so the client can pin that the endpoint
/// is served by the expected operator. The URL length is bounded to cap
/// hostile inputs at the deep-link boundary.
class HostEndpoint {
  final String addr;
  final String? edPubKey;

  const HostEndpoint({required this.addr, this.edPubKey});

  /// Whether [raw] is a usable relay endpoint: bounded length, a `ws`/`wss`
  /// scheme, and a non-empty host. A `ws://` endpoint is refused when
  /// [allowInsecure] is off, so a hardened build cannot be downgraded to a
  /// plaintext socket by a hostile invite.
  static bool isValidAddr(
    String raw, {
    bool allowInsecure = allowInsecureRelay,
  }) {
    if (raw.isEmpty || raw.length > maxAddrLength) return false;
    final uri = Uri.tryParse(raw);
    if (uri == null || uri.host.isEmpty) return false;
    if (uri.scheme == 'wss') return true;
    return uri.scheme == 'ws' && allowInsecure;
  }

  static bool _validAddr(String raw) => isValidAddr(raw);

  /// Whether a relay endpoint learned from an untrusted tracker may be dialed.
  /// Loopback, unspecified, link-local and multicast targets are refused:
  /// they are the app's own services or the local network, not a relay. LAN
  /// private ranges are allowed because an OpenWrt relay lives there.
  /// [allowLoopback] is a test seam only.
  static bool isSafeLearnedAddr(
    String raw, {
    bool allowLoopback = false,
  }) {
    if (!isValidAddr(raw)) return false;
    final uri = Uri.tryParse(raw);
    if (uri == null || uri.host.isEmpty) return false;
    final host = uri.host.toLowerCase();
    if (host == 'localhost' || host.endsWith('.localhost')) return false;
    final ip = InternetAddress.tryParse(uri.host);
    if (ip == null) return true;
    if (!allowLoopback && ip.isLoopback) return false;
    if (ip.isLinkLocal || ip.isMulticast) return false;
    final addressBytes = ip.rawAddress;
    if (addressBytes.every((b) => b == 0)) return false;
    return true;
  }

  /// Strict parsing; malformed values throw [FormatException].
  factory HostEndpoint.fromJson(Map<String, dynamic> json) {
    final addr = json['addr'];
    final pk = json['edPubKey'];
    if (addr is! String || !_validAddr(addr)) {
      throw const FormatException('HostEndpoint addr is missing or invalid');
    }
    if (pk is! String) {
      throw const FormatException('HostEndpoint edPubKey is mistyped');
    }
    if (pk.isNotEmpty && !isHexOfLength(pk, 32)) {
      throw const FormatException('HostEndpoint edPubKey must be 32-byte hex');
    }
    return HostEndpoint(addr: addr, edPubKey: pk.isEmpty ? null : pk);
  }

  Map<String, dynamic> toJson() => {
    'addr': addr,
    'edPubKey': edPubKey ?? '',
  };
}

/// Serializes a host invite into the shareable `soty://host?addr=…&pk=…`
/// deep link and parses such links back. Parsing is strict: a malformed
/// segment throws [FormatException].
///
/// Multi-host redundancy is expected: a client subscribes to several hosts
/// so a censoring host cannot drop its traffic.
class HostLink {
  static const String scheme = 'soty';
  static const String host = 'host';

  static String encode(HostEndpoint endpoint) {
    final pk = endpoint.edPubKey;
    final params = {
      'addr': endpoint.addr,
      if (pk != null) 'pk': pk,
    };
    final query = params.entries
        .map(
          (e) =>
              '${Uri.encodeQueryComponent(e.key)}='
              '${Uri.encodeQueryComponent(e.value)}',
        )
        .join('&');
    return '$scheme://$host?$query';
  }

  /// Extracts a [HostEndpoint] from [route]; `null` when the route is not a
  /// host link. Throws [FormatException] when the link is corrupt.
  static HostEndpoint? fromRoute(String route) {
    final uri = Uri.tryParse(route);
    if (uri == null || uri.scheme != scheme || uri.host != host) return null;
    final addr = uri.queryParameters['addr'];
    if (addr == null || addr.isEmpty) {
      throw const FormatException('Host link is missing addr');
    }
    final pk = uri.queryParameters['pk'];
    return HostEndpoint.fromJson({
      'addr': addr,
      'edPubKey': pk ?? '',
    });
  }

  /// Decodes a stored JSON list of endpoints; malformed entries are dropped
  /// (never crashes the settings UI or transport start).
  static List<HostEndpoint> decodeStoredList(String raw) {
    final dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return const [];
    }
    if (decoded is! List) return const [];
    final out = <HostEndpoint>[];
    for (final item in decoded) {
      try {
        out.add(HostEndpoint.fromJson((item as Map<dynamic, dynamic>).cast()));
      } on FormatException {
        // Skip corrupt entry.
      } on TypeError {
        // Skip non-object entry.
      }
    }
    return out;
  }
}
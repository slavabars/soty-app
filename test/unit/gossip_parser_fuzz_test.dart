import 'dart:convert';
import 'dart:math';

import 'package:dtm_app/core/security_limits.dart' as limits;
import 'package:dtm_app/core/sync/gossip_message.dart';
import 'package:flutter_test/flutter_test.dart';

/// Hostile input must end at [FormatException]: a `TypeError`, a `CastError`
/// or a silently-accepted half-message proves the parser trusted a field it
/// should have validated.
void main() {
  final rng = Random(20261115);

  Object? randomValue(int depth) {
    final pick = rng.nextInt(depth > 2 ? 6 : 9);
    switch (pick) {
      case 0:
        return null;
      case 1:
        return rng.nextBool();
      case 2:
        return rng.nextInt(1 << 32) - (1 << 31);
      case 3:
        return rng.nextDouble();
      case 4:
        return 'x' * rng.nextInt(80);
      case 5:
        return '';
      case 6:
        return [
          for (var i = rng.nextInt(4); i > 0; i--) randomValue(depth + 1),
        ];
      case 7:
        return {
          for (var i = rng.nextInt(4); i > 0; i--)
            'k${rng.nextInt(5)}': randomValue(depth + 1),
        };
      default:
        return ['/ip4/10.0.0.1/tcp/4010'][rng.nextInt(1)];
    }
  }

  const types = [
    'HELLO',
    'WELCOME',
    'WANT',
    'HAVE',
    'GET',
    'ENVELOPES',
    'PUBLISH',
    'PUBLISHED',
    'SUBSCRIBE',
    'PEER_LIST',
    'NETWORK',
    'PRESENCE',
    'NOPE',
  ];

  test('random frames fail as FormatException, never as TypeError', () {
    for (var i = 0; i < 2000; i++) {
      final json = <String, dynamic>{
        'type': types[rng.nextInt(types.length)],
        for (var f = rng.nextInt(6); f > 0; f--)
          'f${rng.nextInt(8)}': randomValue(0),
      };
      try {
        GossipMessage.fromJson(json);
      } on FormatException {
        // The only acceptable rejection.
      } catch (e) {
        fail('${json['type']} accepted a malformed field with $e: $json');
      }
    }
  });

  test('oversized lists are refused before any element is parsed', () {
    final huge = List<String>.filled(limits.maxGossipItems + 1, 'a' * 64);
    expect(
      () => GossipMessage.fromJson({'type': 'GET', 'ids': huge}),
      throwsFormatException,
    );
    expect(
      () => GossipMessage.fromJson({
        'type': 'HAVE',
        'ids': List<Object>.filled(limits.maxGossipItems + 1, const {}),
      }),
      throwsFormatException,
    );
    expect(
      () => GossipMessage.fromJson({
        'type': 'ENVELOPES',
        'envelopes': jsonDecode(
          jsonEncode(List<Object>.filled(limits.maxGossipItems + 1, const {})),
        ),
      }),
      throwsFormatException,
    );
  });

  test('mistyped scalars and lists are FormatException', () {
    final bad = [
      {'type': 'HELLO'},
      {'type': 'HELLO', 'myPeerId': 7},
      {'type': 'WANT', 'since': 'yesterday'},
      {'type': 'HAVE', 'ids': 'not-a-list'},
      {'type': 'HAVE', 'ids': [1, 2]},
      {'type': 'SUBSCRIBE', 'keys': {'a': 1}},
      {'type': 'PUBLISHED', 'id': 'a' * 64, 'accepted': 'yes'},
      {'type': 'WELCOME', 'identity': 42},
      {'type': 'WELCOME', 'serverTime': 'now'},
      {'type': 'PEER_LIST', 'peers': 'nope'},
      {'type': 'PRESENCE', 'online': 'nope'},
    ];
    for (final json in bad) {
      expect(
        () => GossipMessage.fromJson(json),
        throwsFormatException,
        reason: '$json',
      );
    }
  });
}

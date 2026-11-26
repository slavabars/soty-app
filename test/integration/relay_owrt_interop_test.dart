import 'dart:io';

import 'package:dtm_app/core/crypto/envelope_crypto.dart';
import 'package:dtm_app/core/crypto/keypair.dart';
import 'package:dtm_app/core/host/host_link.dart';
import 'package:dtm_app/core/storage/database.dart';
import 'package:dtm_app/core/storage/settings_dao.dart';
import 'package:dtm_app/core/transport/host/host_transport.dart';
import 'package:dtm_app/core/transport/transport.dart';
import 'package:dtm_app/models/envelope.dart';
import 'package:flutter_test/flutter_test.dart';

/// Opt-in interop test against a running OpenWrt relay (`relay-owrt/`).
///
/// The regular suite skips it. Run it after a wire change:
///
///   host/relay-owrt/dist/x86_64/dtm_relay --listen 127.0.0.1 --port 13102 \
///     --identity /tmp/dtm-relay-identity
///   SOTY_RELAY_URL=ws://127.0.0.1:13102/ws \
///   SOTY_RELAY_PUB=banner-ed25519 \
///   flutter test --no-pub test/integration/relay_owrt_interop_test.dart
void main() {
  final url = Platform.environment['SOTY_RELAY_URL'];
  final pub = Platform.environment['SOTY_RELAY_PUB'];

  test('HostTransport publishes and backfills through dtm_relay', () async {
    final db = AppDatabase.inMemory();
    addTearDown(db.close);
    final settings = SettingsDao(db);
    final endpoint = HostEndpoint(addr: url!, edPubKey: pub);

    final aKeys = await DtmKeyPair.generate();
    final bKeys = await DtmKeyPair.generate();
    final aEd = await aKeys.ed25519PublicKeyHex;
    final aX = await aKeys.x25519PublicKeyHex;
    final bEd = await bKeys.ed25519PublicKeyHex;
    final bX = await bKeys.x25519PublicKeyHex;

    final aSink = _Sink();
    final bSink = _Sink();
    final a = HostTransport(
      settings: settings,
      lastTimestamp: () async => aSink.lastTimestamp,
      peerIdProvider: () => 'relay-owrt-test-a',
      bootstrapHost: endpoint,
    )..setEnvelopeSink(aSink);
    final b = HostTransport(
      settings: settings,
      lastTimestamp: () async => bSink.lastTimestamp,
      peerIdProvider: () => 'relay-owrt-test-b',
      bootstrapHost: endpoint,
    )..setEnvelopeSink(bSink);

    addTearDown(a.stop);
    addTearDown(b.stop);

    await a.start(myEdPubKey: aEd, myXPubKey: aX, displayName: 'A');
    await b.start(myEdPubKey: bEd, myXPubKey: bX, displayName: 'B');
    await _until(() => a.connectedHosts.isNotEmpty, 'A connects');
    await _until(() => b.connectedHosts.isNotEmpty, 'B connects');
    // Let B's SUBSCRIBE reach the relay before the first publish.
    await Future<void>.delayed(const Duration(milliseconds: 250));

    final first = await createEnvelopeForPubKey(
      sender: aKeys,
      recipientX25519PubKeyHex: bX,
      plaintext: 'over the router relay',
    );
    expect(await a.send(first), isTrue, reason: 'PUBLISH was not accepted');
    await _until(() => bSink.has(first.id), 'B receives the live envelope');
    expect(await bSink.first(first.id).verify(), isTrue);
    expect(await bSink.first(first.id).hasValidId(), isTrue);

    // Backfill: B is offline while A publishes; reconnecting B must get the
    // stored envelope from the relay's own store, not from a live fan-out.
    await b.stop();
    await Future<void>.delayed(const Duration(milliseconds: 150));
    final second = await createEnvelopeForPubKey(
      sender: aKeys,
      recipientX25519PubKeyHex: bX,
      plaintext: 'while B was offline',
    );
    expect(await a.send(second), isTrue);
    await b.start(myEdPubKey: bEd, myXPubKey: bX, displayName: 'B');
    await _until(() => bSink.has(second.id), 'B backfills the stored envelope');
    expect(await bSink.first(second.id).hasValidId(), isTrue);
  },
      skip: url == null || pub == null
          ? 'set SOTY_RELAY_URL and SOTY_RELAY_PUB to run'
          : false);
}

Future<void> _until(bool Function() predicate, String what) async {
  final deadline = DateTime.now().add(const Duration(seconds: 8));
  while (DateTime.now().isBefore(deadline)) {
    if (predicate()) return;
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  fail('timeout: $what');
}

class _Sink implements EnvelopeSink {
  final List<Envelope> received = [];
  int lastTimestamp = 0;

  bool has(String id) => received.any((e) => e.id == id);

  Envelope first(String id) => received.firstWhere((e) => e.id == id);

  @override
  Future<void> process(
    Envelope envelope, {
    required TransportSource source,
    required int hops,
  }) async {
    received.add(envelope);
    if (envelope.timestamp > lastTimestamp) {
      lastTimestamp = envelope.timestamp;
    }
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dtm_app/core/crypto/envelope_crypto.dart';
import 'package:dtm_app/core/crypto/handshake.dart';
import 'package:dtm_app/core/crypto/keypair.dart';
import 'package:dtm_app/core/host/host_link.dart';
import 'package:dtm_app/core/security_limits.dart'
    show hostPoolMaxFailures, maxFrameBytes, trackerStopPeerListCount;
import 'package:dtm_app/core/storage/database.dart';
import 'package:dtm_app/core/storage/message_dao.dart';
import 'package:dtm_app/core/storage/settings_dao.dart';
import 'package:dtm_app/core/sync/gossip_message.dart';
import 'package:dtm_app/core/transport/host/host_transport.dart';
import 'package:dtm_app/core/transport/transport.dart';
import 'package:dtm_app/models/envelope.dart';
import 'package:dtm_app/models/peer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HostTransport', () {
    final identityHex = List.filled(64, 'e').join();

    late _FakeHost fake;
    late AppDatabase db;
    late SettingsDao settings;
    late MessageDao messageDao;
    late DtmKeyPair device;
    late _RecordingSink sink;

    setUp(() async {
      fake = _FakeHost(identityHex: identityHex);
      await fake.start();
      db = AppDatabase.inMemory();
      settings = SettingsDao(db);
      messageDao = MessageDao(db);
      device = await DtmKeyPair.generate();
      sink = _RecordingSink();
    });

    tearDown(() async {
      await fake.stop();
      await db.close();
    });

Future<HostTransport> makeTransport({
    PeerImportable? peerImport,
    int Function()? peerCount,
    HostEndpoint? bootstrapHost,
    Set<String> retiredHosts = const <String>{},
    Duration reconnectBase = const Duration(seconds: 2),
    int? maxHostFailures,
    bool allowLoopbackHosts = true,
  }) async {
    final transport = HostTransport(
      settings: settings,
      lastTimestamp: messageDao.latestTimestamp,
      peerImport: peerImport,
      peerCount: peerCount,
      bootstrapHost: bootstrapHost,
      retiredHosts: retiredHosts,
      reconnectBase: reconnectBase,
      maxHostFailures: maxHostFailures ?? hostPoolMaxFailures,
      allowLoopbackHosts: allowLoopbackHosts,
    );
    transport.setEnvelopeSink(sink);
    await transport.start(
      myEdPubKey: await device.ed25519PublicKeyHex,
      myXPubKey: await device.x25519PublicKeyHex,
      displayName: 'tester',
    );
    // Production defaults to manual; these fixtures exercise tracker
    // discovery unless the test explicitly stores a mode.
    if (await settings.get('soty.relayMode') == null) {
      await transport.setRelayMode(RelayMode.auto);
    }
    addTearDown(transport.stop);
    return transport;
  }

    test('unions the baked-in relay and drops a retired address', () async {
      const retired = HostEndpoint(addr: 'ws://10.0.0.1:3100/ws');
      const manual = HostEndpoint(addr: 'wss://example.test/ws');
      await settings.set(
        'soty.hosts',
        jsonEncode([retired.toJson(), manual.toJson()]),
      );
      final fresh = HostEndpoint(addr: 'ws://127.0.0.1:${fake.port}/ws');

      final transport = await makeTransport(
        bootstrapHost: fresh,
        retiredHosts: {retired.addr},
      );
      await _until(
        () => transport.connectedHosts.any((h) => h.addr == fresh.addr),
      );

      final stored = HostLink.decodeStoredList(
        (await settings.get('soty.hosts'))!,
      );
      final addrs = stored.map((h) => h.addr).toSet();
      expect(addrs, contains(fresh.addr));
      expect(addrs, contains(manual.addr));
      expect(addrs, isNot(contains(retired.addr)));
    });

    test('drops a retired address from learned hosts and the visible list',
        () async {
      const retired = HostEndpoint(addr: 'ws://10.0.0.9:3100/ws');
      await settings.set(
        'soty.hosts',
        jsonEncode([retired.toJson()]),
      );
      await settings.set('soty.learnedHosts', jsonEncode([retired.addr]));

      final transport = await makeTransport(retiredHosts: {retired.addr});

      expect(
        transport.visibleHosts.map((h) => h.addr),
        isNot(contains(retired.addr)),
      );
      final learned =
          jsonDecode((await settings.get('soty.learnedHosts'))!) as List;
      expect(learned, isNot(contains(retired.addr)));
    });

    test('does not duplicate a bootstrap host that is already stored',
        () async {
      final endpoint = HostEndpoint(addr: 'ws://127.0.0.1:${fake.port}/ws');
      await settings.set(
        'soty.hosts',
        jsonEncode([endpoint.toJson()]),
      );

      final transport = await makeTransport(bootstrapHost: endpoint);
      await _until(
        () => transport.connectedHosts.any((h) => h.addr == endpoint.addr),
      );

      final stored = HostLink.decodeStoredList(
        (await settings.get('soty.hosts'))!,
      );
      expect(stored.map((h) => h.addr), [endpoint.addr]);
    });

    test('subscribes with the inbound-only cursor, never an outbound one',
        () async {
      final peer = await DtmKeyPair.generate();
      final deviceX = await device.x25519PublicKeyHex;
      final deviceEd = await device.ed25519PublicKeyHex;
      final peerX = await peer.x25519PublicKeyHex;

      final inbound = await createEnvelopeForPubKey(
        sender: peer,
        recipientX25519PubKeyHex: deviceX,
        plaintext: 'mine',
        timestamp: 2000,
      );
      final outbound = await createEnvelopeForPubKey(
        sender: device,
        recipientX25519PubKeyHex: peerX,
        plaintext: 'me newer',
        timestamp: 4000,
      );
      await messageDao.insertIfAbsent(inbound, source: 'p2p');
      await messageDao.insertIfAbsent(outbound, source: 'local');

      final transport = HostTransport(
        settings: settings,
        lastTimestamp: () =>
            messageDao.latestInboundTimestamp(deviceX, deviceEd),
        bootstrapHost: HostEndpoint(
          addr: 'ws://127.0.0.1:${fake.port}/ws',
        ),
      );
      transport.setEnvelopeSink(sink);
      await transport.start(
        myEdPubKey: deviceEd,
        myXPubKey: deviceX,
        displayName: 'tester',
      );
      addTearDown(transport.stop);

      await _until(() => fake.inbounds.any((m) => m is SubscribeMessage));
      final subscribe = fake.inbounds.whereType<SubscribeMessage>().single;
      expect(await messageDao.latestTimestamp(), 4000);
      expect(await messageDao.latestInboundTimestamp(deviceX, deviceEd), 2000);
      // The own outbound (global max) must never push the backfill cursor.
      expect(subscribe.since, 2000);
    });

    test('adds a host, subscribes with the own X key, and persists it',
        () async {
      final transport = await makeTransport();
      final endpoint = HostEndpoint(
        addr: 'ws://127.0.0.1:${fake.port}/ws',
      );

      expect(await transport.addHost(endpoint), isTrue);
      await _until(() => fake.inbounds.any((m) => m is SubscribeMessage));

      final subscribe = fake.inbounds.whereType<SubscribeMessage>().single;
      expect(subscribe.keys, [await device.x25519PublicKeyHex]);
      expect(transport.hosts.single.addr, endpoint.addr);
      expect(transport.connectedHosts.map((h) => h.addr), [endpoint.addr]);

      final persisted = jsonDecode((await settings.get('soty.hosts'))!);
      expect(persisted, isA<List<dynamic>>());
      expect(persisted.first['addr'], endpoint.addr);
    });

    test('relayed envelopes reach the sink with source and hops', () async {
      final sender = await DtmKeyPair.generate();
      final envelope = await createEnvelopeForPubKey(
        sender: sender,
        recipientX25519PubKeyHex: await device.x25519PublicKeyHex,
        plaintext: 'relayed',
      );
      fake.relayOnSubscribe = [
        [envelope],
      ];

      final transport = await makeTransport();
      await transport.addHost(
        HostEndpoint(addr: 'ws://127.0.0.1:${fake.port}/ws'),
      );

      await _until(() => sink.received.isNotEmpty);
      final (got, source, hops) = sink.received.single;
      expect(got.id, envelope.id);
      expect(source, TransportSource.host);
      expect(hops, 0);
    });

    test('send resolves on the published ack', () async {
      final transport = await makeTransport();
      await transport.addHost(
        HostEndpoint(addr: 'ws://127.0.0.1:${fake.port}/ws'),
      );
      await _until(() => transport.connectedHosts.isNotEmpty);

      final peer = await DtmKeyPair.generate();
      final ok = await createEnvelopeForPubKey(
        sender: device,
        recipientX25519PubKeyHex: await peer.x25519PublicKeyHex,
        plaintext: 'ack me',
      );
      expect(await transport.send(ok), isTrue);

      fake.acceptPublished = false;
      final rejected = await createEnvelopeForPubKey(
        sender: device,
        recipientX25519PubKeyHex: await peer.x25519PublicKeyHex,
        plaintext: 'reject me',
      );
      expect(await transport.send(rejected), isFalse);
    });

    test('a direct-only slice is published live, never stored', () async {
      final transport = await makeTransport();
      await transport.addHost(
        HostEndpoint(addr: 'ws://127.0.0.1:${fake.port}/ws'),
      );
      await _until(() => transport.connectedHosts.isNotEmpty);
      final peer = await DtmKeyPair.generate();
      final envelope = await createEnvelopeForPubKey(
        sender: device,
        recipientX25519PubKeyHex: await peer.x25519PublicKeyHex,
        plaintext: 'live slice',
      );

      expect(await transport.send(envelope, directOnly: true), isTrue);
      expect(
        fake.inbounds.whereType<PublishLiveMessage>(),
        hasLength(1),
      );
      expect(fake.inbounds.whereType<PublishMessage>(), isEmpty);
    });

    test('send returns false with nothing connected', () async {
      final transport = await makeTransport();
      final peer = await DtmKeyPair.generate();
      final envelope = await createEnvelopeForPubKey(
        sender: device,
        recipientX25519PubKeyHex: await peer.x25519PublicKeyHex,
        plaintext: 'nobody home',
      );
      expect(await transport.send(envelope), isFalse);
    });

    test('a pinned host whose identity mismatches is dropped', () async {
      final transport = await makeTransport();
      final pinned = HostEndpoint(
        addr: 'ws://127.0.0.1:${fake.port}/ws',
        edPubKey: List.filled(64, 'f').join(),
      );

      await transport.addHost(pinned);
      await _until(
        () => fake.helloCount >= 1 && transport.connectedHosts.isEmpty,
      );

      expect(fake.inbounds.any((m) => m is SubscribeMessage), isFalse);

      final peer = await DtmKeyPair.generate();
      final envelope = await createEnvelopeForPubKey(
        sender: device,
        recipientX25519PubKeyHex: await peer.x25519PublicKeyHex,
        plaintext: 'dropped',
      );
      expect(await transport.send(envelope), isFalse);
    });

    test('persisted hosts reconnect on a later start', () async {
      final first = await makeTransport();
      await first.addHost(
        HostEndpoint(addr: 'ws://127.0.0.1:${fake.port}/ws'),
      );
      await _until(() => fake.helloCount >= 1);
      await first.stop();

      final second = await makeTransport();
      await _until(() => fake.helloCount >= 2);
      await _until(() => second.connectedHosts.isNotEmpty);
    });

    test('re-subscribes after its socket is dropped and resumes live relay',
        () async {
      final transport = await makeTransport();
      await transport.addHost(
        HostEndpoint(addr: 'ws://127.0.0.1:${fake.port}/ws'),
      );
      await _until(() => fake.subscriptions >= 1);

      await fake.dropAll();
      await _until(() => fake.subscriptions >= 2);

      final sender = await DtmKeyPair.generate();
      final envelope = await createEnvelopeForPubKey(
        sender: sender,
        recipientX25519PubKeyHex: await device.x25519PublicKeyHex,
        plaintext: 'after reconnect',
      );
      fake.relayToAll(envelope);

      await _until(() => sink.received.isNotEmpty);
      expect(sink.received.single.$1.id, envelope.id);
      expect(sink.received.single.$2, TransportSource.host);
    });

    test('a garbage greeting drops the connection', () async {
      fake.garbageGreeting = true;
      final transport = await makeTransport();
      await transport.addHost(
        HostEndpoint(addr: 'ws://127.0.0.1:${fake.port}/ws'),
      );
      await _until(
        () => fake.helloCount >= 1 && transport.connectedHosts.isEmpty,
      );

      final peer = await DtmKeyPair.generate();
      final envelope = await createEnvelopeForPubKey(
        sender: device,
        recipientX25519PubKeyHex: await peer.x25519PublicKeyHex,
        plaintext: 'garbage',
      );
      expect(await transport.send(envelope), isFalse);
    });

    test('requests PEER_LIST only from tracker-capable hosts', () async {
      fake.trackerCapable = false;
      final transport = await makeTransport();
      await transport.addHost(
        HostEndpoint(addr: 'ws://127.0.0.1:${fake.port}/ws'),
      );
      await _until(() => fake.subscriptions >= 1);
      expect(transport.trackerRequestsSent, 0);

      fake.trackerCapable = true;
      await fake.dropAll();
      await _until(() => fake.peerListRequests >= 1);
      expect(transport.trackerRequestsSent, greaterThanOrEqualTo(1));
    });

    test('imports tracker peers into the p2p book via peerImport', () async {
      final importer = _RecordingImporter();
      final refPeer = await DtmKeyPair.generate();
      final otherPeer = await DtmKeyPair.generate();
      fake.peerListReply = [
        PeerRef(
          xPubKey: await refPeer.x25519PublicKeyHex,
          peerId: '12D3KooWEXAMPLE',
        ),
        PeerRef(
          xPubKey: await otherPeer.x25519PublicKeyHex,
          peerId: '12D3KooWOTHER',
          addrs: const ['/ip4/10.0.2.2/tcp/5011'],
        ),
      ];

      final transport = await makeTransport(peerImport: importer);
      await transport.addHost(
        HostEndpoint(addr: 'ws://127.0.0.1:${fake.port}/ws'),
      );

      await _until(() => importer.imported.isNotEmpty);
      expect(importer.imported.map((p) => p.pubKey), [
        await refPeer.x25519PublicKeyHex,
        await otherPeer.x25519PublicKeyHex,
      ]);
      expect(importer.imported.last.peerId, '12D3KooWOTHER');
      expect(importer.imported.last.addrs.single,
          '/ip4/10.0.2.2/tcp/5011');
      expect(importer.imported.last.isContact, isFalse);
      expect(transport.peersImported, 2);
    });

    test('a later peer list refreshes a known peer\u0027s addresses', () async {
      final importer = _RecordingImporter();
      final peer = await DtmKeyPair.generate();
      final xPub = await peer.x25519PublicKeyHex;
      fake.peerListReply = [PeerRef(xPubKey: xPub, peerId: '12D3KooWONE')];

      final transport = await makeTransport(peerImport: importer);
      await transport.addHost(
        HostEndpoint(addr: 'ws://127.0.0.1:${fake.port}/ws'),
      );
      await _until(() => importer.imported.isNotEmpty);
      expect(importer.imported.single.addrs, isEmpty);
      expect(transport.peersImported, 1);

      fake.peerListReply = [
        PeerRef(
          xPubKey: xPub,
          peerId: '12D3KooWONE',
          addrs: const ['/ip4/10.0.2.2/tcp/5011'],
        ),
      ];
      await transport.reannounce();

      await _until(() => importer.imported.length >= 2);
      expect(importer.imported.last.addrs, ['/ip4/10.0.2.2/tcp/5011']);
      expect(transport.peersImported, 1);
    });

    test('learned tracker hosts join the pool and get subscribed', () async {
      final second = _FakeHost(identityHex: identityHex);
      await second.start();
      addTearDown(second.stop);
      fake.hostListReply = [
        HostEndpoint(addr: 'ws://127.0.0.1:${second.port}/ws'),
      ];

      final transport = await makeTransport();
      await transport.setRelayMode(RelayMode.auto);
      await transport.addHost(
        HostEndpoint(addr: 'ws://127.0.0.1:${fake.port}/ws'),
      );

      await _until(() => second.subscriptions >= 1);
      expect(transport.hosts.map((h) => h.addr), [
        'ws://127.0.0.1:${fake.port}/ws',
        'ws://127.0.0.1:${second.port}/ws',
      ]);
    });

    test(
        'auto mode with a full p2p book still learns hosts but skips peers',
        () async {
      final importer = _RecordingImporter();
      final second = _FakeHost(identityHex: identityHex);
      await second.start();
      addTearDown(second.stop);
      fake.peerListReply = [
        PeerRef(
          xPubKey: List.filled(64, 'b').join(),
          peerId: '12D3KooWFULLBOOK',
        ),
      ];
      fake.hostListReply = [
        HostEndpoint(addr: 'ws://127.0.0.1:${second.port}/ws'),
      ];

      final transport = await makeTransport(
        peerCount: () => trackerStopPeerListCount + 10,
        peerImport: importer,
      );
      await transport.setRelayMode(RelayMode.auto);
      await transport.addHost(
        HostEndpoint(addr: 'ws://127.0.0.1:${fake.port}/ws'),
      );

      await _until(() => fake.peerListRequests >= 1);
      await _until(() => second.subscriptions >= 1);
      expect(transport.trackerRequestsSent, greaterThanOrEqualTo(1));
      expect(importer.imported, isEmpty);
      expect(transport.hosts.map((h) => h.addr), [
        'ws://127.0.0.1:${fake.port}/ws',
        'ws://127.0.0.1:${second.port}/ws',
      ]);
    });

    test('refuses a loopback endpoint learned from the tracker', () async {
      final second = _FakeHost(identityHex: identityHex);
      await second.start();
      addTearDown(second.stop);
      fake.hostListReply = [
        HostEndpoint(addr: 'ws://127.0.0.1:${second.port}/ws'),
      ];

      final transport = await makeTransport(allowLoopbackHosts: false);
      await transport.setRelayMode(RelayMode.auto);
      await transport.addHost(
        HostEndpoint(addr: 'ws://127.0.0.1:${fake.port}/ws'),
      );
      await _until(() => fake.peerListRequests >= 1);
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(transport.hosts.map((h) => h.addr), [
        'ws://127.0.0.1:${fake.port}/ws',
      ]);
      expect(second.subscriptions, 0);
    });

    test('a pinned relay signs WELCOME and is accepted', () async {
      final signer = await DtmKeyPair.generate();
      final pub = await signer.ed25519PublicKeyHex;
      final signed = _FakeHost(identityHex: pub, signer: signer);
      await signed.start();
      addTearDown(signed.stop);

      final transport = await makeTransport(
        bootstrapHost: HostEndpoint(
          addr: 'ws://127.0.0.1:${signed.port}/ws',
          edPubKey: pub,
        ),
      );
      await _until(() => signed.subscriptions >= 1);
      expect(transport.connectedHosts, hasLength(1));
    });

    test('a pinned relay without a WELCOME signature is rejected', () async {
      final signer = await DtmKeyPair.generate();
      final pub = await signer.ed25519PublicKeyHex;
      final unsigned = _FakeHost(identityHex: pub);
      await unsigned.start();
      addTearDown(unsigned.stop);

      final transport = await makeTransport(
        bootstrapHost: HostEndpoint(
          addr: 'ws://127.0.0.1:${unsigned.port}/ws',
          edPubKey: pub,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(transport.connectedHosts, isEmpty);
      expect(unsigned.subscriptions, 0);
    });

    test('manual mode never requests discovery or dials tracker hosts',
        () async {
      final second = _FakeHost(identityHex: identityHex);
      await second.start();
      addTearDown(second.stop);
      fake.hostListReply = [
        HostEndpoint(addr: 'ws://127.0.0.1:${second.port}/ws'),
      ];

      final transport = await makeTransport(
        peerCount: () => trackerStopPeerListCount + 10,
      );
      await transport.setRelayMode(RelayMode.manual);
      await transport.addHost(
        HostEndpoint(addr: 'ws://127.0.0.1:${fake.port}/ws'),
      );
      await _until(() => fake.subscriptions >= 1);

      expect(transport.relayMode, RelayMode.manual);
      expect(fake.peerListRequests, 0);
      expect(second.subscriptions, 0);
      expect(transport.hosts, hasLength(1));
      expect(transport.visibleHosts.map((h) => h.addr), [
        'ws://127.0.0.1:${fake.port}/ws',
      ]);
    });

    test('switching to manual drains learned hosts; back to auto redials',
        () async {
      final second = _FakeHost(identityHex: identityHex);
      await second.start();
      addTearDown(second.stop);
      fake.hostListReply = [
        HostEndpoint(addr: 'ws://127.0.0.1:${second.port}/ws'),
      ];

      final transport = await makeTransport(
        reconnectBase: const Duration(milliseconds: 20),
      );
      await transport.setRelayMode(RelayMode.auto);
      await transport.addHost(
        HostEndpoint(addr: 'ws://127.0.0.1:${fake.port}/ws'),
      );
      await _until(() => second.subscriptions >= 1);
      expect(transport.connectedHosts, hasLength(2));

      await transport.setRelayMode(RelayMode.manual);
      await _until(() => transport.connectedHosts.length == 1);
      expect(transport.hosts, hasLength(2));
      expect(transport.visibleHosts, hasLength(1));

      await transport.setRelayMode(RelayMode.auto);
      await _until(() => transport.connectedHosts.length == 2);
    });

    test('relay mode is read from persisted settings on start', () async {
      await settings.set('soty.relayMode', 'manual');
      final transport = await makeTransport();
      expect(transport.relayMode, RelayMode.manual);
    });

    test('evicts an unresponsive learned host after maxHostFailures',
        () async {
      final dead = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final deadAddr = 'ws://127.0.0.1:${dead.port}/ws';
      await dead.close(force: true);
      fake.hostListReply = [HostEndpoint(addr: deadAddr)];

      final transport = await makeTransport(
        reconnectBase: const Duration(milliseconds: 500),
        maxHostFailures: 2,
        peerImport: _RecordingImporter(),
      );
      await transport.addHost(
        HostEndpoint(addr: 'ws://127.0.0.1:${fake.port}/ws'),
      );

      await _until(() => transport.hosts.any((h) => h.addr == deadAddr));
      await _until(() => !transport.hosts.any((h) => h.addr == deadAddr));

      expect(transport.hosts.map((h) => h.addr), [
        'ws://127.0.0.1:${fake.port}/ws',
      ]);
    });

    test('announces the presence capability in HELLO', () async {
      final transport = await makeTransport();
      await transport.addHost(fake.endpoint);
      await _until(() => fake.helloCount > 0);
      expect(fake.helloCapabilities, contains(dtmPresence));
    });

    test('a PRESENCE feed flips a peer online and back offline', () async {
      final transport = await makeTransport();
      await transport.addHost(fake.endpoint);
      final seen = <DtmPeer>[];
      final sub = transport.peers.listen(seen.add);
      addTearDown(sub.cancel);

      await _until(() => transport.connectedHosts.isNotEmpty);
      final peerX = List.filled(64, 'a').join();
      fake.sendPresence([peerX]);
      await _until(() => seen.any((p) => p.pubKey == peerX && p.online));
      expect(seen.firstWhere((p) => p.pubKey == peerX).online, isTrue);

      fake.sendPresence([]);
      await _until(
        () => seen.any((p) => p.pubKey == peerX && !p.online),
      );
    });

    test('a listener that subscribes after the feed still sees the peers',
        () async {
      final transport = await makeTransport();
      await transport.addHost(fake.endpoint);
      await _until(() => transport.connectedHosts.isNotEmpty);

      final peerX = List.filled(64, 'a').join();
      fake.sendPresence([peerX]);
      await Future<void>.delayed(const Duration(milliseconds: 200));

      final seen = <DtmPeer>[];
      final sub = transport.peers.listen(seen.add);
      addTearDown(sub.cancel);
      await _until(() => seen.isNotEmpty);

      expect(seen.first.pubKey, peerX);
      expect(seen.first.online, isTrue);
    });

    test('presence from one host keeps a peer online while another lists it',
        () async {
      final second = _FakeHost(identityHex: List.filled(64, 'f').join());
      await second.start();
      addTearDown(second.stop);

      final transport = await makeTransport();
      final seen = <DtmPeer>[];
      final sub = transport.peers.listen(seen.add);
      addTearDown(sub.cancel);
      await transport.addHost(fake.endpoint);
      await transport.addHost(
        HostEndpoint(addr: 'ws://127.0.0.1:${second.port}/ws'),
      );
      await _until(() => transport.connectedHosts.length == 2);

      final peerX = List.filled(64, 'b').join();
      fake.sendPresence([peerX]);
      second.sendPresence([peerX]);
      await _until(() => seen.where((p) => p.pubKey == peerX).isNotEmpty);
      expect(
        seen.lastWhere((p) => p.pubKey == peerX).online,
        isTrue,
      );

      fake.sendPresence([]);
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(
        seen.lastWhere((p) => p.pubKey == peerX).online,
        isTrue,
        reason: 'the second host still lists the peer',
      );

      second.sendPresence([]);
      await _until(
        () => seen.any((p) => p.pubKey == peerX && !p.online),
      );
    });

    test('a dropped host socket takes its presence claims with it', () async {
      final transport = await makeTransport();
      await transport.addHost(fake.endpoint);
      final seen = <DtmPeer>[];
      final sub = transport.peers.listen(seen.add);
      addTearDown(sub.cancel);

      await _until(() => transport.connectedHosts.isNotEmpty);
      final peerX = List.filled(64, 'c').join();
      fake.sendPresence([peerX]);
      await _until(() => seen.any((p) => p.pubKey == peerX && p.online));

      await fake.dropAll();
      await _until(
        () => seen.any((p) => p.pubKey == peerX && !p.online),
      );
    });

    test('a presence feed never reports the device itself as a peer',
        () async {
      final transport = await makeTransport();
      await transport.addHost(fake.endpoint);
      final seen = <DtmPeer>[];
      final sub = transport.peers.listen(seen.add);
      addTearDown(sub.cancel);

      await _until(() => transport.connectedHosts.isNotEmpty);
      final myX = await device.x25519PublicKeyHex;
      fake.sendPresence([myX]);
      fake.sendPresence([List.filled(64, 'd').join()]);
      await _until(() => seen.isNotEmpty);
      expect(seen.any((p) => p.pubKey == myX), isFalse);
    });
  });
}

class _RecordingImporter implements PeerImportable {
  final List<DtmPeer> imported = [];

  @override
  void importPeer(DtmPeer peer) {
    imported.add(peer);
  }
}

class _RecordingSink implements EnvelopeSink {
  final List<(Envelope, TransportSource, int)> received = [];

  @override
  Future<void> process(
    Envelope envelope, {
    required TransportSource source,
    required int hops,
  }) async {
    received.add((envelope, source, hops));
  }
}

class _FakeHost {
  final String identityHex;
  final DtmKeyPair? signer;
  _FakeHost({required this.identityHex, this.signer});

  bool acceptPublished = true;
  bool garbageGreeting = false;
  bool trackerCapable = true;
  bool liveCapable = true;
  List<PeerRef> peerListReply = const [];
  List<HostEndpoint> hostListReply = const [];
  List<List<Envelope>> relayOnSubscribe = const [];
  final List<GossipMessage> inbounds = [];
  final Set<WebSocket> _sockets = {};
  int helloCount = 0;
  List<String> helloCapabilities = const [];
  int subscriptions = 0;
  int peerListRequests = 0;
  HttpServer? _server;

  int get port => _server!.port;

  HostEndpoint get endpoint => HostEndpoint(addr: 'ws://127.0.0.1:$port/ws');

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server!.listen((request) async {
      if (request.method == 'GET' && request.uri.path == '/ws') {
        final ws = await WebSocketTransformer.upgrade(request);
        _sockets.add(ws);
        unawaited(_serve(ws));
      } else {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      }
    });
  }

  Future<void> stop() async {
    final server = _server;
    _server = null;
    if (server != null) await server.close(force: true);
    _sockets.clear();
  }

  Future<void> dropAll() async {
    final wsList = _sockets.toList(growable: false);
    _sockets.clear();
    for (final ws in wsList) {
      await ws.close();
    }
  }

  void sendPresence(List<String> online) {
    for (final ws in _sockets.toList(growable: false)) {
      ws.add(
        jsonEncode(
          PresenceMessage(
            online: online,
            at: DateTime.now().toUtc().millisecondsSinceEpoch,
          ).toJson(),
        ),
      );
    }
  }

  void relayToAll(Envelope envelope) {
    for (final ws in _sockets.toList(growable: false)) {
      ws.add(
        jsonEncode(
          EnvelopesMessage(envelopes: [envelope], done: false).toJson(),
        ),
      );
    }
  }

  Future<void> _serve(WebSocket ws) async {
    await for (final frame in ws) {
      final text = frame is String
          ? frame
          : utf8.decode(frame as List<int>);
      final decoded = jsonDecode(text);
      if (decoded is! Map<String, dynamic>) continue;
      final message = GossipMessage.fromJson(decoded);
      inbounds.add(message);
      switch (message) {
        case HelloMessage(:final capabilities, :final nonce):
          helloCount++;
          helloCapabilities = capabilities;
          if (garbageGreeting) {
            ws.add('this is not gossip json');
          } else {
            final caps = [
              if (trackerCapable) 'dtm-tracker',
              if (liveCapable) 'dtm-live',
            ];
            final identity = signer == null
                ? identityHex
                : await signer!.ed25519PublicKeyHex;
            final proof = signer == null || nonce == null
                ? null
                : await signHandshakeData(
                    signer!,
                    welcomeProofData(
                      nonce: nonce,
                      serverTime: 0,
                      identity: identity,
                      capabilities: caps,
                    ),
                  );
            ws.add(
              jsonEncode(
                WelcomeMessage(
                  serverTime: 0,
                  retentionSeconds: 3600,
                  maxEnvelopeSize: maxFrameBytes,
                  identity: identity,
                  capabilities: caps,
                  proof: proof,
                ).toJson(),
              ),
            );
          }
        case SubscribeMessage():
          subscriptions++;
          for (final batch in relayOnSubscribe) {
            ws.add(
              jsonEncode(EnvelopesMessage(envelopes: batch).toJson()),
            );
          }
        case PublishMessage(:final envelope):
          ws.add(
            jsonEncode(
              PublishedMessage(
                id: envelope.id,
                accepted: acceptPublished,
              ).toJson(),
            ),
          );
        case PublishLiveMessage(:final envelope):
          ws.add(
            jsonEncode(
              PublishedMessage(
                id: envelope.id,
                accepted: acceptPublished,
              ).toJson(),
            ),
          );
        case WantMessage():
          ws.add(jsonEncode(const HaveMessage(ids: []).toJson()));
        case PeerListRequestMessage():
          peerListRequests++;
          ws.add(
            jsonEncode(
              PeerListMessage(
                peers: peerListReply,
                hosts: hostListReply,
              ).toJson(),
            ),
          );
        case WelcomeMessage() ||
              EnvelopesMessage() ||
              PublishedMessage() ||
              HaveMessage() ||
              GetMessage() ||
              PeerListMessage() ||
              NetworkMessage() ||
              PresenceMessage():
          break;
      }
    }
  }
}

Future<void> _until(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException('condition not met within $timeout');
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}
import 'dart:async';
import 'dart:convert';

import 'package:dtm_app/core/crypto/envelope_crypto.dart';
import 'package:dtm_app/core/crypto/keypair.dart';
import 'package:dtm_app/core/security_limits.dart';
import 'package:dtm_app/core/storage/database.dart';
import 'package:dtm_app/core/storage/message_dao.dart';
import 'package:dtm_app/core/sync/envelope_processor.dart';
import 'package:dtm_app/core/sync/gossip.dart';
import 'package:dtm_app/core/transport/length_prefixed.dart';
import 'package:dtm_app/models/envelope.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GossipMessage parsing', () {
    test('round-trips every message type', () {
      final messages = <GossipMessage>[
        const HelloMessage(myPeerId: 'p1', capabilities: ['sync']),
        const WantMessage(since: 42),
        const HaveMessage(ids: ['a']),
        const GetMessage(ids: ['b']),
        const EnvelopesMessage(envelopes: []),
      ];
      for (final message in messages) {
        final restored = GossipMessage.fromJson(message.toJson());
        expect(restored.runtimeType, message.runtimeType);
      }
    });

    test('rejects unknown message types', () {
      expect(
        () => GossipMessage.fromJson(const {'type': 'EVIL'}),
        throwsFormatException,
      );
    });

    test('rejects oversized id lists', () {
      final ids = List<String>.generate(maxGossipItems + 1, (i) => '$i');
      expect(
        () => GossipMessage.fromJson({'type': 'HAVE', 'ids': ids}),
        throwsFormatException,
      );
      expect(
        () => GossipMessage.fromJson({'type': 'GET', 'ids': ids}),
        throwsFormatException,
      );
    });

    test('caps capabilities on HELLO', () {
      final caps = List<String>.generate(maxGossipItems + 1, (i) => '$i');
      expect(
        () => GossipMessage.fromJson({
          'type': 'HELLO',
          'myPeerId': 'p',
          'capabilities': caps,
        }),
        throwsFormatException,
      );
    });
  });

  group('GossipService.backfill', () {
    late AppDatabase serverDb;
    late AppDatabase clientDb;
    late MessageDao serverDao;
    late MessageDao clientDao;
    late DtmKeyPair sender;
    late DtmKeyPair clientKey;

    setUp(() async {
      serverDb = AppDatabase.inMemory();
      clientDb = AppDatabase.inMemory();
      serverDao = MessageDao(serverDb);
      clientDao = MessageDao(clientDb);
      sender = await DtmKeyPair.generate();
      clientKey = await DtmKeyPair.generate();
    });

    tearDown(() async {
      await serverDb.close();
      await clientDb.close();
    });

    test('transfers every missing envelope to the client', () async {
      final ids = <String>[];
      for (var i = 0; i < 3; i++) {
        final envelope = await createFor(clientKey, sender, 'msg $i');
        await serverDao.insertIfAbsent(envelope, source: 'p2p');
        ids.add(envelope.id);
      }

      final loop = _Loopback();
      final server = GossipService(
        dao: serverDao,
        processor: EnvelopeProcessor(identity: sender, dao: serverDao),
        myPeerId: 'server',
      );
      final clientProcessor = EnvelopeProcessor(
        identity: clientKey,
        dao: clientDao,
      );
      final client = GossipService(
        dao: clientDao,
        processor: clientProcessor,
        myPeerId: 'client',
      );

      final decrypted = <String>[];
      final sub = clientProcessor.onDecrypted.listen(
        (m) => decrypted.add(m.plaintext),
      );

      final serving = server.serve(loop.server);
      final accepted = await client.backfill(loop.client, since: 0);
      await loop.close();
      await serving;
      await Future<void>.delayed(Duration.zero);

      expect(accepted, 3);
      for (final id in ids) {
        expect(await clientDao.has(id), isTrue);
      }
      expect(decrypted.length, 3);
      await sub.cancel();
    });

    test('skips ids the client already has', () async {
      final have = await createFor(clientKey, sender, 'have');
      final missing = await createFor(clientKey, sender, 'missing');
      await serverDao.insertIfAbsent(have, source: 'p2p');
      await serverDao.insertIfAbsent(missing, source: 'p2p');
      await clientDao.insertIfAbsent(have, source: 'p2p');

      final loop = _Loopback();
      final server = GossipService(
        dao: serverDao,
        processor: EnvelopeProcessor(identity: sender, dao: serverDao),
        myPeerId: 'server',
      );
      final client = GossipService(
        dao: clientDao,
        processor: EnvelopeProcessor(identity: clientKey, dao: clientDao),
        myPeerId: 'client',
      );

      final serving = server.serve(loop.server);
      final accepted = await client.backfill(loop.client, since: 0);
      await loop.close();
      await serving;

      expect(accepted, 1);
      expect(await clientDao.has(missing.id), isTrue);
    });
  });

  group('GossipService.serve', () {
    late AppDatabase db;
    late MessageDao dao;

    setUp(() async {
      db = AppDatabase.inMemory();
      dao = MessageDao(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('answers HELLO and WANT, tolerates garbage frames', () async {
      final identity = await DtmKeyPair.generate();
      final service = GossipService(
        dao: dao,
        processor: EnvelopeProcessor(identity: identity, dao: dao),
        myPeerId: 'server',
      );
      final inbound = StreamController<List<int>>();
      final outbound = StreamController<List<int>>();
      final transport = (
        incoming: inbound.stream,
        send: (List<int> bytes) async {
          if (!outbound.isClosed) outbound.add(bytes);
        },
      );
      final received = <GossipMessage>[];
      final sub = outbound.stream.transform(LengthPrefixedDecoder()).listen((
        frame,
      ) {
        received.add(
          GossipMessage.fromJson(
            (jsonDecode(utf8.decode(frame)) as Map<dynamic, dynamic>)
                .cast<String, dynamic>(),
          ),
        );
      });

      final serving = service.serve(transport);
      inbound.add(framePayload(utf8.encode('not a gossip message')));
      inbound.add(
        framePayload(
          utf8.encode(jsonEncode(const HelloMessage(myPeerId: 'x').toJson())),
        ),
      );
      inbound.add(
        framePayload(
          utf8.encode(jsonEncode(const WantMessage(since: -5).toJson())),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await inbound.close();
      await serving;
      await Future<void>.delayed(Duration.zero);

      expect(received.whereType<HelloMessage>(), isNotEmpty);
      expect(received.whereType<HaveMessage>(), isNotEmpty);
      await sub.cancel();
      await outbound.close();
    });

    test('serves requested envelopes by id', () async {
      final identity = await DtmKeyPair.generate();
      final recipient = await DtmKeyPair.generate();
      final envelope = await createFor(recipient, identity, 'stored');
      await dao.insertIfAbsent(envelope, source: 'p2p');

      final service = GossipService(
        dao: dao,
        processor: EnvelopeProcessor(identity: identity, dao: dao),
        myPeerId: 'server',
      );
      final inbound = StreamController<List<int>>();
      final outbound = StreamController<List<int>>();
      final transport = (
        incoming: inbound.stream,
        send: (List<int> bytes) async {
          if (!outbound.isClosed) outbound.add(bytes);
        },
      );
      final received = <GossipMessage>[];
      final sub = outbound.stream.transform(LengthPrefixedDecoder()).listen((
        frame,
      ) {
        received.add(
          GossipMessage.fromJson(
            (jsonDecode(utf8.decode(frame)) as Map<dynamic, dynamic>)
                .cast<String, dynamic>(),
          ),
        );
      });

      final serving = service.serve(transport);
      inbound.add(
        framePayload(
          utf8.encode(jsonEncode(GetMessage(ids: [envelope.id]).toJson())),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await inbound.close();
      await serving;
      await Future<void>.delayed(Duration.zero);

      final responses = received.whereType<EnvelopesMessage>();
      expect(responses, isNotEmpty);
      expect(responses.first.envelopes.single.id, envelope.id);
      await sub.cancel();
      await outbound.close();
    });
  });
}

Future<Envelope> createFor(
  DtmKeyPair recipient,
  DtmKeyPair sender,
  String plaintext,
) async => createEnvelopeForPubKey(
  sender: sender,
  recipientX25519PubKeyHex: await recipient.x25519PublicKeyHex,
  plaintext: plaintext,
);

/// Two in-memory gossip endpoints wired to each other.
class _Loopback {
  final _clientToServer = StreamController<List<int>>();
  final _serverToClient = StreamController<List<int>>();

  late final GossipTransport client = (
    incoming: _serverToClient.stream,
    send: (List<int> bytes) async {
      if (!_clientToServer.isClosed) _clientToServer.add(bytes);
    },
  );

  late final GossipTransport server = (
    incoming: _clientToServer.stream,
    send: (List<int> bytes) async {
      if (!_serverToClient.isClosed) _serverToClient.add(bytes);
    },
  );

  Future<void> close() async {
    await _clientToServer.close();
    await _serverToClient.close();
  }
}

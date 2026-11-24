import 'dart:async';
import 'dart:convert' show base64Encode;

import 'package:dtm_app/core/crypto/envelope_crypto.dart';
import 'package:dtm_app/core/crypto/keypair.dart';
import 'package:dtm_app/core/security_limits.dart'
    show maxMediaPlaintextBytes;
import 'package:dtm_app/core/storage/database.dart';
import 'package:dtm_app/core/storage/message_dao.dart';
import 'package:dtm_app/core/sync/envelope_processor.dart';
import 'package:dtm_app/core/transport/transport.dart';
import 'package:dtm_app/models/envelope.dart';
import 'package:dtm_app/models/message_payload.dart';
import 'package:dtm_app/models/message_status.dart';
import 'package:dtm_app/models/peer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late MessageDao dao;
  late DtmKeyPair recipient;
  late DtmKeyPair sender;

  Future<int> storedCount() async {
    final rows = await db.select(db.messages).get();
    return rows.length;
  }

  setUp(() async {
    db = AppDatabase.inMemory();
    dao = MessageDao(db);
    recipient = await DtmKeyPair.generate();
    sender = await DtmKeyPair.generate();
  });

  tearDown(() async {
    await db.close();
  });

  group('EnvelopeProcessor pipeline', () {
    test(
      'a valid envelope is stored and decrypted for the recipient',
      () async {
        final processor = EnvelopeProcessor(identity: recipient, dao: dao);
        final decrypted = <String>[];
        final sub = processor.onDecrypted.listen(
          (m) => decrypted.add(m.plaintext),
        );

        final envelope = await createEnvelopeForPubKey(
          sender: sender,
          recipientX25519PubKeyHex: await recipient.x25519PublicKeyHex,
          plaintext: 'ping',
        );
        await processor.process(
          envelope,
          source: TransportSource.mesh,
          hops: 0,
        );

        await Future<void>.delayed(Duration.zero);
        expect(decrypted, ['ping']);
        expect(await storedCount(), 1);
        await sub.cancel();
      },
    );


    test('a blocked sender is dropped before storage and decryption',
        () async {
      final processor = EnvelopeProcessor(identity: recipient, dao: dao);
      final senderEd = await sender.ed25519PublicKeyHex;
      processor.blockFilter = (ed) => ed == senderEd;

      final decrypted = <String>[];
      final sub = processor.onDecrypted.listen(
        (message) => decrypted.add(message.plaintext),
      );

      final envelope = await createEnvelopeForPubKey(
        sender: sender,
        recipientX25519PubKeyHex: await recipient.x25519PublicKeyHex,
        plaintext: 'from a blocked contact',
      );
      await processor.process(envelope, source: TransportSource.mesh, hops: 0);

      await Future<void>.delayed(Duration.zero);
      expect(decrypted, isEmpty);
      expect(await storedCount(), 0);
      await sub.cancel();
    });

    test('unblocking lets the same sender through again', () async {
      final processor = EnvelopeProcessor(identity: recipient, dao: dao);
      final senderEd = await sender.ed25519PublicKeyHex;
      processor.blockFilter = (ed) => ed == senderEd;

      final envelope = await createEnvelopeForPubKey(
        sender: sender,
        recipientX25519PubKeyHex: await recipient.x25519PublicKeyHex,
        plaintext: 'second try',
      );
      await processor.process(envelope, source: TransportSource.mesh, hops: 0);
      expect(await storedCount(), 0);

      processor.blockFilter = (ed) => false;
      await processor.process(envelope, source: TransportSource.mesh, hops: 0);
      expect(await storedCount(), 1);
    });

    test('dedup: the same envelope is stored exactly once', () async {
      final processor = EnvelopeProcessor(identity: recipient, dao: dao);
      final envelope = await createEnvelopeForPubKey(
        sender: sender,
        recipientX25519PubKeyHex: await recipient.x25519PublicKeyHex,
        plaintext: 'same again',
      );

      await processor.process(envelope, source: TransportSource.mesh, hops: 0);
      await processor.process(envelope, source: TransportSource.p2p, hops: 0);

      expect(await storedCount(), 1);
    });

    test('tampered signature is dropped', () async {
      final processor = EnvelopeProcessor(identity: recipient, dao: dao);
      final envelope = await createEnvelopeForPubKey(
        sender: sender,
        recipientX25519PubKeyHex: await recipient.x25519PublicKeyHex,
        plaintext: 'signed',
      );
      final flipped = envelope.signature == '00'
          ? 'ff'
          : envelope.signature.replaceFirst('0', '1');

      await processor.process(
        Envelope(
          id: envelope.id,
          senderPubKey: envelope.senderPubKey,
          recipientPubKey: envelope.recipientPubKey,
          timestamp: envelope.timestamp,
          ciphertext: envelope.ciphertext,
          ephemeralPubKey: envelope.ephemeralPubKey,
          signature: flipped,
        ),
        source: TransportSource.p2p,
        hops: 0,
      );

      expect(await storedCount(), 0);
    });

    test('a mismatched envelope id is dropped', () async {
      final processor = EnvelopeProcessor(identity: recipient, dao: dao);
      final envelope = await createEnvelopeForPubKey(
        sender: sender,
        recipientX25519PubKeyHex: await recipient.x25519PublicKeyHex,
        plaintext: 'id check',
      );

      await processor.process(
        Envelope(
          id: 'f' * 64,
          senderPubKey: envelope.senderPubKey,
          recipientPubKey: envelope.recipientPubKey,
          timestamp: envelope.timestamp,
          ciphertext: envelope.ciphertext,
          ephemeralPubKey: envelope.ephemeralPubKey,
          signature: envelope.signature,
        ),
        source: TransportSource.p2p,
        hops: 0,
      );

      expect(await storedCount(), 0);
    });

    test('envelopes stamped too far in the future are rejected', () async {
      final processor = EnvelopeProcessor(identity: recipient, dao: dao);
      final future = DateTime.now()
          .toUtc()
          .add(const Duration(minutes: 30))
          .millisecondsSinceEpoch;
      final envelope = await createEnvelopeForPubKey(
        sender: sender,
        recipientX25519PubKeyHex: await recipient.x25519PublicKeyHex,
        plaintext: 'too early',
        timestamp: future,
      );

      await processor.process(envelope, source: TransportSource.p2p, hops: 0);
      expect(await storedCount(), 0);
    });

    test(
      'envelopes for someone else are relayed but never decrypted',
      () async {
        final thirdParty = await DtmKeyPair.generate();
        final processor = EnvelopeProcessor(identity: recipient, dao: dao);
        final decrypted = <String>[];
        final sub = processor.onDecrypted.listen(
          (m) => decrypted.add(m.plaintext),
        );

        final envelope = await createEnvelopeForPubKey(
          sender: sender,
          recipientX25519PubKeyHex: await thirdParty.x25519PublicKeyHex,
          plaintext: 'only for the third party',
        );
        await processor.process(envelope, source: TransportSource.p2p, hops: 0);

        await Future<void>.delayed(Duration.zero);
        expect(decrypted, isEmpty);
        expect(await storedCount(), 1, reason: 'relays store ciphertext only');
        await sub.cancel();
      },
    );

    test('relay forwards to other transports up to the hop limit', () async {
      final relay = RecordingTransport();
      final processor = EnvelopeProcessor(identity: recipient, dao: dao);
      processor.registerTransport(relay);

      final envelope = await createEnvelopeForPubKey(
        sender: sender,
        recipientX25519PubKeyHex: await recipient.x25519PublicKeyHex,
        plaintext: 'forward me',
      );
      await processor.process(envelope, source: TransportSource.mesh, hops: 0);
      expect(relay.sent, [envelope.id]);

      relay.sent.clear();
      await processor.process(envelope, source: TransportSource.mesh, hops: 5);
      expect(relay.sent, isEmpty);
    });

    test('sendText persists the outbound envelope', () async {
      final processor = EnvelopeProcessor(identity: recipient, dao: dao);
      final peer = await DtmKeyPair.generate();

      await processor.sendText(
        recipientXPubKey: await peer.x25519PublicKeyHex,
        plaintext: 'outbound',
      );

      expect(await storedCount(), 1);
    });

    test('sendText persists before a slow transport delivers', () async {
      final processor = EnvelopeProcessor(identity: recipient, dao: dao);
      final slow = SlowTransport();
      processor.registerTransport(slow);
      final peer = await DtmKeyPair.generate();

      // A transport that dials for seconds must not hold the stored message
      // and the UI refresh behind it.
      await processor
          .sendText(
            recipientXPubKey: await peer.x25519PublicKeyHex,
            plaintext: 'outbound',
          )
          .timeout(const Duration(seconds: 2));

      expect(await storedCount(), 1);
      expect(slow.started, isTrue);

      slow.complete();
      await Future<void>.delayed(Duration.zero);
    });

    test('a stalled transport neither blocks a healthy one nor the status',
        () async {
      final processor = EnvelopeProcessor(
        identity: recipient,
        dao: dao,
        sendTimeout: const Duration(milliseconds: 80),
      );
      final slow = SlowTransport();
      final fast = RecordingTransport();
      processor.registerTransport(slow);
      processor.registerTransport(fast);
      final peer = await DtmKeyPair.generate();

      final envelope = await processor.sendText(
        recipientXPubKey: await peer.x25519PublicKeyHex,
        plaintext: 'fast path',
      );
      await Future<void>.delayed(const Duration(milliseconds: 300));

      expect(fast.sent, contains(envelope.id));
      expect(await dao.statusFor(envelope.id), MessageStatus.sent);
      slow.complete();
    });

    test('when every transport stalls the envelope stays queued', () async {
      final processor = EnvelopeProcessor(
        identity: recipient,
        dao: dao,
        sendTimeout: const Duration(milliseconds: 60),
      );
      final slow = SlowTransport();
      processor.registerTransport(slow);
      final peer = await DtmKeyPair.generate();

      final envelope = await processor.sendText(
        recipientXPubKey: await peer.x25519PublicKeyHex,
        plaintext: 'no route',
      );
      await Future<void>.delayed(const Duration(milliseconds: 250));

      expect(await dao.statusFor(envelope.id), MessageStatus.queued);
      slow.complete();
    });

    test('sendText reaches a running transport in the background', () async {
      final processor = EnvelopeProcessor(identity: recipient, dao: dao);
      final recorder = RecordingTransport();
      processor.registerTransport(recorder);
      final peer = await DtmKeyPair.generate();

      final envelope = await processor.sendText(
        recipientXPubKey: await peer.x25519PublicKeyHex,
        plaintext: 'outbound',
      );

      await Future<void>.delayed(Duration.zero);
      expect(recorder.sent, [envelope.id]);
    });
  });

  group('control classification', () {
    test('a receipt addressed to us is control, never a chat bubble', () async {
      final processor = EnvelopeProcessor(identity: recipient, dao: dao);
      final decrypted = <String>[];
      final receipts = <String>[];
      final stored = <String>[];
      final s1 =
          processor.onDecrypted.listen((m) => decrypted.add(m.plaintext));
      final s2 = processor.onReceipt.listen((m) => receipts.add(m.plaintext));
      final s3 =
          processor.onEnvelopeStored.listen((e) => stored.add(e.id));

      final envelope = await createEnvelopeForPubKey(
        sender: sender,
        recipientX25519PubKeyHex: await recipient.x25519PublicKeyHex,
        plaintext: MessagePayload.composeReceipt(
          kind: ReceiptKind.delivered,
          ids: ['a' * 64],
        ),
      );
      await processor.process(envelope, source: TransportSource.p2p, hops: 0);
      await Future<void>.delayed(Duration.zero);

      expect(receipts, hasLength(1));
      expect(decrypted, isEmpty);
      expect(stored, isEmpty, reason: 'a receipt must not refresh a chat');
      expect(await dao.isControl(envelope.id), isTrue);
      await s1.cancel();
      await s2.cancel();
      await s3.cancel();
    });

    test('an ordinary message is stored and decrypted, never a receipt',
        () async {
      final processor = EnvelopeProcessor(identity: recipient, dao: dao);
      final decrypted = <String>[];
      final receipts = <String>[];
      final stored = <String>[];
      final s1 =
          processor.onDecrypted.listen((m) => decrypted.add(m.plaintext));
      final s2 = processor.onReceipt.listen((m) => receipts.add(m.plaintext));
      final s3 =
          processor.onEnvelopeStored.listen((e) => stored.add(e.id));

      final envelope = await createEnvelopeForPubKey(
        sender: sender,
        recipientX25519PubKeyHex: await recipient.x25519PublicKeyHex,
        plaintext: 'hello',
      );
      await processor.process(envelope, source: TransportSource.p2p, hops: 0);
      await Future<void>.delayed(Duration.zero);

      expect(decrypted, ['hello']);
      expect(receipts, isEmpty);
      expect(stored, [envelope.id]);
      expect(await dao.isControl(envelope.id), isFalse);
      await s1.cancel();
      await s2.cancel();
      await s3.cancel();
    });
  });

  group('outbound delivery status', () {
    test('no transport leaves the message queued', () async {
      final processor = EnvelopeProcessor(identity: recipient, dao: dao);
      final peer = await DtmKeyPair.generate();

      final envelope = await processor.sendText(
        recipientXPubKey: await peer.x25519PublicKeyHex,
        plaintext: 'offline',
      );
      await Future<void>.delayed(Duration.zero);

      expect(await dao.statusFor(envelope.id), MessageStatus.queued);
    });

    test('an accepted message becomes sent', () async {
      final processor = EnvelopeProcessor(identity: recipient, dao: dao);
      processor.registerTransport(RecordingTransport());
      final peer = await DtmKeyPair.generate();

      final envelope = await processor.sendText(
        recipientXPubKey: await peer.x25519PublicKeyHex,
        plaintext: 'online',
      );
      await Future<void>.delayed(Duration.zero);

      expect(await dao.statusFor(envelope.id), MessageStatus.sent);
    });

    test('redispatch flips a queued envelope once a transport accepts',
        () async {
      final processor = EnvelopeProcessor(identity: recipient, dao: dao);
      final peer = await DtmKeyPair.generate();
      final envelope = await processor.sendText(
        recipientXPubKey: await peer.x25519PublicKeyHex,
        plaintext: 'later',
      );
      await Future<void>.delayed(Duration.zero);
      expect(await dao.statusFor(envelope.id), MessageStatus.queued);

      final recorder = RecordingTransport();
      processor.registerTransport(recorder);
      await processor.redispatch(envelope);

      expect(recorder.sent, [envelope.id]);
      expect(await dao.statusFor(envelope.id), MessageStatus.sent);
    });

    test('a transition is announced on onStatusChanged', () async {
      final processor = EnvelopeProcessor(identity: recipient, dao: dao);
      processor.registerTransport(RecordingTransport());
      final seen = <String>[];
      final sub = processor.onStatusChanged.listen(seen.add);
      final peer = await DtmKeyPair.generate();

      final envelope = await processor.sendText(
        recipientXPubKey: await peer.x25519PublicKeyHex,
        plaintext: 'announce',
      );
      await Future<void>.delayed(Duration.zero);

      expect(seen, contains(envelope.id));
      await sub.cancel();
    });
  });

  group('outbound media', () {
    String b64(int len) => base64Encode(List<int>.filled(len, 9));

    test('a media container is wrapped in one envelope and stored', () async {
      final processor = EnvelopeProcessor(identity: recipient, dao: dao);
      final peer = await DtmKeyPair.generate();
      final peerX = await peer.x25519PublicKeyHex;

      final plaintext = MessagePayload.composeMediaDirect(
        senderX: await recipient.x25519PublicKeyHex,
        blobId: 'b' * 64,
        kind: MediaKind.voice,
        mime: 'audio/mp4',
        byteCount: 512,
        durationMs: 3000,
        dataBase64: b64(512),
      );

      final envelope = await processor.sendMedia(
        recipientXPubKey: peerX,
        plaintext: plaintext,
      );

      expect(await dao.has(envelope.id), isTrue);
      final stored = await dao.envelopeById(envelope.id);
      expect(stored, isNotNull);
      expect(await stored!.verify(), isTrue);
      expect(await stored.hasValidId(), isTrue);
    });

    test('the media envelope decrypts to the same container', () async {
      final processor = EnvelopeProcessor(identity: recipient, dao: dao);
      final peer = await DtmKeyPair.generate();
      final peerX = await peer.x25519PublicKeyHex;
      final plaintext = MessagePayload.composeMediaDirect(
        senderX: await recipient.x25519PublicKeyHex,
        blobId: 'b' * 64,
        kind: MediaKind.photo,
        mime: 'image/jpeg',
        byteCount: 64,
        durationMs: 0,
        dataBase64: b64(64),
      );

      final envelope = await processor.sendMedia(
        recipientXPubKey: peerX,
        plaintext: plaintext,
      );

      final clear = await decryptPayload(
        envelope: envelope,
        recipientX25519KeyPair: peer.xKeyPair,
        senderEd25519PubKeyHex: envelope.senderPubKey,
      );
      expect(clear, plaintext);
      final parsed = MessagePayload.parse(clear!);
      expect(parsed, isA<MediaPayload>());
      expect((parsed as MediaPayload).kind, MediaKind.photo);
    });

    test('a media container over the cap is rejected before sending',
        () async {
      final processor = EnvelopeProcessor(identity: recipient, dao: dao);
      final peer = await DtmKeyPair.generate();
      final peerX = await peer.x25519PublicKeyHex;

      // A raw blob at the ceiling encodes to more than the container cap
      // only when the base64 expansion is accounted for; build a string
      // that is unambiguously over the limit.
      final huge = 'x' * (maxMediaPlaintextBytes + 1);
      expect(
        () => processor.sendMedia(
          recipientXPubKey: peerX,
          plaintext: huge,
        ),
        throwsArgumentError,
      );
    });

    test('a malformed recipient key is rejected', () async {
      final processor = EnvelopeProcessor(identity: recipient, dao: dao);
      expect(
        () => processor.sendMedia(
          recipientXPubKey: 'nothex',
          plaintext: 'm1 ...',
        ),
        throwsArgumentError,
      );
    });

    test('a media send becomes sent once a transport accepts', () async {
      final processor = EnvelopeProcessor(identity: recipient, dao: dao);
      processor.registerTransport(RecordingTransport());
      final peer = await DtmKeyPair.generate();
      final peerX = await peer.x25519PublicKeyHex;
      final plaintext = MessagePayload.composeMediaDirect(
        senderX: await recipient.x25519PublicKeyHex,
        blobId: 'b' * 64,
        kind: MediaKind.voice,
        mime: 'audio/mp4',
        byteCount: 32,
        durationMs: 1000,
        dataBase64: b64(32),
      );

      final envelope = await processor.sendMedia(
        recipientXPubKey: peerX,
        plaintext: plaintext,
      );
      await Future<void>.delayed(Duration.zero);

      expect(await dao.statusFor(envelope.id), MessageStatus.sent);
    });

    test('a refused dispatch stays queued and a retry really retries',
        () async {
      final processor = EnvelopeProcessor(identity: recipient, dao: dao);
      final transport = FlakyTransport(failures: 1);
      processor.registerTransport(transport);
      final peer = await DtmKeyPair.generate();
      final peerX = await peer.x25519PublicKeyHex;

      final envelope = await processor.sendText(
        recipientXPubKey: peerX,
        plaintext: 'offline now',
      );
      await Future<void>.delayed(Duration.zero);

      expect(await dao.statusFor(envelope.id), MessageStatus.queued);

      expect(await processor.redispatch(envelope), isTrue);
      expect(await dao.statusFor(envelope.id), MessageStatus.sent);
      expect(transport.attempts, 2);
    });
  });

  group('direct-only priority', () {
    test('prefers p2p over mesh and the relay', () async {
      final p2p = NamedTransport('p2p');
      final mesh = NamedTransport('mesh');
      final host = NamedTransport('host');
      final processor = EnvelopeProcessor(identity: recipient, dao: dao);
      processor
        ..registerTransport(host)
        ..registerTransport(mesh)
        ..registerTransport(p2p);

      await processor.sendMedia(
        recipientXPubKey: await recipient.x25519PublicKeyHex,
        plaintext: 'slice',
        directOnly: true,
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(p2p.sent, hasLength(1));
      expect(mesh.sent, isEmpty);
      expect(host.sent, isEmpty);
    });

    test('falls back to mesh when p2p is unreachable', () async {
      final p2p = NamedTransport('p2p', accept: false);
      final mesh = NamedTransport('mesh');
      final host = NamedTransport('host');
      final processor = EnvelopeProcessor(identity: recipient, dao: dao);
      processor
        ..registerTransport(p2p)
        ..registerTransport(mesh)
        ..registerTransport(host);

      await processor.sendMedia(
        recipientXPubKey: await recipient.x25519PublicKeyHex,
        plaintext: 'slice',
        directOnly: true,
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(p2p.sent, isEmpty);
      expect(mesh.sent, hasLength(1));
      expect(host.sent, isEmpty);
    });

    test('probes p2p once and sends the other slices to the relay',
        () async {
      final p2p = HangingTransport();
      final host = NamedTransport('host');
      final processor = EnvelopeProcessor(
        identity: recipient,
        dao: dao,
        directProbe: const Duration(milliseconds: 30),
        directCooldown: const Duration(seconds: 10),
      );
      processor
        ..registerTransport(p2p)
        ..registerTransport(host);

      for (var i = 0; i < 3; i++) {
        await processor.sendMedia(
          recipientXPubKey: await recipient.x25519PublicKeyHex,
          plaintext: 'slice $i',
          directOnly: true,
        );
      }
      await Future<void>.delayed(const Duration(milliseconds: 120));

      expect(
        p2p.attempts,
        1,
        reason: 'a second dial would queue behind the first for 20+ seconds',
      );
      expect(host.sent, hasLength(3));
    });

    test('re-probes p2p after the cooldown expires', () async {
      final p2p = HangingTransport();
      final host = NamedTransport('host');
      final processor = EnvelopeProcessor(
        identity: recipient,
        dao: dao,
        directProbe: const Duration(milliseconds: 20),
        directCooldown: const Duration(milliseconds: 40),
      );
      processor
        ..registerTransport(p2p)
        ..registerTransport(host);

      await processor.sendMedia(
        recipientXPubKey: await recipient.x25519PublicKeyHex,
        plaintext: 'first',
        directOnly: true,
      );
      await Future<void>.delayed(const Duration(milliseconds: 60));
      await processor.sendMedia(
        recipientXPubKey: await recipient.x25519PublicKeyHex,
        plaintext: 'second',
        directOnly: true,
      );
      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(p2p.attempts, 2);
      expect(host.sent, hasLength(2));
    });

    test('falls back to the live relay when p2p and mesh are unreachable',
        () async {
      final p2p = NamedTransport('p2p', accept: false);
      final mesh = NamedTransport('mesh', accept: false);
      final host = NamedTransport('host');
      final processor = EnvelopeProcessor(identity: recipient, dao: dao);
      processor
        ..registerTransport(p2p)
        ..registerTransport(mesh)
        ..registerTransport(host);

      await processor.sendMedia(
        recipientXPubKey: await recipient.x25519PublicKeyHex,
        plaintext: 'slice',
        directOnly: true,
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(p2p.sent, isEmpty);
      expect(mesh.sent, isEmpty);
      expect(host.sent, hasLength(1));
    });
  });
}

/// Minimal transport stub that records every envelope it is asked to send.
class RecordingTransport implements Transport {
  final List<String> sent = [];

  @override
  Stream<DtmPeer> get peers => const Stream.empty();

  @override
  bool get isRunning => true;

  @override
  String get name => 'recorder';

  @override
  void setEnvelopeSink(EnvelopeSink sink) {}

  @override
  Future<void> start({
    required String myEdPubKey,
    required String myXPubKey,
    required String displayName,
  }) async {}

  @override
  Future<void> stop() async {}

  @override
  Future<bool> send(Envelope envelope, {bool directOnly = false}) async {
    sent.add(envelope.id);
    return true;
  }
}

/// A p2p transport whose dial never completes, like a peer behind a NAT that
/// silently drops the handshake.
class HangingTransport extends RecordingTransport {
  int attempts = 0;

  @override
  String get name => 'p2p';

  @override
  Future<bool> send(Envelope envelope, {bool directOnly = false}) {
    attempts++;
    return Completer<bool>().future;
  }
}

class NamedTransport extends RecordingTransport {
  NamedTransport(this.label, {this.accept = true});

  final String label;
  final bool accept;

  @override
  String get name => label;

  @override
  Future<bool> send(Envelope envelope, {bool directOnly = false}) async {
    if (!accept) return false;
    sent.add(envelope.id);
    return true;
  }
}

/// Transport that refuses the first [failures] attempts and accepts afterwards,
/// modelling a dial that fails while the peer is unreachable.
class FlakyTransport implements Transport {
  FlakyTransport({this.failures = 1});

  final int failures;
  int attempts = 0;

  @override
  Stream<DtmPeer> get peers => const Stream.empty();

  @override
  bool get isRunning => true;

  @override
  String get name => 'flaky';

  @override
  void setEnvelopeSink(EnvelopeSink sink) {}

  @override
  Future<void> start({
    required String myEdPubKey,
    required String myXPubKey,
    required String displayName,
  }) async {}

  @override
  Future<void> stop() async {}

  @override
  Future<bool> send(Envelope envelope, {bool directOnly = false}) async {
    attempts++;
    return attempts > failures;
  }
}

/// Transport whose [send] blocks until released, modelling a dial that takes
/// seconds. Used to prove an outbound message is persisted and shown before the
/// network step returns.
class SlowTransport implements Transport {
  final Completer<void> _gate = Completer<void>();
  bool started = false;

  @override
  Stream<DtmPeer> get peers => const Stream.empty();

  @override
  bool get isRunning => true;

  @override
  String get name => 'slow';

  @override
  void setEnvelopeSink(EnvelopeSink sink) {}

  @override
  Future<void> start({
    required String myEdPubKey,
    required String myXPubKey,
    required String displayName,
  }) async {}

  @override
  Future<void> stop() async {}

  @override
  Future<bool> send(Envelope envelope, {bool directOnly = false}) async {
    started = true;
    await _gate.future;
    return true;
  }

  void complete() {
    if (!_gate.isCompleted) _gate.complete();
  }
}

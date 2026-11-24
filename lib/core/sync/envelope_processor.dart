import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;

import '../../models/envelope.dart';
import '../../models/message_payload.dart'
    show FileChunkPayload, FileRequestPayload, MessagePayload, ReceiptPayload;
import '../../models/message_status.dart';
import '../crypto/envelope_crypto.dart';
import '../crypto/keypair.dart';
import '../security_limits.dart'
    show
        directProbeCooldown,
        directProbeTimeout,
        maxMediaPlaintextBytes,
        maxPlaintextBytes,
        transportBulkSendTimeout,
        transportSendTimeout;
import '../storage/message_dao.dart';
import '../transport/transport.dart';

/// A decrypted inbound message, delivered only on the recipient's device.
class DecryptedMessage {
  final String id;
  final String senderPubKey;
  final String recipientPubKey;
  final int timestamp;
  final String plaintext;

  const DecryptedMessage({
    required this.id,
    required this.senderPubKey,
    required this.recipientPubKey,
    required this.timestamp,
    required this.plaintext,
  });
}

/// Maximum ladder a relay is willing to forward an envelope.
const int maxRelayHops = 5;

/// Central pipeline for every envelope, regardless of transport.
///
/// Order (crypto-envelope skill): verify signature → recompute id → dedup
/// (storage also cross-checks the chain link) → decrypt. Relaying only
/// happens after a clean verify; plaintext never leaves this device through
/// any transport.
class EnvelopeProcessor implements EnvelopeSink {
  final DtmKeyPair identity;
  final MessageDao dao;
  final Duration _sendTimeout;
  final Duration _directProbeTimeout;
  final Duration _directProbeCooldown;
  final List<Transport> _transports = [];

  /// One direct p2p probe per recipient, not one per slice. Dials to an
  /// unreachable peer serialise and each can take tens of seconds, which is
  /// exactly how a 2 MB file turned into a five-minute transfer.
  final Map<String, _DirectGate> _directGates = {};

  final _onDecrypted = StreamController<DecryptedMessage>.broadcast();
  final _onEnvelopeStored = StreamController<Envelope>.broadcast();
  final _onReceipt = StreamController<DecryptedMessage>.broadcast();
  final _onStatusChanged = StreamController<String>.broadcast();
  bool _disposed = false;

  EnvelopeProcessor({
    required this.identity,
    required this.dao,
    Duration sendTimeout = transportSendTimeout,
    Duration directProbe = directProbeTimeout,
    Duration directCooldown = directProbeCooldown,
  }) : _sendTimeout = sendTimeout,
       _directProbeTimeout = directProbe,
       _directProbeCooldown = directCooldown;

  String? _myXPubKey;
  String? _myEdPubKey;

  Future<String> get myXPubKey async =>
      _myXPubKey ??= await identity.x25519PublicKeyHex;

  Future<String> get myEdPubKey async =>
      _myEdPubKey ??= await identity.ed25519PublicKeyHex;

  /// Plaintext delivered only for envelopes addressed to this device.
  Stream<DecryptedMessage> get onDecrypted => _onDecrypted.stream;

  /// Every successfully verified & stored envelope (for UI refresh).
  Stream<Envelope> get onEnvelopeStored => _onEnvelopeStored.stream;

  /// Local block list. Envelopes signed by these Ed25519 keys are dropped
  /// right after verification, before they are stored, decrypted or relayed.
  bool Function(String senderEdPubKey)? blockFilter;

  /// Receipt plaintext (delivery/read) addressed to this device. A receipt is
  /// stored for dedup but flagged control, so it never reaches [onDecrypted]
  /// nor [onEnvelopeStored] and can never render as a chat bubble.
  Stream<DecryptedMessage> get onReceipt => _onReceipt.stream;

  /// The id of an outgoing envelope whose delivery status just advanced.
  Stream<String> get onStatusChanged => _onStatusChanged.stream;

  void registerTransport(Transport transport) {
    _transports.add(transport);
    transport.setEnvelopeSink(this);
  }

  @override
  Future<void> process(
    Envelope envelope, {
    required TransportSource source,
    required int hops,
  }) async {
    // Pre-filter: envelopes stamped more than 5 minutes in the future are
    // rejected outright (clock-skew guard).
    if (!envelope.withinSkew()) {
      return;
    }

    // 1. Verify Ed25519 signature against senderPubKey.
    if (!await envelope.verify()) {
      return;
    }

    // 2. Recompute the id and compare.
    if (!await envelope.hasValidId()) {
      return;
    }

    // 2b. A blocked contact is dropped here: nothing is stored, decrypted or
    // relayed for a sender the user blocked.
    if (blockFilter?.call(envelope.senderPubKey) ?? false) {
      return;
    }

    // 3. Dedup: INSERT OR IGNORE — false means we have seen it already.
    final inserted = await dao.insertIfAbsent(
      envelope,
      source: source.name,
      hops: hops,
    );
    if (!inserted) {
      return;
    }

    // 4. If addressed to us, decrypt and classify: a receipt is flagged
    // control and routed away from the chat streams, everything else is a
    // normal message. Empty/failed decryption is never treated as control.
    var control = false;
    DecryptedMessage? message;
    if (envelope.recipientPubKey == await myXPubKey) {
      final plaintext = await decryptPayload(
        envelope: envelope,
        recipientX25519KeyPair: identity.xKeyPair,
        senderEd25519PubKeyHex: envelope.senderPubKey,
      );
      if (plaintext != null) {
        message = DecryptedMessage(
          id: envelope.id,
          senderPubKey: envelope.senderPubKey,
          recipientPubKey: envelope.recipientPubKey,
          timestamp: envelope.timestamp,
          plaintext: plaintext,
        );
        final payload = MessagePayload.parse(plaintext);
        control = payload is ReceiptPayload;
        if (control) {
          await dao.markControl(envelope.id);
        } else if (payload is FileChunkPayload ||
            payload is FileRequestPayload) {
          // A transfer slice or a chunk request is control data:
          // control-flagged so it never renders as a bubble nor counts as
          // unread, but still announced to the controller so it can feed the
          // assembler or answer a holder.
          await dao.markControl(envelope.id);
        }
      }
    }

    if (control) {
      _onReceipt.add(message!);
    } else {
      _onEnvelopeStored.add(envelope);
      if (message != null) _onDecrypted.add(message);
    }

    // 5. Relay to every other transport while the hop ladder allows it.
    if (hops >= maxRelayHops) {
      return;
    }
    for (final transport in _transports) {
      if (transport.name == source.name) continue;
      if (!transport.isRunning) continue;
      try {
        await transport.send(envelope);
      } catch (_) {
        // Relay best-effort — a transport failure must not crash the pipeline.
      }
    }
  }

  /// Composes and signs an envelope for [recipientXPubKey] then pushes it to
  /// every transport.
  Future<Envelope> sendText({
    required String recipientXPubKey,
    required String plaintext,
  }) async {
    if (!isHexOfLength(recipientXPubKey, 32)) {
      throw ArgumentError('Recipient public key must be 32-byte hex');
    }
    if (utf8.encode(plaintext).length > maxPlaintextBytes) {
      throw ArgumentError(
        'Plaintext exceeds the $maxPlaintextBytes-byte limit',
      );
    }
    final chainLink = await dao.chainLinkFor(
      await myEdPubKey,
      recipientXPubKey,
    );
    final envelope = await createEnvelopeForPubKey(
      sender: identity,
      recipientX25519PubKeyHex: recipientXPubKey,
      plaintext: plaintext,
      chainLink: chainLink,
    );

    // Persist and announce our own outbound envelope before touching the
    // network: a dial can take seconds, and the message must appear (and
    // survive a restart) without waiting for it.
    await dao.insertIfAbsent(envelope, source: 'local', hops: 0);
    await dao.setStatus(envelope.id, MessageStatus.queued);
    _onEnvelopeStored.add(envelope);

    // Relay best-effort in the background: a transport failure must not crash
    // the pipeline nor delay the caller.
    unawaited(_dispatchAndRecord(envelope));
    return envelope;
  }

  /// Composes and signs an envelope carrying a media container for
  /// [recipientXPubKey] then pushes it to every transport.
  ///
  /// Media containers are binary-safe: the container string is encrypted as
  /// bytes, never round-tripped through a UTF-8 decode. The container ceiling
  /// is [maxMediaPlaintextBytes], deliberately separate from the text limit.
  Future<Envelope> sendMedia({
    required String recipientXPubKey,
    required String plaintext,
    bool directOnly = false,
    bool control = false,
  }) async {
    if (!isHexOfLength(recipientXPubKey, 32)) {
      throw ArgumentError('Recipient public key must be 32-byte hex');
    }
    final bytes = utf8.encode(plaintext);
    if (bytes.length > maxMediaPlaintextBytes) {
      throw ArgumentError(
        'Media container exceeds the $maxMediaPlaintextBytes-byte limit',
      );
    }
    final chainLink = await dao.chainLinkFor(
      await myEdPubKey,
      recipientXPubKey,
    );
    final envelope = await createEnvelopeBytesForPubKey(
      sender: identity,
      recipientX25519PubKeyHex: recipientXPubKey,
      plaintextBytes: bytes,
      chainLink: chainLink,
    );

    await dao.insertIfAbsent(envelope, source: 'local', hops: 0);
    if (control) await dao.markControl(envelope.id);
    if (directOnly) await dao.markDirectOnly(envelope.id);
    await dao.setStatus(envelope.id, MessageStatus.queued);
    _onEnvelopeStored.add(envelope);

    unawaited(_dispatchAndRecord(envelope));
    return envelope;
  }

  /// Re-pushes an already stored envelope whose status is still below `sent`
  /// (the retry pass). Never re-inserts; only advances the status.
  Future<bool> redispatch(Envelope envelope) => _dispatchAndRecord(envelope);

  Future<bool> _dispatchAndRecord(Envelope envelope) async {
    final sent = await _dispatchOutbound(envelope);
    if (_disposed) return sent;
    try {
      await dao.setStatus(
        envelope.id,
        sent ? MessageStatus.sent : MessageStatus.queued,
      );
    } catch (_) {
      return sent;
    }
    if (!_onStatusChanged.isClosed) _onStatusChanged.add(envelope.id);
    return sent;
  }

  /// Pushes an envelope to every running transport concurrently, ignoring
  /// per-transport failures. Returns whether at least one accepted it.
  ///
  /// Concurrency matters for perceived latency: a stalled p2p dial must not
  /// hold the relay copy (and the delivery status) behind it. Each transport is
  /// given [_sendTimeout]; a slow one is treated as a miss for this attempt.
  Future<bool> _dispatchOutbound(Envelope envelope) async {
    // A direct-only envelope (a media slice) must never be *stored* by a relay
    // host: hosts keep envelopes for offline delivery, and a file would then
    // sit on the relay instead of waiting for the sender to come online.
    // HostTransport.send(directOnly:) therefore publishes live (PUBLISH_LIVE),
    // which the relay forwards to a connected subscriber without persisting.
    final directOnly = await dao.isDirectOnly(envelope.id);
    final running = _transports.where((t) => t.isRunning).toList();
    for (final transport in _transports) {
      if (!transport.isRunning) {
        debugPrint('[dispatch] ${transport.name} skipped (not running)');
      }
    }
    if (running.isEmpty) {
      debugPrint('[dispatch] env=${envelope.id} accepted=false');
      return false;
    }
    final bulk = directOnly && envelope.ciphertext.length > 4096;
    final timeout = bulk ? transportBulkSendTimeout : _sendTimeout;
    if (directOnly) {
      // Strict preference: a direct libp2p stream first, then the offline
      // mesh, and only then the relay's live (never stored) forward. Sending
      // in parallel would put every media slice on the relay even when the
      // peers can reach each other directly.
      final byName = {for (final t in running) t.name: t};
      const known = ['p2p', 'mesh', 'host'];
      final ordered = <Transport>[
        for (final name in known)
          if (byName[name] != null) byName[name]!,
        for (final t in running)
          if (!known.contains(t.name)) t,
      ];
      for (final transport in ordered) {
        final isP2p = transport.name == 'p2p';
        if (isP2p &&
            !_mayProbeDirect(envelope.recipientPubKey, DateTime.now())) {
          debugPrint('[dispatch] p2p direct skipped (recently unreachable)');
          continue;
        }
        try {
          final ok = await transport
              .send(envelope, directOnly: true)
              .timeout(isP2p ? _directProbeTimeout : timeout);
          if (isP2p) _noteDirectProbe(envelope.recipientPubKey, ok);
          debugPrint('[dispatch] ${transport.name} direct accepted=$ok');
          if (ok) return true;
        } catch (e) {
          if (isP2p) _noteDirectProbe(envelope.recipientPubKey, false);
          debugPrint('[dispatch] ${transport.name} direct error=$e');
        }
      }
      return false;
    }
    final results = await Future.wait(
      running.map((transport) async {
        try {
          final ok = await transport
              .send(envelope, directOnly: directOnly)
              .timeout(
            timeout,
            onTimeout: () {
              debugPrint('[dispatch] ${transport.name} timed out');
              return false;
            },
          );
          debugPrint('[dispatch] ${transport.name} accepted=$ok');
          return ok;
        } catch (e) {
          debugPrint('[dispatch] ${transport.name} error=$e');
          return false;
        }
      }),
    );
    final accepted = results.any((ok) => ok);
    debugPrint('[dispatch] env=${envelope.id} accepted=$accepted');
    return accepted;
  }

  /// Whether this slice may start a direct p2p attempt. Only one attempt is
  /// allowed at a time per recipient; while it is in flight the other slices
  /// go straight to the next transport instead of queueing up behind it.
  bool _mayProbeDirect(String recipient, DateTime now) {
    var gate = _directGates[recipient];
    if (gate == null) {
      gate = _DirectGate(probingUntil: now.add(_directProbeTimeout));
      _directGates[recipient] = gate;
      return true;
    }
    final down = gate.downUntil;
    if (down != null) {
      if (now.isBefore(down)) return false;
      gate.downUntil = null;
    }
    final probing = gate.probingUntil;
    if (probing != null && now.isBefore(probing)) return false;
    gate.probingUntil = now.add(_directProbeTimeout);
    return true;
  }

  /// Records the outcome of a direct probe. A success clears the gate so p2p
  /// keeps its priority; a failure closes it for [_directProbeCooldown], and
  /// the slices fall through to the live relay until it expires.
  void _noteDirectProbe(String recipient, bool ok) {
    if (ok) {
      _directGates.remove(recipient);
      return;
    }
    var gate = _directGates[recipient];
    if (gate == null) {
      gate = _DirectGate();
      _directGates[recipient] = gate;
    }
    gate.probingUntil = null;
    gate.downUntil = DateTime.now().add(_directProbeCooldown);
    if (_directGates.length > 256) {
      final now = DateTime.now();
      _directGates.removeWhere(
        (_, g) => g.downUntil == null || g.downUntil!.isBefore(now),
      );
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    await _onDecrypted.close();
    await _onEnvelopeStored.close();
    await _onReceipt.close();
    await _onStatusChanged.close();
  }
}


/// Direct-dial state for one recipient. [probingUntil] bounds a single
/// in-flight probe; [downUntil] is the cooldown after a failed one.
class _DirectGate {
  DateTime? probingUntil;
  DateTime? downUntil;

  _DirectGate({this.probingUntil});
}

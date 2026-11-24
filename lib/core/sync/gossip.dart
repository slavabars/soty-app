import 'dart:async';
import 'dart:convert';

import '../../models/envelope.dart';
import '../security_limits.dart' as limits;
import '../storage/message_dao.dart';
import '../transport/length_prefixed.dart';
import '../transport/transport.dart' show TransportSource;
import 'envelope_processor.dart';
import 'gossip_message.dart';

export 'gossip_message.dart'
    show
      EnvelopesMessage,
      GetMessage,
      GossipMessage,
      HaveMessage,
      HelloMessage,
      PublishMessage,
      PublishedMessage,
      SubscribeMessage,
      WantMessage,
      WelcomeMessage;

/// A bidirectional exchange boundary. In production it is backed by a libp2p
/// stream; in tests by in-memory controllers.
typedef GossipTransport = ({
  Stream<List<int>> incoming,
  Future<void> Function(List<int> bytes) send,
});

/// Implements the server half (HAVE/ENVELOPES) and the client half
/// (backfill) of the gossip protocol.
class GossipService {
  final MessageDao dao;
  final EnvelopeProcessor processor;
  final String myPeerId;

  GossipService({
    required this.dao,
    required this.processor,
    required this.myPeerId,
  });

  /// Server-side loop over one control stream.
  Future<void> serve(GossipTransport transport) async {
    final stream = transport.incoming.transform(LengthPrefixedDecoder());
    final outgoing = _Outgoing(transport.send);
    outgoing.send(HelloMessage(myPeerId: myPeerId));

    await for (final frame in stream) {
      final message = _tryDecode(frame);
      if (message == null) continue;
      switch (message) {
        case HelloMessage():
          outgoing.send(HelloMessage(myPeerId: myPeerId));
        case WantMessage(:final since):
          final now = DateTime.now().toUtc().millisecondsSinceEpoch;
          // Clamp hostile/extreme scan windows (H4 in the audit).
          final sinceClamped = since < 0
              ? 0
              : now - since > limits.gossipMaxScanWindow
              ? now - limits.gossipMaxScanWindow
              : since;
          outgoing.send(
            HaveMessage(
              ids: await dao.idsSince(
                sinceClamped,
                limit: limits.maxGossipItems,
              ),
            ),
          );
        case GetMessage(:final ids):
          final envelopes = <Envelope>[];
          for (final id in ids) {
            final env = await dao.envelopeById(id);
            if (env != null) envelopes.add(env);
          }
          outgoing.send(EnvelopesMessage(envelopes: envelopes));
        case HaveMessage():
        case EnvelopesMessage():
        case WelcomeMessage():
        case PublishMessage():
        case PublishedMessage():
        case SubscribeMessage():
        case PeerListRequestMessage():
        case PublishLiveMessage():
        case PeerListMessage():
        case NetworkMessage():
        case PresenceMessage():
          break;
      }
    }
    await outgoing.close();
  }

  /// Client-side backfill: HELLO → WANT → HAVE → GET → ENVELOPES.
  /// Envelopes whose id was not requested are rejected by the processor
  /// (which is the source of truth for signature + dedup checks).
  Future<int> backfill(GossipTransport transport, {required int since}) async {
    // A single-subscription iterator: HAVE and ENVELOPES are read from the
    // same control stream without re-listening to it.
    final iterator = StreamIterator(
      transport.incoming.transform(LengthPrefixedDecoder()),
    );
    final outgoing = _Outgoing(transport.send);
    outgoing.send(HelloMessage(myPeerId: myPeerId));

    HaveMessage? haveMessage;
    while (haveMessage == null && await iterator.moveNext()) {
      final message = _tryDecode(iterator.current);
      if (message is HelloMessage) {
        outgoing.send(WantMessage(since: since < 0 ? 0 : since));
      } else if (message is HaveMessage) {
        haveMessage = message;
      }
    }
    if (haveMessage == null) {
      await iterator.cancel();
      await outgoing.close();
      return 0;
    }

    final wanted = <String>[];
    for (final id in haveMessage.ids) {
      if (!await dao.has(id)) wanted.add(id);
    }
    if (wanted.isEmpty) {
      await iterator.cancel();
      await outgoing.close();
      return 0;
    }
    outgoing.send(GetMessage(ids: wanted));

    var accepted = 0;
    while (await iterator.moveNext()) {
      final message = _tryDecode(iterator.current);
      if (message is EnvelopesMessage) {
        for (final envelope in message.envelopes) {
          if (!wanted.contains(envelope.id)) continue; // unsolicited → drop
          await processor.process(
            envelope,
            source: TransportSource.p2p,
            hops: 0,
          );
          accepted++;
        }
        if (message.done) break;
      }
    }
    await iterator.cancel();
    await outgoing.close();
    return accepted;
  }
}

/// Decodes one control frame, returning `null` for malformed/hostile input.
GossipMessage? _tryDecode(List<int> frame) {
  try {
    return GossipMessage.fromJson(
      jsonDecode(utf8.decode(frame)) as Map<String, dynamic>,
    );
  } catch (_) {
    return null;
  }
}

/// Fire-and-forget JSON frame writer with a bounded queue: a remote peer that
/// stops reading can no longer make us buffer without limit (H4).
class _Outgoing {
  final Future<void> Function(List<int> bytes) _send;
  final List<List<int>> _queue = [];
  bool _pumping = false;
  bool _closed = false;

  _Outgoing(this._send);

  void send(GossipMessage message) {
    if (_closed) return;
    _queue.add(utf8.encode(jsonEncode(message.toJson())));
    if (_queue.length > limits.maxGossipQueue) {
      _queue.removeAt(0);
    }
    unawaited(_pump());
  }

  Future<void> _pump() async {
    if (_pumping) return;
    _pumping = true;
    try {
      while (_queue.isNotEmpty) {
        final frame = _queue.removeAt(0);
        try {
          await _send(framePayload(frame));
        } catch (_) {
          // Peer disconnected; drain the rest silently.
        }
      }
    } finally {
      _pumping = false;
    }
  }

  Future<void> close() async {
    _closed = true;
    await _pump();
  }
}
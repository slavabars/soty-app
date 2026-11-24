import '../../models/envelope.dart';
import '../../models/peer.dart';

/// Where an envelope arrived from.
enum TransportSource { mesh, p2p, host }

/// Anything that can ingest an incoming envelope (today: [EnvelopeProcessor]).
abstract class EnvelopeSink {
  Future<void> process(
    Envelope envelope, {
    required TransportSource source,
    required int hops,
  });
}

/// A relay-only transport: it moves opaque [Envelope]s and never decrypts.
abstract class Transport {
  String get name;

  bool get isRunning;

  Future<void> start({
    required String myEdPubKey,
    required String myXPubKey,
    required String displayName,
  });

  Future<void> stop();

  /// Best-effort delivery of [envelope] to its recipient (or to the mesh).
  /// Implementations MUST dedup by envelope [id] to avoid loops. When
  /// [directOnly] is set, the envelope may only go to its direct recipient:
  /// no relay-by-any-online-peer fallback, because a media slice must not be
  /// stored or forwarded by an uninvolved device.
  Future<bool> send(Envelope envelope, {bool directOnly = false});

  /// Peers discovered/reachable via this transport.
  Stream<DtmPeer> get peers;

  /// Who receives envelopes heard on this transport.
  void setEnvelopeSink(EnvelopeSink sink);
}

/// Transport that exposes a synchronous peer-import method (QR / paste).
abstract class PeerImportable {
  void importPeer(DtmPeer peer);
}

import '../util/capped_set.dart' show CappedSet;

/// Remembers which envelope ids a transport already handed to a peer.
///
/// The distinction that matters: an id enters the ledger only **after** a
/// successful hand-off. A failed attempt leaves no trace, so the next
/// `send()` for the same envelope really tries again instead of reporting a
/// success it never earned (a retry would otherwise be lost forever).
class SendLedger {
  final CappedSet<String> _delivered = CappedSet();

  /// Whether this transport already delivered [id] once.
  bool isDelivered(String id) => _delivered.contains(id);

  /// Records a successful hand-off of [id].
  void markDelivered(String id) => _delivered.add(id);

  /// Drops [id] so the next attempt is made again.
  void forget(String id) => _delivered.remove(id);

  int get length => _delivered.length;
}

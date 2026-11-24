/// A map with a hard size ceiling that evicts the least recently used entry.
///
/// Used for per-session caches whose keys come from remote input (message ids),
/// so an unbounded map would be a slow memory leak on a long-lived device.
class LruCache<K, V> {
  LruCache({required this.maxEntries});

  final int maxEntries;
  final Map<K, V> _entries = <K, V>{};

  int get length => _entries.length;

  /// Whether [key] is cached, without marking it as used.
  bool containsKey(K key) => _entries.containsKey(key);

  V? operator [](K key) {
    final value = _entries.remove(key);
    if (value == null) return null;
    // Re-insert at the end: the map's insertion order is the recency order.
    _entries[key] = value;
    return value;
  }

  void operator []=(K key, V value) {
    _entries.remove(key);
    _entries[key] = value;
    while (_entries.length > maxEntries) {
      _entries.remove(_entries.keys.first);
    }
  }

  void clear() => _entries.clear();
}

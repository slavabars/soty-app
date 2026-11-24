import '../security_limits.dart';

/// A bounded set used for dedup/seeding. Evicts the oldest entry (FIFO) when
/// full, so a hostile peer flooding unique ids can never grow memory without
/// bound.
class CappedSet<E> {
  final int _maxSize;
  final Set<E> _set = <E>{};

  CappedSet({int? maxSize}) : _maxSize = maxSize ?? maxSeenIds;

  /// Adds [element]; returns `false` if it was already present.
  bool add(E element) {
    if (_set.contains(element)) return false;
    if (_set.length >= _maxSize) {
      _evictOldest();
    }
    _set.add(element);
    return true;
  }

  bool contains(E element) => _set.contains(element);

  int get length => _set.length;

  void remove(E element) => _set.remove(element);

  void clear() => _set.clear();

  void _evictOldest() {
    final it = _set.iterator;
    if (it.moveNext()) {
      _set.remove(it.current);
    }
  }
}

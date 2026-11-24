import '../security_limits.dart';

/// Fixed-window per-key rate limiter for host PUBLISH anti-spam.
///
/// Each key (a sender public key) gets one bucket per [windowSeconds]
/// window; a bucket over its budget rejects further events. The bucket
/// table is FIFO-capped so a hostile flood of fresh keys cannot grow
/// memory without bound.
class RateLimiter {
  final int limitPerWindow;
  final int windowSeconds;
  final int _maxKeys;

  final Map<String, _Bucket> _buckets = <String, _Bucket>{};

  RateLimiter({
    int? limitPerWindow,
    int? windowSeconds,
    int? maxKeys,
  }) : limitPerWindow = limitPerWindow ?? hostRateLimitPerWindow,
       windowSeconds = windowSeconds ?? hostRateWindowSeconds,
       _maxKeys = maxKeys ?? maxRateLimiterKeys;

  int _window(DateTime now) => now.millisecondsSinceEpoch ~/
      (windowSeconds * 1000);

  /// Returns `true` when the event is allowed, `false` when over budget.
  bool allow(String key, {DateTime? now}) {
    final time = now ?? DateTime.now().toUtc();
    final window = _window(time);
    final bucket = _buckets[key];
    if (bucket == null || bucket.window != window) {
      _evictIfNeeded();
      _buckets[key] = _Bucket(window: window, count: 1);
      return true;
    }
    if (bucket.count >= limitPerWindow) {
      return false;
    }
    bucket.count++;
    return true;
  }

  void _evictIfNeeded() {
    if (_buckets.length < _maxKeys) return;
    final oldest = _buckets.values.map((b) => b.window).reduce(
      (a, b) => a < b ? a : b,
    );
    _buckets.removeWhere((_, b) => b.window <= oldest);
    if (_buckets.length >= _maxKeys && _buckets.isNotEmpty) {
      final first = _buckets.keys.first;
      _buckets.remove(first);
    }
  }
}

class _Bucket {
  final int window;
  int count;
  _Bucket({required this.window, required this.count});
}
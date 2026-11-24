import 'package:dtm_app/core/host/rate_limiter.dart';
import 'package:dtm_app/core/security_limits.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RateLimiter allow', () {
    final at = DateTime.utc(2026, 1, 1);

    test('passes within budget then rejects in the same window', () {
      final limiter = RateLimiter(limitPerWindow: 2, windowSeconds: 60);
      expect(limiter.allow('k', now: at), isTrue);
      expect(limiter.allow('k', now: at), isTrue);
      expect(limiter.allow('k', now: at), isFalse);
      expect(limiter.allow('k', now: at), isFalse);
    });

    test('budget resets on a fresh window', () {
      final limiter = RateLimiter(limitPerWindow: 1, windowSeconds: 60);
      expect(limiter.allow('k', now: at), isTrue);
      expect(limiter.allow('k', now: at), isFalse);
      final nextWindow = at.add(const Duration(minutes: 1));
      expect(limiter.allow('k', now: nextWindow), isTrue);
      expect(limiter.allow('k', now: nextWindow), isFalse);
    });

    test('keys are independent', () {
      final limiter = RateLimiter(limitPerWindow: 1, windowSeconds: 60);
      expect(limiter.allow('a'), isTrue);
      expect(limiter.allow('b'), isTrue);
    });

    test('bucket table is FIFO-capped so key floods cannot grow memory', () {
      final limiter = RateLimiter(
        limitPerWindow: 1,
        windowSeconds: 60,
        maxKeys: 2,
      );
      expect(limiter.allow('k1', now: at), isTrue);
      expect(limiter.allow('k2', now: at), isTrue);
      final later = at.add(const Duration(minutes: 2));
      expect(limiter.allow('k3', now: later), isTrue);
      expect(limiter.allow('k1', now: later), isTrue);
    });

    test('defaults come from the shared security limits', () {
      final limiter = RateLimiter();
      final base = DateTime.utc(2026, 1, 1);
      var allowed = 0;
      // 62 events 0.9s apart, all inside one 60s window.
      for (var i = 0; i < hostRateLimitPerWindow + 2; i++) {
        final now = base.add(Duration(milliseconds: i * 900));
        if (limiter.allow('defaults', now: now)) allowed++;
      }
      expect(allowed, hostRateLimitPerWindow);
    });
  });
}
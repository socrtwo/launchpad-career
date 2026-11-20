import 'package:launchpad_server/launchpad_server.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  late TestClock clock;
  late RateLimiter limiter;

  setUp(() {
    clock = TestClock();
    limiter = RateLimiter(
      limit: 3,
      window: const Duration(minutes: 15),
      clock: clock.call,
    );
  });

  test('allows events up to the limit, then reports how long to wait', () {
    for (var i = 0; i < 3; i++) {
      expect(limiter.retryAfter('key'), isNull);
      limiter.record('key');
      clock.advance(const Duration(minutes: 1));
    }
    // The first event was 3 minutes ago, so it leaves the window in 12.
    expect(limiter.retryAfter('key'), const Duration(minutes: 12));
  });

  test('keys are independent', () {
    for (var i = 0; i < 3; i++) {
      limiter.record('first');
    }
    expect(limiter.retryAfter('first'), isNotNull);
    expect(limiter.retryAfter('second'), isNull);
  });

  test('frees a slot exactly when the oldest event leaves the window', () {
    for (var i = 0; i < 3; i++) {
      limiter.record('key');
    }
    clock.advance(const Duration(minutes: 15) - const Duration(seconds: 1));
    expect(limiter.retryAfter('key'), const Duration(seconds: 1));
    clock.advance(const Duration(seconds: 1));
    expect(limiter.retryAfter('key'), isNull);
  });

  test('the window slides: later events keep the key limited for longer', () {
    limiter.record('key');
    clock.advance(const Duration(minutes: 10));
    limiter.record('key');
    limiter.record('key');
    clock.advance(const Duration(minutes: 5));
    // The first event has expired; two remain, so one more is allowed.
    expect(limiter.retryAfter('key'), isNull);
    limiter.record('key');
    expect(limiter.retryAfter('key'), const Duration(minutes: 10));
  });

  test('a cancelled event no longer counts', () {
    limiter.record('key');
    limiter.record('key');
    final third = limiter.record('key');
    expect(limiter.retryAfter('key'), isNotNull);
    third.cancel();
    expect(limiter.retryAfter('key'), isNull);
    // Cancelling twice takes back one event, not two.
    third.cancel();
    limiter.record('key');
    expect(limiter.retryAfter('key'), isNotNull);
  });

  test('reset forgets a key', () {
    for (var i = 0; i < 3; i++) {
      limiter.record('key');
    }
    limiter.reset('key');
    expect(limiter.retryAfter('key'), isNull);
    expect(limiter.trackedKeys, 0);
  });

  test('forgets keys whose events have all expired', () {
    for (var i = 0; i < 300; i++) {
      limiter.record('key-$i');
    }
    expect(limiter.trackedKeys, 300);
    clock.advance(const Duration(minutes: 16));
    // Recording prunes periodically; 256 further calls guarantee a prune.
    for (var i = 0; i < 256; i++) {
      limiter.record('fresh');
      limiter.reset('fresh');
    }
    expect(limiter.trackedKeys, 0);
  });

  test('never remembers more than maxKeys keys', () {
    final small = RateLimiter(
      limit: 3,
      window: const Duration(minutes: 15),
      clock: clock.call,
      maxKeys: 10,
    );
    for (var i = 0; i < 50; i++) {
      small.record('key-$i');
    }
    expect(small.trackedKeys, 10);
    // The most recent keys are the ones kept.
    small.record('key-49');
    small.record('key-49');
    expect(small.retryAfter('key-49'), isNotNull);
  });

  test('rejects a non-positive limit', () {
    expect(
      () => RateLimiter(
        limit: 0,
        window: const Duration(minutes: 1),
        clock: clock.call,
      ),
      throwsArgumentError,
    );
  });
}

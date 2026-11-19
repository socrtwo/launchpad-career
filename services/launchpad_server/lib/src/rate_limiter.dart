import 'dart:collection';

/// A sliding-window limiter held entirely in memory.
///
/// Keys (handles and client addresses) live only in this object. They are
/// never logged and never written to the store, and they are forgotten once
/// their window has passed.
final class RateLimiter {
  RateLimiter({
    required this.limit,
    required this.window,
    required DateTime Function() clock,
    this.maxKeys = 50000,
  }) : _clock = clock {
    if (limit < 1) throw ArgumentError.value(limit, 'limit');
    if (maxKeys < 1) throw ArgumentError.value(maxKeys, 'maxKeys');
  }

  /// How many events one key may record within [window].
  final int limit;

  final Duration window;

  /// The most keys remembered at once. When the limiter is full, expired
  /// keys are dropped first and then the least recently added.
  final int maxKeys;

  final DateTime Function() _clock;
  final LinkedHashMap<String, Queue<DateTime>> _events =
      LinkedHashMap<String, Queue<DateTime>>();
  int _callsSincePrune = 0;

  /// How long [key] must wait before it may record another event, or null
  /// when it may record one now.
  Duration? retryAfter(String key) {
    final now = _clock();
    final events = _live(key, now);
    if (events == null || events.length < limit) return null;
    return events.first.add(window).difference(now);
  }

  /// Records one event for [key] and returns a handle that can take it back.
  ///
  /// Callers check [retryAfter] first. Sign-in records the event *before*
  /// verifying the passphrase and cancels it on success, so a burst of
  /// parallel guesses cannot all slip under the limit.
  RateLimitEntry record(String key) {
    final now = _clock();
    _maybePrune(now);
    var events = _live(key, now);
    if (events == null) {
      if (_events.length >= maxKeys) {
        _pruneExpired(now);
        while (_events.length >= maxKeys) {
          _events.remove(_events.keys.first);
        }
      }
      events = _events[key] = Queue<DateTime>();
    }
    events.add(now);
    return RateLimitEntry._(this, key, now);
  }

  /// Forgets everything recorded for [key].
  void reset(String key) {
    _events.remove(key);
  }

  /// The number of keys currently remembered.
  int get trackedKeys => _events.length;

  Queue<DateTime>? _live(String key, DateTime now) {
    final events = _events[key];
    if (events == null) return null;
    final cutoff = now.subtract(window);
    while (events.isNotEmpty && !events.first.isAfter(cutoff)) {
      events.removeFirst();
    }
    if (events.isEmpty) {
      _events.remove(key);
      return null;
    }
    return events;
  }

  void _maybePrune(DateTime now) {
    if (++_callsSincePrune < 256) return;
    _pruneExpired(now);
  }

  void _pruneExpired(DateTime now) {
    _callsSincePrune = 0;
    final cutoff = now.subtract(window);
    _events.removeWhere((_, events) => !events.last.isAfter(cutoff));
  }

  void _cancel(String key, DateTime at) {
    final events = _events[key];
    if (events == null) return;
    events.remove(at);
    if (events.isEmpty) _events.remove(key);
  }
}

/// One recorded event, which [cancel] removes again.
final class RateLimitEntry {
  RateLimitEntry._(this._limiter, this._key, this._at);

  final RateLimiter _limiter;
  final String _key;
  final DateTime _at;
  bool _cancelled = false;

  /// Takes the event back, for example because the attempt it stood for
  /// turned out to succeed.
  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    _limiter._cancel(_key, _at);
  }
}

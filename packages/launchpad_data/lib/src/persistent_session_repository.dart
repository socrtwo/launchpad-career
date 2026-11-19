import 'dart:async';
import 'dart:convert';

import 'package:launchpad_domain/launchpad_domain.dart';

import 'key_value_store.dart';
import 'session_codec.dart';

/// The session, kept in memory and - only once the person has opted in -
/// mirrored to a [KeyValueStore] on the device.
///
/// What this class guarantees:
///
///  * before [enableStorage] nothing is written, not even a "declined" marker;
///  * the "Something else" text is never written;
///  * a stored copy older than [retention] is erased on start instead of being
///    loaded (`docs/privacy/retention.md`);
///  * [disableStorage] and [deleteEverything] remove every key this class owns.
///
/// Nothing here logs. A corrupt stored copy is discarded silently, because the
/// only useful thing to put in a log line would be the person's own answers.
class PersistentSessionRepository
    implements SessionRepository, LocalDataRepository {
  PersistentSessionRepository(
    this._store, {
    DateTime Function()? clock,
    this.retention = defaultRetention,
  })  : _clock = clock ?? DateTime.now,
        _controller = StreamController<Session>.broadcast() {
    _controller.onListen = () => _controller.add(_session);
    _restore();
  }

  /// Version of the wording the person agreed to. Bump it when the opt-in text
  /// changes meaning, so an old opt-in is not stretched to cover new storage.
  static const String consentVersion = '2026-11';

  static const Duration defaultRetention = Duration(days: 365);

  static const String consentKey = 'launchpad.consent.v1';
  static const String sessionKey = 'launchpad.session.v1';

  /// Every key this class may write. Storage adapters allow-list exactly these.
  static const Set<String> ownedKeys = <String>{consentKey, sessionKey};

  final KeyValueStore _store;
  final DateTime Function() _clock;
  final Duration retention;
  final StreamController<Session> _controller;

  Session _session = const Session();
  bool _storageEnabled = false;
  DateTime? _lastSavedAt;

  @override
  bool get storageEnabled => _storageEnabled;

  @override
  DateTime? get lastSavedAt => _lastSavedAt;

  @override
  Session current() => _session;

  @override
  Stream<Session> watch() => _controller.stream;

  @override
  Future<void> update(Session session) async {
    _session = session;
    _controller.add(session);
    if (_storageEnabled) await _write();
  }

  @override
  Future<void> enableStorage() async {
    final now = _clock().toUtc();
    await _store.write(
      consentKey,
      jsonEncode(<String, Object?>{
        'storage': 'granted',
        'at': now.toIso8601String(),
        'version': consentVersion,
      }),
    );
    _storageEnabled = true;
    await _write();
  }

  @override
  Future<void> disableStorage() async {
    _storageEnabled = false;
    _lastSavedAt = null;
    for (final key in ownedKeys) {
      await _store.delete(key);
    }
  }

  @override
  Future<void> deleteEverything() async {
    await disableStorage();
    _session = const Session();
    _controller.add(_session);
  }

  @override
  String exportData() {
    return const JsonEncoder.withIndent('  ').convert(<String, Object?>{
      'format': 'launchpad-career-export',
      'exportedAt': _clock().toUtc().toIso8601String(),
      'keptOnThisDevice': _storageEnabled,
      if (_lastSavedAt != null) 'lastSavedAt': _lastSavedAt!.toIso8601String(),
      'session': SessionCodec.encode(_session, includeFreeText: true),
    });
  }

  Future<void> dispose() => _controller.close();

  Future<void> _write() async {
    final now = _clock().toUtc();
    await _store.write(
      sessionKey,
      jsonEncode(<String, Object?>{
        'savedAt': now.toIso8601String(),
        'session': SessionCodec.encode(_session),
      }),
    );
    _lastSavedAt = now;
  }

  void _restore() {
    final consent = _decode(_store.read(consentKey));
    if (consent == null ||
        consent['storage'] != 'granted' ||
        consent['version'] != consentVersion) {
      // No opt-in on record, or an opt-in to different wording: start clean
      // and remove anything a previous version left behind.
      if (_store.read(consentKey) != null || _store.read(sessionKey) != null) {
        unawaited(_erase());
      }
      return;
    }
    _storageEnabled = true;

    final stored = _decode(_store.read(sessionKey));
    if (stored == null) return;

    final savedAt = DateTime.tryParse(stored['savedAt'] as String? ?? '');
    final payload = stored['session'];
    if (savedAt == null || payload is! Map) {
      unawaited(_store.delete(sessionKey));
      return;
    }
    if (_clock().toUtc().difference(savedAt.toUtc()) > retention) {
      unawaited(_store.delete(sessionKey));
      return;
    }
    _session = SessionCodec.decode(
      payload.map((key, value) => MapEntry(key.toString(), value as Object?)),
    );
    _lastSavedAt = savedAt.toUtc();
  }

  Future<void> _erase() async {
    for (final key in ownedKeys) {
      await _store.delete(key);
    }
  }

  static Map<String, Object?>? _decode(String? raw) {
    if (raw == null) return null;
    try {
      final value = jsonDecode(raw);
      if (value is Map) {
        return value
            .map((key, item) => MapEntry(key.toString(), item as Object?));
      }
    } on FormatException {
      // Fall through: a corrupt copy is treated as no copy.
    }
    return null;
  }
}

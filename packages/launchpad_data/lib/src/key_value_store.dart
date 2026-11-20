/// The narrowest storage surface the data layer needs.
///
/// Reads are synchronous because the session has to be available on the first
/// frame; every real backend this is adapted to (browser local storage, the
/// platform preference stores) keeps an in-process cache that makes that true.
/// The adapters live in the app, because they are Flutter plugins and this
/// package is pure Dart.
abstract interface class KeyValueStore {
  String? read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

/// A store that forgets everything when the process ends.
///
/// The default wiring until an adapter is supplied, and the store every test
/// uses.
class InMemoryKeyValueStore implements KeyValueStore {
  InMemoryKeyValueStore([Map<String, String>? initial])
      : _values = <String, String>{...?initial};

  final Map<String, String> _values;

  /// Everything currently held, for assertions.
  Map<String, String> get snapshot => Map<String, String>.unmodifiable(_values);

  @override
  String? read(String key) => _values[key];

  @override
  Future<void> write(String key, String value) async {
    _values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _values.remove(key);
  }
}

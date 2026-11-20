/// Structural equality helpers.
///
/// The domain package depends on nothing but `meta`, so these are written out
/// rather than pulled in from `collection`.
bool setEquals<T>(Set<T> a, Set<T> b) =>
    identical(a, b) || (a.length == b.length && a.containsAll(b));

bool mapEquals<K, V>(Map<K, V> a, Map<K, V> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    if (!b.containsKey(entry.key) || b[entry.key] != entry.value) return false;
  }
  return true;
}

bool listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Order-independent hash for a set.
int setHash<T>(Set<T> values) => Object.hashAllUnordered(values);

/// Order-independent hash for a map.
int mapHash<K, V>(Map<K, V> values) => Object.hashAllUnordered(
      values.entries.map((entry) => Object.hash(entry.key, entry.value)),
    );

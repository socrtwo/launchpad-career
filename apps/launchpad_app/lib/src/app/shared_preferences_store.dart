import 'package:launchpad_data/launchpad_data.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Adapts the platform preference store (browser local storage on the web) to
/// the data layer's [KeyValueStore].
///
/// The cache is allow-listed to the keys the session repository owns, so this
/// adapter cannot read or write anything else even by mistake. Whether
/// anything is written at all is decided by the repository, which waits for
/// the person to opt in.
class SharedPreferencesStore implements KeyValueStore {
  SharedPreferencesStore(this._preferences);

  final SharedPreferencesWithCache _preferences;

  static Future<SharedPreferencesStore> open() async {
    final preferences = await SharedPreferencesWithCache.create(
      cacheOptions: const SharedPreferencesWithCacheOptions(
        allowList: PersistentSessionRepository.ownedKeys,
      ),
    );
    return SharedPreferencesStore(preferences);
  }

  @override
  String? read(String key) => _preferences.getString(key);

  @override
  Future<void> write(String key, String value) =>
      _preferences.setString(key, value);

  @override
  Future<void> delete(String key) => _preferences.remove(key);
}

/// Controls whether anything is kept on the device, and gives the person a
/// copy of it or removes it.
///
/// The rules this interface exists to make hard to break
/// (`docs/privacy/privacy-design.md`, `docs/privacy/retention.md`):
///
///  * nothing is written to durable storage until [enableStorage] has been
///    called as the direct result of the person choosing it;
///  * turning storage off erases what was stored;
///  * export and deletion exist wherever storage exists.
abstract interface class LocalDataRepository {
  /// Whether the person has opted in to keeping their answers on this device.
  bool get storageEnabled;

  /// When the stored copy was last written, if there is one.
  DateTime? get lastSavedAt;

  /// Records the opt-in and writes the current session.
  Future<void> enableStorage();

  /// Withdraws the opt-in and erases the stored copy. The session in memory
  /// carries on until the app is closed.
  Future<void> disableStorage();

  /// Erases the stored copy, withdraws the opt-in, and resets the session in
  /// memory. Nothing the person entered remains anywhere.
  Future<void> deleteEverything();

  /// A human-readable copy of everything currently held, stored or not.
  String exportData();
}

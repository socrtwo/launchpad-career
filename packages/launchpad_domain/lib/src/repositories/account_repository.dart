import '../entities/account.dart';
import '../entities/session.dart';

/// An optional account on a sync service.
///
/// Rules this interface exists to make hard to break
/// (`docs/privacy/privacy-design.md`):
///
///  * nothing is sent until the person signs in **and** turns sync on, and
///    then only when they ask for a sync;
///  * a sync never silently replaces either copy: a difference comes back as
///    a [SyncConflict] for the person to settle;
///  * turning sync off deletes the copy on the service;
///  * the "Something else" text is never sent;
///  * export and deletion exist wherever storage exists.
///
/// Every method that talks to the service throws [AccountException] and
/// nothing else.
abstract interface class AccountRepository {
  /// The signed-in account, or null.
  AccountStatus? get current;

  Future<AccountStatus> createAccount({
    required String handle,
    required String passphrase,
  });

  Future<AccountStatus> signIn({
    required String handle,
    required String passphrase,
  });

  /// Ends this sign-in on the service and forgets it on the device. The
  /// device forgets it even if the service cannot be reached.
  Future<void> signOut();

  /// Whether the person has turned sync on for this account.
  Future<bool> syncConsent();

  /// Turning sync off deletes the copy on the service.
  Future<void> setSyncConsent({required bool granted});

  /// Sends this device's copy. With [baseRevision] it is sent as a change to
  /// that revision; without, as a change to the revision this device last
  /// synced.
  Future<SyncResult> upload(Session session, {int? baseRevision});

  /// The copy on the service, or null if there is none. Records its revision
  /// as the one this device has seen.
  Future<RemoteProfile?> download();

  /// A human-readable copy of everything the service holds about the account.
  Future<String> exportData();

  /// Deletes the account and everything the service holds about it. Cannot
  /// be undone.
  Future<void> deleteAccount({required String passphrase});

  /// Writes the sign-in to the device store if the person allows storage, so
  /// it survives a restart. Called when storage is turned on.
  Future<void> persistIfAllowed();
}

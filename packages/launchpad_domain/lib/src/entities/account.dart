import 'package:meta/meta.dart';

import 'session.dart';

/// Why an account action did not happen.
///
/// Each value maps to one sentence in the interface that says what happened
/// and what to do. None of them carries anything the person typed.
enum AccountFailure {
  /// This build is not connected to an account service.
  notConfigured,

  /// The service could not be reached.
  network,

  /// The handle or the passphrase is wrong. The service does not say which.
  invalidCredentials,
  handleTaken,
  invalidHandle,
  invalidPassphrase,

  /// The passphrase given to confirm a deletion or a change is wrong.
  incorrectPassphrase,
  tooManyAttempts,
  serverBusy,

  /// The sign-in has expired or been revoked.
  signedOut,

  /// Sync is off, so the service refused to store anything.
  consentRequired,
  tooLarge,

  /// The service failed or answered in a way this app does not understand.
  server,
}

class AccountException implements Exception {
  const AccountException(this.failure, {this.retryAfterSeconds});

  final AccountFailure failure;

  /// How long the service asked the app to wait, where it said.
  final int? retryAfterSeconds;

  @override
  String toString() => 'AccountException(${failure.name})';
}

/// A signed-in account, as much of it as the app holds.
///
/// There is no email address and no name: an account is a handle the person
/// chose and a passphrase the app never keeps.
@immutable
class AccountStatus {
  const AccountStatus({
    required this.handle,
    this.expiresAt,
    this.syncedRevision,
  });

  final String handle;

  /// When this sign-in stops working.
  final DateTime? expiresAt;

  /// The revision of the copy on the service this device last sent or took.
  /// Null until the first sync from this device.
  final int? syncedRevision;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AccountStatus &&
          other.handle == handle &&
          other.expiresAt == expiresAt &&
          other.syncedRevision == syncedRevision);

  @override
  int get hashCode => Object.hash(handle, expiresAt, syncedRevision);
}

/// The copy of a person's answers held by the account service.
@immutable
class RemoteProfile {
  const RemoteProfile({
    required this.revision,
    required this.session,
    this.updatedAt,
  });

  final int revision;
  final DateTime? updatedAt;
  final Session session;
}

/// What happened when the app tried to send this device's copy.
@immutable
sealed class SyncResult {
  const SyncResult();
}

/// The copy was stored.
class SyncUploaded extends SyncResult {
  const SyncUploaded(this.revision);
  final int revision;
}

/// The service holds a copy this device has not seen. Nothing was changed;
/// the person chooses which copy to keep.
class SyncConflict extends SyncResult {
  const SyncConflict(this.remote);
  final RemoteProfile remote;
}

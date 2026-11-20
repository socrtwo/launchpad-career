import 'package:meta/meta.dart';

/// The consent purpose that gates profile sync.
const String syncConsentPurpose = 'sync';

/// An account. There is no email address or other contact detail: the
/// product deliberately collects none.
@immutable
final class AccountRecord {
  const AccountRecord({
    required this.id,
    required this.handle,
    required this.passphraseHash,
    required this.createdAt,
  });

  /// Opaque internal identifier. Never sent to clients.
  final String id;

  /// The lower-cased handle the person chose.
  final String handle;

  /// `pbkdf2-sha256$<iterations>$<salt b64>$<hash b64>`.
  final String passphraseHash;

  final DateTime createdAt;

  AccountRecord withPassphraseHash(String newHash) => AccountRecord(
        id: id,
        handle: handle,
        passphraseHash: newHash,
        createdAt: createdAt,
      );
}

/// A sign-in. Only the SHA-256 of the bearer token is held.
@immutable
final class TokenRecord {
  const TokenRecord({
    required this.tokenHash,
    required this.accountId,
    required this.createdAt,
    required this.expiresAt,
  });

  final String tokenHash;
  final String accountId;
  final DateTime createdAt;
  final DateTime expiresAt;

  /// Whether the token can no longer be used at [now].
  bool isExpiredAt(DateTime now) => !expiresAt.isAfter(now);
}

/// The latest decision recorded for one consent purpose.
@immutable
final class ConsentRecord {
  const ConsentRecord({
    required this.granted,
    required this.at,
    required this.policyVersion,
  });

  final bool granted;
  final DateTime at;

  /// The version of the policy text the person saw when deciding.
  final String policyVersion;
}

/// A synced profile document. [data] is opaque to the server.
@immutable
final class ProfileRecord {
  const ProfileRecord({
    required this.revision,
    required this.updatedAt,
    required this.data,
  });

  final int revision;
  final DateTime updatedAt;
  final Map<String, Object?> data;
}

/// The published revision of a catalogue.
@immutable
final class CatalogRecord {
  const CatalogRecord({
    required this.revision,
    required this.updatedAt,
    required this.document,
  });

  final int revision;
  final DateTime updatedAt;
  final Map<String, Object?> document;
}

/// How a profile write ended.
enum ProfileWriteStatus {
  /// The document was stored at a new revision.
  written,

  /// `baseRevision` did not match the stored revision.
  conflict,

  /// Sync consent is not currently granted for the account.
  consentRequired,

  /// The account no longer exists.
  accountMissing,
}

/// The outcome of `ServerStore.writeProfile`.
@immutable
final class ProfileWriteResult {
  const ProfileWriteResult.written(ProfileRecord this.profile)
      : status = ProfileWriteStatus.written;

  /// [profile] is the document currently stored, or null when there is none.
  const ProfileWriteResult.conflict(this.profile)
      : status = ProfileWriteStatus.conflict;

  const ProfileWriteResult.consentRequired()
      : status = ProfileWriteStatus.consentRequired,
        profile = null;

  const ProfileWriteResult.accountMissing()
      : status = ProfileWriteStatus.accountMissing,
        profile = null;

  final ProfileWriteStatus status;
  final ProfileRecord? profile;
}

/// How a catalogue rollback ended.
enum CatalogRollbackStatus {
  /// The previous revision is published again.
  rolledBack,

  /// Nothing has been published under that name.
  noCatalog,

  /// Only one revision has ever been published, so there is nothing to
  /// restore.
  noPreviousRevision,
}

/// The outcome of `ServerStore.rollbackCatalog`.
@immutable
final class CatalogRollbackResult {
  const CatalogRollbackResult.rolledBack(CatalogRecord this.catalog)
      : status = CatalogRollbackStatus.rolledBack;

  const CatalogRollbackResult.noCatalog()
      : status = CatalogRollbackStatus.noCatalog,
        catalog = null;

  const CatalogRollbackResult.noPreviousRevision()
      : status = CatalogRollbackStatus.noPreviousRevision,
        catalog = null;

  final CatalogRollbackStatus status;
  final CatalogRecord? catalog;
}

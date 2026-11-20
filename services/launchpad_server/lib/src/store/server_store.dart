import 'records.dart';

/// Everything the server keeps, behind one narrow interface.
///
/// Two implementations live beside this file: `InMemoryServerStore` and
/// `FileServerStore`. A database-backed implementation belongs beside them,
/// not in place of them.
///
/// Every method is **atomic**: it either applies completely or not at all,
/// and no other call observes a half-applied state. Several methods bundle a
/// check with a change (compare-and-set) precisely so that request handlers,
/// which interleave at every `await`, cannot act on stale reads. A database
/// implementation maps each method onto one statement or one transaction.
///
/// Invariants every implementation keeps:
///
/// * tokens, consents and a profile exist only for an account that exists;
/// * a profile exists only while the account's `sync` consent is granted.
abstract interface class ServerStore {
  // Accounts ---------------------------------------------------------------

  /// Stores [account]. Returns false, changing nothing, when the handle is
  /// already taken.
  Future<bool> createAccount(AccountRecord account);

  Future<AccountRecord?> findAccountByHandle(String handle);

  Future<AccountRecord?> findAccountById(String accountId);

  /// Replaces the passphrase hash, provided the account still carries
  /// [expectedPassphraseHash].
  ///
  /// With [revokeOtherTokens], every token of the account except
  /// [keepTokenHash] is deleted in the same step. Returns false, changing
  /// nothing, when the account is gone or its hash has changed.
  Future<bool> replacePassphraseHash({
    required String accountId,
    required String expectedPassphraseHash,
    required String newPassphraseHash,
    required bool revokeOtherTokens,
    String? keepTokenHash,
  });

  /// Deletes the account with its consents, profile document and every
  /// token, provided it still carries [expectedPassphraseHash].
  ///
  /// Irreversible. The handle becomes available again. Returns false,
  /// changing nothing, when the account is gone or its hash has changed.
  Future<bool> deleteAccount({
    required String accountId,
    required String expectedPassphraseHash,
  });

  // Tokens -----------------------------------------------------------------

  /// Stores [token], provided its account exists and still carries
  /// [expectedPassphraseHash].
  ///
  /// The check closes the window in which a sign-in verified against an old
  /// passphrase could be issued a token after the passphrase changed.
  ///
  /// With [maxPerAccount], the account's oldest tokens are deleted in the
  /// same step so that it holds at most that many, the new one included.
  /// Without the cap, anyone who can sign in could grow the store without
  /// limit.
  Future<bool> createToken(
    TokenRecord token, {
    required String expectedPassphraseHash,
    int? maxPerAccount,
  });

  Future<TokenRecord?> findToken(String tokenHash);

  Future<void> deleteToken(String tokenHash);

  /// The number of tokens of the account that have not expired at [now].
  Future<int> countActiveTokens(String accountId, DateTime now);

  /// Deletes every token that has expired at [now] and returns how many
  /// were removed.
  Future<int> deleteExpiredTokens(DateTime now);

  // Consents ---------------------------------------------------------------

  /// The latest decision for each purpose the account has decided on.
  Future<Map<String, ConsentRecord>> listConsents(String accountId);

  /// Records [consent] for [purpose], replacing any earlier decision.
  ///
  /// Withdrawing [syncConsentPurpose] deletes the profile document in the
  /// same step. Returns false, changing nothing, when the account is gone.
  Future<bool> putConsent(
    String accountId,
    String purpose,
    ConsentRecord consent,
  );

  // Profile ----------------------------------------------------------------

  Future<ProfileRecord?> findProfile(String accountId);

  /// Stores [data] as revision `baseRevision + 1`, provided the account
  /// exists, its sync consent is granted and [baseRevision] equals the
  /// stored revision (0 when there is no profile).
  Future<ProfileWriteResult> writeProfile(
    String accountId, {
    required int baseRevision,
    required Map<String, Object?> data,
    required DateTime updatedAt,
  });

  // Catalogues -------------------------------------------------------------

  Future<CatalogRecord?> findCatalog(String name);

  /// Publishes [document] as the next revision of [name] and keeps the
  /// revision it replaces, so one rollback is possible.
  Future<CatalogRecord> publishCatalog(
    String name,
    Map<String, Object?> document,
    DateTime at,
  );

  /// Publishes the kept previous document again, under a new revision
  /// number, and keeps the document it replaces in its place.
  Future<CatalogRollbackResult> rollbackCatalog(String name, DateTime at);

  // Lifecycle --------------------------------------------------------------

  /// Waits for pending work and releases resources. The store must not be
  /// used afterwards.
  Future<void> close();
}

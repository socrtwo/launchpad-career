import 'records.dart';
import 'server_store.dart';
import 'store_state.dart';

/// Keeps everything in memory. Nothing survives a restart.
///
/// This is the default when no data file is configured, and what the tests
/// use.
final class InMemoryServerStore implements ServerStore {
  InMemoryServerStore();

  final StoreState _state = StoreState();

  /// A JSON-compatible copy of everything held, for tests that assert on
  /// what the store does and does not contain.
  Map<String, Object?> snapshot() => _state.toJson();

  @override
  Future<bool> createAccount(AccountRecord account) async =>
      _state.createAccount(account);

  @override
  Future<AccountRecord?> findAccountByHandle(String handle) async =>
      _state.findAccountByHandle(handle);

  @override
  Future<AccountRecord?> findAccountById(String accountId) async =>
      _state.findAccountById(accountId);

  @override
  Future<bool> replacePassphraseHash({
    required String accountId,
    required String expectedPassphraseHash,
    required String newPassphraseHash,
    required bool revokeOtherTokens,
    String? keepTokenHash,
  }) async =>
      _state.replacePassphraseHash(
        accountId: accountId,
        expectedPassphraseHash: expectedPassphraseHash,
        newPassphraseHash: newPassphraseHash,
        revokeOtherTokens: revokeOtherTokens,
        keepTokenHash: keepTokenHash,
      );

  @override
  Future<bool> deleteAccount({
    required String accountId,
    required String expectedPassphraseHash,
  }) async =>
      _state.deleteAccount(
        accountId: accountId,
        expectedPassphraseHash: expectedPassphraseHash,
      );

  @override
  Future<bool> createToken(
    TokenRecord token, {
    required String expectedPassphraseHash,
    int? maxPerAccount,
  }) async =>
      _state.createToken(
        token,
        expectedPassphraseHash: expectedPassphraseHash,
        maxPerAccount: maxPerAccount,
      );

  @override
  Future<TokenRecord?> findToken(String tokenHash) async =>
      _state.findToken(tokenHash);

  @override
  Future<void> deleteToken(String tokenHash) async {
    _state.deleteToken(tokenHash);
  }

  @override
  Future<int> countActiveTokens(String accountId, DateTime now) async =>
      _state.countActiveTokens(accountId, now);

  @override
  Future<int> deleteExpiredTokens(DateTime now) async =>
      _state.deleteExpiredTokens(now);

  @override
  Future<Map<String, ConsentRecord>> listConsents(String accountId) async =>
      _state.listConsents(accountId);

  @override
  Future<bool> putConsent(
    String accountId,
    String purpose,
    ConsentRecord consent,
  ) async =>
      _state.putConsent(accountId, purpose, consent);

  @override
  Future<ProfileRecord?> findProfile(String accountId) async =>
      _state.findProfile(accountId);

  @override
  Future<ProfileWriteResult> writeProfile(
    String accountId, {
    required int baseRevision,
    required Map<String, Object?> data,
    required DateTime updatedAt,
  }) async =>
      _state.writeProfile(
        accountId,
        baseRevision: baseRevision,
        data: data,
        updatedAt: updatedAt,
      );

  @override
  Future<CatalogRecord?> findCatalog(String name) async =>
      _state.findCatalog(name);

  @override
  Future<CatalogRecord> publishCatalog(
    String name,
    Map<String, Object?> document,
    DateTime at,
  ) async =>
      _state.publishCatalog(name, document, at);

  @override
  Future<CatalogRollbackResult> rollbackCatalog(
    String name,
    DateTime at,
  ) async =>
      _state.rollbackCatalog(name, at);

  @override
  Future<void> close() async {}
}

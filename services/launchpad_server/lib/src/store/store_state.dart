import 'records.dart';

/// Thrown when persisted store contents cannot be understood.
final class StoreFormatException implements Exception {
  const StoreFormatException(this.message);

  final String message;

  @override
  String toString() => 'StoreFormatException: $message';
}

/// The whole data set, held in memory, with the store rules applied
/// synchronously.
///
/// Both bundled stores share this class: `InMemoryServerStore` uses it
/// as-is, and `FileServerStore` adds serialised persistence around it.
/// Because every method runs to completion without an `await`, each one is
/// atomic with respect to other requests.
final class StoreState {
  StoreState();

  /// The layout version written by [toJson].
  static const int formatVersion = 1;

  final Map<String, AccountRecord> _accountsById = {};
  final Map<String, String> _accountIdByHandle = {};
  final Map<String, TokenRecord> _tokens = {};
  final Map<String, Map<String, ConsentRecord>> _consents = {};
  final Map<String, ProfileRecord> _profiles = {};
  final Map<String, _CatalogSlot> _catalogs = {};

  // Accounts ---------------------------------------------------------------

  bool createAccount(AccountRecord account) {
    if (_accountIdByHandle.containsKey(account.handle) ||
        _accountsById.containsKey(account.id)) {
      return false;
    }
    _accountsById[account.id] = account;
    _accountIdByHandle[account.handle] = account.id;
    return true;
  }

  AccountRecord? findAccountByHandle(String handle) {
    final id = _accountIdByHandle[handle];
    return id == null ? null : _accountsById[id];
  }

  AccountRecord? findAccountById(String accountId) => _accountsById[accountId];

  bool replacePassphraseHash({
    required String accountId,
    required String expectedPassphraseHash,
    required String newPassphraseHash,
    required bool revokeOtherTokens,
    String? keepTokenHash,
  }) {
    final account = _accountsById[accountId];
    if (account == null || account.passphraseHash != expectedPassphraseHash) {
      return false;
    }
    _accountsById[accountId] = account.withPassphraseHash(newPassphraseHash);
    if (revokeOtherTokens) {
      _tokens.removeWhere(
        (hash, token) => token.accountId == accountId && hash != keepTokenHash,
      );
    }
    return true;
  }

  bool deleteAccount({
    required String accountId,
    required String expectedPassphraseHash,
  }) {
    final account = _accountsById[accountId];
    if (account == null || account.passphraseHash != expectedPassphraseHash) {
      return false;
    }
    _accountsById.remove(accountId);
    _accountIdByHandle.remove(account.handle);
    _tokens.removeWhere((_, token) => token.accountId == accountId);
    _consents.remove(accountId);
    _profiles.remove(accountId);
    return true;
  }

  // Tokens -----------------------------------------------------------------

  bool createToken(
    TokenRecord token, {
    required String expectedPassphraseHash,
    int? maxPerAccount,
  }) {
    final account = _accountsById[token.accountId];
    if (account == null || account.passphraseHash != expectedPassphraseHash) {
      return false;
    }
    _tokens[token.tokenHash] = token;
    if (maxPerAccount != null) {
      // Oldest first; the sort is stable, so equal times keep the order in
      // which the tokens were stored. The new token is never a candidate.
      final others = [
        for (final other in _tokens.values)
          if (other.accountId == token.accountId &&
              other.tokenHash != token.tokenHash)
            other,
      ]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      final excess = others.length + 1 - maxPerAccount;
      for (var i = 0; i < excess; i++) {
        _tokens.remove(others[i].tokenHash);
      }
    }
    return true;
  }

  TokenRecord? findToken(String tokenHash) => _tokens[tokenHash];

  /// Returns whether a token was removed.
  bool deleteToken(String tokenHash) => _tokens.remove(tokenHash) != null;

  int countActiveTokens(String accountId, DateTime now) {
    var count = 0;
    for (final token in _tokens.values) {
      if (token.accountId == accountId && !token.isExpiredAt(now)) count++;
    }
    return count;
  }

  int deleteExpiredTokens(DateTime now) {
    final before = _tokens.length;
    _tokens.removeWhere((_, token) => token.isExpiredAt(now));
    return before - _tokens.length;
  }

  // Consents ---------------------------------------------------------------

  Map<String, ConsentRecord> listConsents(String accountId) {
    return Map.unmodifiable(_consents[accountId] ?? const {});
  }

  bool putConsent(String accountId, String purpose, ConsentRecord consent) {
    if (!_accountsById.containsKey(accountId)) return false;
    (_consents[accountId] ??= {})[purpose] = consent;
    if (purpose == syncConsentPurpose && !consent.granted) {
      _profiles.remove(accountId);
    }
    return true;
  }

  // Profile ----------------------------------------------------------------

  ProfileRecord? findProfile(String accountId) => _profiles[accountId];

  ProfileWriteResult writeProfile(
    String accountId, {
    required int baseRevision,
    required Map<String, Object?> data,
    required DateTime updatedAt,
  }) {
    if (!_accountsById.containsKey(accountId)) {
      return const ProfileWriteResult.accountMissing();
    }
    final consent = _consents[accountId]?[syncConsentPurpose];
    if (consent == null || !consent.granted) {
      return const ProfileWriteResult.consentRequired();
    }
    final current = _profiles[accountId];
    if (baseRevision != (current?.revision ?? 0)) {
      return ProfileWriteResult.conflict(current);
    }
    final next = ProfileRecord(
      revision: baseRevision + 1,
      updatedAt: updatedAt,
      data: data,
    );
    _profiles[accountId] = next;
    return ProfileWriteResult.written(next);
  }

  // Catalogues -------------------------------------------------------------

  CatalogRecord? findCatalog(String name) => _catalogs[name]?.current;

  CatalogRecord publishCatalog(
    String name,
    Map<String, Object?> document,
    DateTime at,
  ) {
    final slot = _catalogs[name];
    final next = CatalogRecord(
      revision: (slot?.current.revision ?? 0) + 1,
      updatedAt: at,
      document: document,
    );
    _catalogs[name] = _CatalogSlot(next, slot?.current);
    return next;
  }

  CatalogRollbackResult rollbackCatalog(String name, DateTime at) {
    final slot = _catalogs[name];
    if (slot == null) return const CatalogRollbackResult.noCatalog();
    final previous = slot.previous;
    if (previous == null) {
      return const CatalogRollbackResult.noPreviousRevision();
    }
    final restored = CatalogRecord(
      revision: slot.current.revision + 1,
      updatedAt: at,
      document: previous.document,
    );
    _catalogs[name] = _CatalogSlot(restored, slot.current);
    return CatalogRollbackResult.rolledBack(restored);
  }

  // Persistence ------------------------------------------------------------

  Map<String, Object?> toJson() {
    return {
      'formatVersion': formatVersion,
      'accounts': [
        for (final account in _accountsById.values)
          {
            'id': account.id,
            'handle': account.handle,
            'passphraseHash': account.passphraseHash,
            'createdAt': _writeTime(account.createdAt),
          },
      ],
      'tokens': [
        for (final token in _tokens.values)
          {
            'tokenHash': token.tokenHash,
            'accountId': token.accountId,
            'createdAt': _writeTime(token.createdAt),
            'expiresAt': _writeTime(token.expiresAt),
          },
      ],
      'consents': {
        for (final entry in _consents.entries)
          entry.key: {
            for (final consent in entry.value.entries)
              consent.key: {
                'granted': consent.value.granted,
                'at': _writeTime(consent.value.at),
                'policyVersion': consent.value.policyVersion,
              },
          },
      },
      'profiles': {
        for (final entry in _profiles.entries)
          entry.key: {
            'revision': entry.value.revision,
            'updatedAt': _writeTime(entry.value.updatedAt),
            'data': entry.value.data,
          },
      },
      'catalogs': {
        for (final entry in _catalogs.entries)
          entry.key: {
            'current': _catalogToJson(entry.value.current),
            'previous': entry.value.previous == null
                ? null
                : _catalogToJson(entry.value.previous!),
          },
      },
    };
  }

  /// Rebuilds a state from [toJson] output.
  ///
  /// Throws [StoreFormatException] when [json] has an unknown layout
  /// version, the wrong shape, or breaks a store invariant.
  factory StoreState.fromJson(Object? json) {
    try {
      return StoreState._parse(json);
    } on StoreFormatException {
      rethrow;
    } on Object {
      // A cast or lookup failed: the contents have the wrong shape. The
      // original error is dropped on purpose, because its text can quote
      // stored values.
      throw const StoreFormatException(
        'The stored data does not have the expected layout.',
      );
    }
  }

  factory StoreState._parse(Object? json) {
    final root = json as Map<String, Object?>;
    final version = root['formatVersion'];
    if (version != formatVersion) {
      throw StoreFormatException(
        'The stored data uses layout version $version; this build reads '
        'version $formatVersion.',
      );
    }

    final state = StoreState();
    for (final raw in root['accounts'] as List<Object?>) {
      final entry = raw as Map<String, Object?>;
      final created = state.createAccount(
        AccountRecord(
          id: entry['id'] as String,
          handle: entry['handle'] as String,
          passphraseHash: entry['passphraseHash'] as String,
          createdAt: _readTime(entry['createdAt']),
        ),
      );
      if (!created) {
        throw const StoreFormatException(
          'The stored data lists the same account twice.',
        );
      }
    }

    for (final raw in root['tokens'] as List<Object?>) {
      final entry = raw as Map<String, Object?>;
      final token = TokenRecord(
        tokenHash: entry['tokenHash'] as String,
        accountId: entry['accountId'] as String,
        createdAt: _readTime(entry['createdAt']),
        expiresAt: _readTime(entry['expiresAt']),
      );
      state._requireAccount(token.accountId);
      state._tokens[token.tokenHash] = token;
    }

    final consents = root['consents'] as Map<String, Object?>;
    for (final entry in consents.entries) {
      state._requireAccount(entry.key);
      final purposes = entry.value as Map<String, Object?>;
      state._consents[entry.key] = {
        for (final purpose in purposes.entries)
          purpose.key: _consentFromJson(purpose.value),
      };
    }

    final profiles = root['profiles'] as Map<String, Object?>;
    for (final entry in profiles.entries) {
      state._requireAccount(entry.key);
      final consent = state._consents[entry.key]?[syncConsentPurpose];
      if (consent == null || !consent.granted) {
        throw const StoreFormatException(
          'The stored data holds a profile without sync consent.',
        );
      }
      final profile = entry.value as Map<String, Object?>;
      state._profiles[entry.key] = ProfileRecord(
        revision: profile['revision'] as int,
        updatedAt: _readTime(profile['updatedAt']),
        data: profile['data'] as Map<String, Object?>,
      );
    }

    final catalogs = root['catalogs'] as Map<String, Object?>;
    for (final entry in catalogs.entries) {
      final slot = entry.value as Map<String, Object?>;
      final previous = slot['previous'];
      state._catalogs[entry.key] = _CatalogSlot(
        _catalogFromJson(slot['current']),
        previous == null ? null : _catalogFromJson(previous),
      );
    }
    return state;
  }

  void _requireAccount(String accountId) {
    if (!_accountsById.containsKey(accountId)) {
      throw const StoreFormatException(
        'The stored data refers to an account that does not exist.',
      );
    }
  }
}

final class _CatalogSlot {
  const _CatalogSlot(this.current, this.previous);

  final CatalogRecord current;
  final CatalogRecord? previous;
}

String _writeTime(DateTime time) => time.toUtc().toIso8601String();

DateTime _readTime(Object? value) => DateTime.parse(value as String).toUtc();

ConsentRecord _consentFromJson(Object? json) {
  final entry = json as Map<String, Object?>;
  return ConsentRecord(
    granted: entry['granted'] as bool,
    at: _readTime(entry['at']),
    policyVersion: entry['policyVersion'] as String,
  );
}

Map<String, Object?> _catalogToJson(CatalogRecord catalog) => {
      'revision': catalog.revision,
      'updatedAt': _writeTime(catalog.updatedAt),
      'document': catalog.document,
    };

CatalogRecord _catalogFromJson(Object? json) {
  final entry = json as Map<String, Object?>;
  return CatalogRecord(
    revision: entry['revision'] as int,
    updatedAt: _readTime(entry['updatedAt']),
    document: entry['document'] as Map<String, Object?>,
  );
}

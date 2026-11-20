import 'dart:convert';
import 'dart:io';

import 'records.dart';
import 'server_store.dart';
import 'store_state.dart';

/// Keeps everything in one JSON file.
///
/// Suitable for a small pilot on one machine, not for anything larger: the
/// whole data set is held in memory and the whole file is rewritten on
/// every change.
///
/// * Every operation, read or write, passes through one queue, so a read
///   only ever observes state that has reached the file.
/// * A write goes to a temporary file in the same directory, is flushed,
///   and is then renamed over the data file. A crash part-way through
///   leaves the previous file intact.
/// * If a write fails, the in-memory state is reloaded from the file, so
///   memory never runs ahead of disk.
/// * A lock file stops a second server opening the same data file.
final class FileServerStore implements ServerStore {
  FileServerStore._(this._file, this._temporaryFile, this._lock, this._state);

  static final Set<String> _openPaths = {};

  final File _file;
  final File _temporaryFile;
  final RandomAccessFile _lock;
  StoreState _state;

  Future<void> _tail = Future<void>.value();
  Future<void>? _closing;
  bool _closed = false;
  bool _unusable = false;

  /// The data file this store reads and writes.
  String get path => _file.path;

  /// Opens the store at [path], creating its directory when needed.
  ///
  /// A missing file is an empty store. A file that cannot be understood
  /// throws [StoreFormatException] and is left untouched. Throws
  /// [FileSystemException] when another process holds the store open.
  static Future<FileServerStore> open(String path) async {
    final file = File(path).absolute;
    final inUse = FileSystemException(
      'The data file is already in use. Stop the other server or choose a '
      'different DATA_FILE.',
      file.path,
    );

    // The operating-system lock below is held per process, so it cannot
    // stop the same process opening the file twice. This set does.
    if (!_openPaths.add(file.path)) throw inUse;

    RandomAccessFile? lock;
    try {
      await file.parent.create(recursive: true);
      lock = await File('${file.path}.lock').open(mode: FileMode.write);
      try {
        await lock.lock(FileLock.exclusive);
      } on FileSystemException {
        throw inUse;
      }

      final temporaryFile = File('${file.path}.tmp');
      // A leftover temporary file is an interrupted write. The data file is
      // still the last complete state, so the leftover is discarded.
      if (await temporaryFile.exists()) await temporaryFile.delete();
      final state = await _load(file);
      return FileServerStore._(file, temporaryFile, lock, state);
    } on Object {
      if (lock != null) await _releaseLock(lock);
      _openPaths.remove(file.path);
      rethrow;
    }
  }

  static Future<StoreState> _load(File file) async {
    if (!await file.exists()) return StoreState();
    final Object? json;
    try {
      json = jsonDecode(utf8.decode(await file.readAsBytes()));
    } on FormatException {
      // The parser's own message can quote file contents, so it is replaced.
      throw const StoreFormatException(
        'The data file is not valid JSON. Restore it from a backup or move '
        'it aside to start empty.',
      );
    }
    return StoreState.fromJson(json);
  }

  static Future<void> _releaseLock(RandomAccessFile lock) async {
    try {
      await lock.unlock();
    } on FileSystemException {
      // Closing the file releases the lock as well.
    }
    await lock.close();
  }

  /// Runs [action] after everything queued before it has finished.
  Future<T> _enqueue<T>(Future<T> Function() action) {
    final result = _tail.then<T>((_) {
      if (_closed) throw StateError('The store is closed.');
      if (_unusable) {
        throw StateError(
          'The store stopped after a failed write and a failed reload. '
          'Check the data file and restart the server.',
        );
      }
      return action();
    });
    _tail = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  Future<T> _read<T>(T Function(StoreState state) action) {
    return _enqueue(() async => action(_state));
  }

  /// Applies [action] and, when [changed] says it altered anything, writes
  /// the new state before completing.
  Future<T> _mutate<T>(
    T Function(StoreState state) action, {
    required bool Function(T result) changed,
  }) {
    return _enqueue(() async {
      final result = action(_state);
      if (changed(result)) await _persist();
      return result;
    });
  }

  Future<void> _persist() async {
    try {
      final bytes = utf8.encode(jsonEncode(_state.toJson()));
      await _temporaryFile.writeAsBytes(bytes, flush: true);
      await _temporaryFile.rename(_file.path);
    } on Object {
      // The change did not reach the file. Fall back to what the file holds
      // so that memory and disk agree, then report the failure.
      try {
        _state = await _load(_file);
      } on Object {
        _unusable = true;
      }
      rethrow;
    }
  }

  static bool _always(Object? _) => true;
  static bool _whenTrue(bool result) => result;

  @override
  Future<bool> createAccount(AccountRecord account) =>
      _mutate((state) => state.createAccount(account), changed: _whenTrue);

  @override
  Future<AccountRecord?> findAccountByHandle(String handle) =>
      _read((state) => state.findAccountByHandle(handle));

  @override
  Future<AccountRecord?> findAccountById(String accountId) =>
      _read((state) => state.findAccountById(accountId));

  @override
  Future<bool> replacePassphraseHash({
    required String accountId,
    required String expectedPassphraseHash,
    required String newPassphraseHash,
    required bool revokeOtherTokens,
    String? keepTokenHash,
  }) =>
      _mutate(
        (state) => state.replacePassphraseHash(
          accountId: accountId,
          expectedPassphraseHash: expectedPassphraseHash,
          newPassphraseHash: newPassphraseHash,
          revokeOtherTokens: revokeOtherTokens,
          keepTokenHash: keepTokenHash,
        ),
        changed: _whenTrue,
      );

  @override
  Future<bool> deleteAccount({
    required String accountId,
    required String expectedPassphraseHash,
  }) =>
      _mutate(
        (state) => state.deleteAccount(
          accountId: accountId,
          expectedPassphraseHash: expectedPassphraseHash,
        ),
        changed: _whenTrue,
      );

  @override
  Future<bool> createToken(
    TokenRecord token, {
    required String expectedPassphraseHash,
    int? maxPerAccount,
  }) =>
      _mutate(
        (state) => state.createToken(
          token,
          expectedPassphraseHash: expectedPassphraseHash,
          maxPerAccount: maxPerAccount,
        ),
        changed: _whenTrue,
      );

  @override
  Future<TokenRecord?> findToken(String tokenHash) =>
      _read((state) => state.findToken(tokenHash));

  @override
  Future<void> deleteToken(String tokenHash) async {
    await _mutate<bool>(
      (state) => state.deleteToken(tokenHash),
      changed: _whenTrue,
    );
  }

  @override
  Future<int> countActiveTokens(String accountId, DateTime now) =>
      _read((state) => state.countActiveTokens(accountId, now));

  @override
  Future<int> deleteExpiredTokens(DateTime now) => _mutate(
        (state) => state.deleteExpiredTokens(now),
        changed: (removed) => removed > 0,
      );

  @override
  Future<Map<String, ConsentRecord>> listConsents(String accountId) =>
      _read((state) => state.listConsents(accountId));

  @override
  Future<bool> putConsent(
    String accountId,
    String purpose,
    ConsentRecord consent,
  ) =>
      _mutate(
        (state) => state.putConsent(accountId, purpose, consent),
        changed: _whenTrue,
      );

  @override
  Future<ProfileRecord?> findProfile(String accountId) =>
      _read((state) => state.findProfile(accountId));

  @override
  Future<ProfileWriteResult> writeProfile(
    String accountId, {
    required int baseRevision,
    required Map<String, Object?> data,
    required DateTime updatedAt,
  }) =>
      _mutate(
        (state) => state.writeProfile(
          accountId,
          baseRevision: baseRevision,
          data: data,
          updatedAt: updatedAt,
        ),
        changed: (result) => result.status == ProfileWriteStatus.written,
      );

  @override
  Future<CatalogRecord?> findCatalog(String name) =>
      _read((state) => state.findCatalog(name));

  @override
  Future<CatalogRecord> publishCatalog(
    String name,
    Map<String, Object?> document,
    DateTime at,
  ) =>
      _mutate(
        (state) => state.publishCatalog(name, document, at),
        changed: _always,
      );

  @override
  Future<CatalogRollbackResult> rollbackCatalog(String name, DateTime at) =>
      _mutate(
        (state) => state.rollbackCatalog(name, at),
        changed: (result) => result.status == CatalogRollbackStatus.rolledBack,
      );

  @override
  Future<void> close() {
    final existing = _closing;
    if (existing != null) return existing;
    // Chained behind the queue, so work accepted before this call still
    // reaches the file. Anything queued afterwards finds the store closed.
    final closing = _tail.then((_) async {
      _closed = true;
      try {
        await _releaseLock(_lock);
      } finally {
        _openPaths.remove(_file.path);
      }
    });
    _tail = closing.then<void>((_) {}, onError: (Object _) {});
    return _closing = closing;
  }
}

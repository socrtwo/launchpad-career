import 'dart:convert';
import 'dart:io';

import 'package:launchpad_server/launchpad_server.dart';
import 'package:test/test.dart';

final DateTime _t0 = DateTime.utc(2026, 1, 15, 9);

AccountRecord _account(String id, String handle, {String hash = 'hash-1'}) {
  return AccountRecord(
    id: id,
    handle: handle,
    passphraseHash: hash,
    createdAt: _t0,
  );
}

TokenRecord _token(String hash, String accountId, {DateTime? expiresAt}) {
  return TokenRecord(
    tokenHash: hash,
    accountId: accountId,
    createdAt: _t0,
    expiresAt: expiresAt ?? _t0.add(const Duration(days: 30)),
  );
}

ConsentRecord _consent({required bool granted}) {
  return ConsentRecord(granted: granted, at: _t0, policyVersion: 'v1');
}

/// The behaviour every [ServerStore] must have, run against each
/// implementation.
void _contract(Future<ServerStore> Function() open) {
  late ServerStore store;

  setUp(() async => store = await open());
  tearDown(() => store.close());

  Future<void> grantSync(String accountId) async {
    expect(
      await store.putConsent(
        accountId,
        syncConsentPurpose,
        _consent(granted: true),
      ),
      isTrue,
    );
  }

  group('accounts', () {
    test('are found by handle and by id', () async {
      expect(await store.createAccount(_account('a1', 'ada')), isTrue);
      expect((await store.findAccountByHandle('ada'))?.id, 'a1');
      expect((await store.findAccountById('a1'))?.handle, 'ada');
      expect(await store.findAccountByHandle('nobody'), isNull);
      expect(await store.findAccountById('nothing'), isNull);
    });

    test('a taken handle is refused and the first account is unchanged',
        () async {
      await store.createAccount(_account('a1', 'ada'));
      expect(
        await store.createAccount(_account('a2', 'ada', hash: 'other')),
        isFalse,
      );
      final found = await store.findAccountByHandle('ada');
      expect(found?.id, 'a1');
      expect(found?.passphraseHash, 'hash-1');
      expect(await store.findAccountById('a2'), isNull);
    });

    test('the passphrase hash is replaced only when the expected one matches',
        () async {
      await store.createAccount(_account('a1', 'ada'));
      expect(
        await store.replacePassphraseHash(
          accountId: 'a1',
          expectedPassphraseHash: 'stale',
          newPassphraseHash: 'hash-2',
          revokeOtherTokens: true,
        ),
        isFalse,
      );
      expect((await store.findAccountById('a1'))?.passphraseHash, 'hash-1');

      expect(
        await store.replacePassphraseHash(
          accountId: 'a1',
          expectedPassphraseHash: 'hash-1',
          newPassphraseHash: 'hash-2',
          revokeOtherTokens: true,
        ),
        isTrue,
      );
      expect((await store.findAccountById('a1'))?.passphraseHash, 'hash-2');
      expect(
        await store.replacePassphraseHash(
          accountId: 'missing',
          expectedPassphraseHash: 'hash-1',
          newPassphraseHash: 'hash-2',
          revokeOtherTokens: true,
        ),
        isFalse,
      );
    });

    test('replacing the hash can revoke every token but one', () async {
      await store.createAccount(_account('a1', 'ada'));
      await store.createAccount(_account('b1', 'bea'));
      for (final hash in ['t1', 't2', 't3']) {
        await store.createToken(
          _token(hash, 'a1'),
          expectedPassphraseHash: 'hash-1',
        );
      }
      await store.createToken(
        _token('other', 'b1'),
        expectedPassphraseHash: 'hash-1',
      );

      await store.replacePassphraseHash(
        accountId: 'a1',
        expectedPassphraseHash: 'hash-1',
        newPassphraseHash: 'hash-2',
        revokeOtherTokens: true,
        keepTokenHash: 't2',
      );
      expect(await store.findToken('t1'), isNull);
      expect(await store.findToken('t2'), isNotNull);
      expect(await store.findToken('t3'), isNull);
      expect(await store.findToken('other'), isNotNull);
    });

    test('replacing the hash can leave tokens alone', () async {
      await store.createAccount(_account('a1', 'ada'));
      await store.createToken(
        _token('t1', 'a1'),
        expectedPassphraseHash: 'hash-1',
      );
      await store.replacePassphraseHash(
        accountId: 'a1',
        expectedPassphraseHash: 'hash-1',
        newPassphraseHash: 'hash-2',
        revokeOtherTokens: false,
      );
      expect(await store.findToken('t1'), isNotNull);
    });

    test('deleting removes consents, profile and tokens and frees the handle',
        () async {
      await store.createAccount(_account('a1', 'ada'));
      await store.createAccount(_account('b1', 'bea'));
      await store.createToken(
        _token('t1', 'a1'),
        expectedPassphraseHash: 'hash-1',
      );
      await store.createToken(
        _token('t2', 'b1'),
        expectedPassphraseHash: 'hash-1',
      );
      await grantSync('a1');
      await grantSync('b1');
      await store.writeProfile(
        'a1',
        baseRevision: 0,
        data: {'k': 'v'},
        updatedAt: _t0,
      );
      await store.writeProfile(
        'b1',
        baseRevision: 0,
        data: {'k': 'w'},
        updatedAt: _t0,
      );

      expect(
        await store.deleteAccount(
          accountId: 'a1',
          expectedPassphraseHash: 'stale',
        ),
        isFalse,
      );
      expect(await store.findAccountById('a1'), isNotNull);

      expect(
        await store.deleteAccount(
          accountId: 'a1',
          expectedPassphraseHash: 'hash-1',
        ),
        isTrue,
      );
      expect(await store.findAccountById('a1'), isNull);
      expect(await store.findAccountByHandle('ada'), isNull);
      expect(await store.findToken('t1'), isNull);
      expect(await store.listConsents('a1'), isEmpty);
      expect(await store.findProfile('a1'), isNull);

      // The other account is untouched.
      expect(await store.findToken('t2'), isNotNull);
      expect((await store.findProfile('b1'))?.data, {'k': 'w'});
      expect(await store.listConsents('b1'), hasLength(1));

      // The handle can be registered again, as a different account.
      expect(await store.createAccount(_account('a2', 'ada')), isTrue);
      expect(await store.listConsents('a2'), isEmpty);
      expect(await store.findProfile('a2'), isNull);
      expect(
        await store.deleteAccount(
          accountId: 'a1',
          expectedPassphraseHash: 'hash-1',
        ),
        isFalse,
      );
    });
  });

  group('tokens', () {
    test('are created only for an existing account with the expected hash',
        () async {
      await store.createAccount(_account('a1', 'ada'));
      expect(
        await store.createToken(
          _token('t1', 'missing'),
          expectedPassphraseHash: 'hash-1',
        ),
        isFalse,
      );
      expect(
        await store.createToken(
          _token('t1', 'a1'),
          expectedPassphraseHash: 'stale',
        ),
        isFalse,
      );
      expect(await store.findToken('t1'), isNull);
      expect(
        await store.createToken(
          _token('t1', 'a1'),
          expectedPassphraseHash: 'hash-1',
        ),
        isTrue,
      );
      final found = await store.findToken('t1');
      expect(found?.accountId, 'a1');
      expect(found?.expiresAt, _t0.add(const Duration(days: 30)));
    });

    test('a cap evicts the oldest tokens of that account only', () async {
      await store.createAccount(_account('a1', 'ada'));
      await store.createAccount(_account('b1', 'bea'));
      await store.createToken(
        _token('other', 'b1'),
        expectedPassphraseHash: 'hash-1',
      );
      for (var i = 0; i < 5; i++) {
        final created = await store.createToken(
          TokenRecord(
            tokenHash: 't$i',
            accountId: 'a1',
            createdAt: _t0.add(Duration(minutes: i)),
            expiresAt: _t0.add(const Duration(days: 30)),
          ),
          expectedPassphraseHash: 'hash-1',
          maxPerAccount: 3,
        );
        expect(created, isTrue);
      }
      expect(await store.findToken('t0'), isNull);
      expect(await store.findToken('t1'), isNull);
      for (final kept in ['t2', 't3', 't4', 'other']) {
        expect(await store.findToken(kept), isNotNull, reason: kept);
      }
      expect(await store.countActiveTokens('a1', _t0), 3);

      // The new token is kept even when every token has the same time.
      await store.createToken(
        _token('same-time', 'a1'),
        expectedPassphraseHash: 'hash-1',
        maxPerAccount: 1,
      );
      expect(await store.findToken('same-time'), isNotNull);
      expect(await store.countActiveTokens('a1', _t0), 1);
      expect(await store.findToken('other'), isNotNull);
    });

    test('can be deleted one at a time', () async {
      await store.createAccount(_account('a1', 'ada'));
      await store.createToken(
        _token('t1', 'a1'),
        expectedPassphraseHash: 'hash-1',
      );
      await store.createToken(
        _token('t2', 'a1'),
        expectedPassphraseHash: 'hash-1',
      );
      await store.deleteToken('t1');
      await store.deleteToken('never-existed');
      expect(await store.findToken('t1'), isNull);
      expect(await store.findToken('t2'), isNotNull);
    });

    test('expired tokens are not counted and can be swept', () async {
      await store.createAccount(_account('a1', 'ada'));
      await store.createAccount(_account('b1', 'bea'));
      final soon = _t0.add(const Duration(days: 1));
      await store.createToken(
        _token('old', 'a1', expiresAt: soon),
        expectedPassphraseHash: 'hash-1',
      );
      await store.createToken(
        _token('new', 'a1'),
        expectedPassphraseHash: 'hash-1',
      );
      await store.createToken(
        _token('other', 'b1'),
        expectedPassphraseHash: 'hash-1',
      );

      expect(await store.countActiveTokens('a1', _t0), 2);
      // A token is expired from the instant of its expiry time.
      expect(await store.countActiveTokens('a1', soon), 1);
      expect(await store.countActiveTokens('b1', soon), 1);

      expect(await store.deleteExpiredTokens(_t0), 0);
      expect(await store.deleteExpiredTokens(soon), 1);
      expect(await store.findToken('old'), isNull);
      expect(await store.findToken('new'), isNotNull);
    });
  });

  group('consents and profile', () {
    setUp(() => store.createAccount(_account('a1', 'ada')));

    test('the latest decision per purpose is kept', () async {
      expect(await store.listConsents('a1'), isEmpty);
      await grantSync('a1');
      final later = ConsentRecord(
        granted: false,
        at: _t0.add(const Duration(hours: 1)),
        policyVersion: 'v2',
      );
      await store.putConsent('a1', syncConsentPurpose, later);
      final consents = await store.listConsents('a1');
      expect(consents.keys, [syncConsentPurpose]);
      expect(consents[syncConsentPurpose]?.granted, isFalse);
      expect(consents[syncConsentPurpose]?.policyVersion, 'v2');
      expect(consents[syncConsentPurpose]?.at, later.at);
    });

    test('a consent for a missing account is refused', () async {
      expect(
        await store.putConsent(
          'missing',
          syncConsentPurpose,
          _consent(granted: true),
        ),
        isFalse,
      );
      expect(await store.listConsents('missing'), isEmpty);
    });

    test('a profile is written only with sync consent', () async {
      var result = await store.writeProfile(
        'a1',
        baseRevision: 0,
        data: {'k': 'v'},
        updatedAt: _t0,
      );
      expect(result.status, ProfileWriteStatus.consentRequired);
      expect(await store.findProfile('a1'), isNull);

      await store.putConsent(
          'a1', syncConsentPurpose, _consent(granted: false));
      result = await store.writeProfile(
        'a1',
        baseRevision: 0,
        data: {'k': 'v'},
        updatedAt: _t0,
      );
      expect(result.status, ProfileWriteStatus.consentRequired);

      result = await store.writeProfile(
        'missing',
        baseRevision: 0,
        data: {'k': 'v'},
        updatedAt: _t0,
      );
      expect(result.status, ProfileWriteStatus.accountMissing);
    });

    test('revisions advance one at a time and stale writes conflict', () async {
      await grantSync('a1');
      final first = await store.writeProfile(
        'a1',
        baseRevision: 0,
        data: {'n': 1},
        updatedAt: _t0,
      );
      expect(first.status, ProfileWriteStatus.written);
      expect(first.profile?.revision, 1);

      final second = await store.writeProfile(
        'a1',
        baseRevision: 1,
        data: {'n': 2},
        updatedAt: _t0.add(const Duration(minutes: 1)),
      );
      expect(second.profile?.revision, 2);

      final stale = await store.writeProfile(
        'a1',
        baseRevision: 1,
        data: {'n': 99},
        updatedAt: _t0,
      );
      expect(stale.status, ProfileWriteStatus.conflict);
      expect(stale.profile?.revision, 2);
      expect(stale.profile?.data, {'n': 2});

      final stored = await store.findProfile('a1');
      expect(stored?.revision, 2);
      expect(stored?.data, {'n': 2});
      expect(stored?.updatedAt, _t0.add(const Duration(minutes: 1)));
    });

    test('a non-zero base revision conflicts when there is no profile',
        () async {
      await grantSync('a1');
      final result = await store.writeProfile(
        'a1',
        baseRevision: 3,
        data: {'n': 1},
        updatedAt: _t0,
      );
      expect(result.status, ProfileWriteStatus.conflict);
      expect(result.profile, isNull);
    });

    test('withdrawing sync consent deletes the profile in the same step',
        () async {
      await grantSync('a1');
      await store.writeProfile(
        'a1',
        baseRevision: 0,
        data: {'k': 'v'},
        updatedAt: _t0,
      );
      await store.putConsent(
          'a1', syncConsentPurpose, _consent(granted: false));
      expect(await store.findProfile('a1'), isNull);

      // Granting again does not bring it back; the next write starts at 1.
      await grantSync('a1');
      expect(await store.findProfile('a1'), isNull);
      final result = await store.writeProfile(
        'a1',
        baseRevision: 0,
        data: {'k': 'new'},
        updatedAt: _t0,
      );
      expect(result.profile?.revision, 1);
    });

    test('a decision about another purpose leaves the profile alone', () async {
      await grantSync('a1');
      await store.writeProfile(
        'a1',
        baseRevision: 0,
        data: {'k': 'v'},
        updatedAt: _t0,
      );
      await store.putConsent('a1', 'another', _consent(granted: false));
      expect(await store.findProfile('a1'), isNotNull);
    });
  });

  group('catalogues', () {
    test('revisions increase and each name is separate', () async {
      expect(await store.findCatalog('goals'), isNull);
      final first = await store.publishCatalog('goals', {'v': 1}, _t0);
      expect(first.revision, 1);
      final second = await store.publishCatalog('goals', {'v': 2}, _t0);
      expect(second.revision, 2);
      expect((await store.findCatalog('goals'))?.document, {'v': 2});
      expect(await store.findCatalog('occupations'), isNull);
      final other = await store.publishCatalog('occupations', {'o': 1}, _t0);
      expect(other.revision, 1);
    });

    test('rollback needs a catalogue and a previous revision', () async {
      expect(
        (await store.rollbackCatalog('goals', _t0)).status,
        CatalogRollbackStatus.noCatalog,
      );
      await store.publishCatalog('goals', {'v': 1}, _t0);
      expect(
        (await store.rollbackCatalog('goals', _t0)).status,
        CatalogRollbackStatus.noPreviousRevision,
      );
      expect((await store.findCatalog('goals'))?.revision, 1);
    });

    test('rollback republishes the previous document under a new revision',
        () async {
      await store.publishCatalog('goals', {'v': 1}, _t0);
      await store.publishCatalog('goals', {'v': 2}, _t0);
      final later = _t0.add(const Duration(hours: 1));

      final result = await store.rollbackCatalog('goals', later);
      expect(result.status, CatalogRollbackStatus.rolledBack);
      expect(result.catalog?.revision, 3);
      expect(result.catalog?.document, {'v': 1});
      expect(result.catalog?.updatedAt, later);
      expect((await store.findCatalog('goals'))?.document, {'v': 1});

      // The document that was rolled back is kept, so a second rollback
      // undoes the first.
      final again = await store.rollbackCatalog('goals', later);
      expect(again.catalog?.revision, 4);
      expect(again.catalog?.document, {'v': 2});
    });

    test('only one earlier revision is kept', () async {
      await store.publishCatalog('goals', {'v': 1}, _t0);
      await store.publishCatalog('goals', {'v': 2}, _t0);
      await store.publishCatalog('goals', {'v': 3}, _t0);
      final result = await store.rollbackCatalog('goals', _t0);
      expect(result.catalog?.document, {'v': 2});
    });
  });
}

void main() {
  group('InMemoryServerStore', () {
    _contract(() async => InMemoryServerStore());
  });

  group('FileServerStore', () {
    late Directory directory;
    late String path;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('launchpad_store_');
      path = '${directory.path}/data.json';
    });
    tearDown(() => directory.delete(recursive: true));

    group('contract', () {
      _contract(() => FileServerStore.open(path));
    });

    Future<void> populate(ServerStore store) async {
      await store.createAccount(_account('a1', 'ada'));
      await store.createToken(
        _token('t1', 'a1'),
        expectedPassphraseHash: 'hash-1',
      );
      await store.putConsent(
        'a1',
        syncConsentPurpose,
        _consent(granted: true),
      );
      await store.writeProfile(
        'a1',
        baseRevision: 0,
        data: {
          'goal': 'explore',
          'notes': ['one', 'two'],
          'nested': {'n': 1.5, 'flag': true, 'nothing': null},
        },
        updatedAt: _t0.add(const Duration(minutes: 5)),
      );
      await store.publishCatalog('goals', {'v': 1}, _t0);
      await store.publishCatalog('goals', {'v': 2}, _t0);
    }

    test('a missing file is an empty store, and its directory is created',
        () async {
      final nested = '${directory.path}/a/b/data.json';
      final store = await FileServerStore.open(nested);
      expect(await store.findAccountByHandle('ada'), isNull);
      expect(await store.findCatalog('goals'), isNull);
      await store.close();
      expect(Directory('${directory.path}/a/b').existsSync(), isTrue);
    });

    test('everything survives closing and reopening', () async {
      final first = await FileServerStore.open(path);
      await populate(first);
      await first.close();

      final second = await FileServerStore.open(path);
      addTearDown(second.close);

      final account = await second.findAccountByHandle('ada');
      expect(account?.id, 'a1');
      expect(account?.passphraseHash, 'hash-1');
      expect(account?.createdAt, _t0);

      final token = await second.findToken('t1');
      expect(token?.accountId, 'a1');
      expect(token?.expiresAt, _t0.add(const Duration(days: 30)));

      final consents = await second.listConsents('a1');
      expect(consents[syncConsentPurpose]?.granted, isTrue);
      expect(consents[syncConsentPurpose]?.policyVersion, 'v1');

      final profile = await second.findProfile('a1');
      expect(profile?.revision, 1);
      expect(profile?.updatedAt, _t0.add(const Duration(minutes: 5)));
      expect(profile?.data, {
        'goal': 'explore',
        'notes': ['one', 'two'],
        'nested': {'n': 1.5, 'flag': true, 'nothing': null},
      });

      expect((await second.findCatalog('goals'))?.revision, 2);
      // The kept previous revision survives too.
      final rolledBack = await second.rollbackCatalog('goals', _t0);
      expect(rolledBack.catalog?.document, {'v': 1});
    });

    test('a deletion survives reopening and leaves no trace in the file',
        () async {
      final first = await FileServerStore.open(path);
      await populate(first);
      expect(File(path).readAsStringSync(), contains('ada'));
      await first.deleteAccount(
        accountId: 'a1',
        expectedPassphraseHash: 'hash-1',
      );
      await first.close();

      final contents = File(path).readAsStringSync();
      expect(contents, isNot(contains('ada')));
      expect(contents, isNot(contains('a1')));
      expect(contents, isNot(contains('explore')));

      final second = await FileServerStore.open(path);
      addTearDown(second.close);
      expect(await second.findAccountByHandle('ada'), isNull);
      expect(await second.findToken('t1'), isNull);
    });

    test('each change is on disk before the call completes', () async {
      final store = await FileServerStore.open(path);
      addTearDown(store.close);
      await store.createAccount(_account('a1', 'ada'));
      expect(File(path).readAsStringSync(), contains('"handle":"ada"'));
      await store.createAccount(_account('b1', 'bea'));
      expect(File(path).readAsStringSync(), contains('"handle":"bea"'));
    });

    test('writes go through a temporary file that is renamed into place',
        () async {
      final store = await FileServerStore.open(path);
      addTearDown(store.close);

      // Watch the directory while many writes run. The data file must hold
      // complete JSON every time it is looked at, because it is only ever
      // replaced by rename, never written in place.
      var looks = 0;
      var done = false;
      Future<void> watch() async {
        while (!done) {
          final file = File(path);
          if (file.existsSync()) {
            final state = jsonDecode(file.readAsStringSync());
            expect(state, isA<Map<String, Object?>>());
            looks++;
          }
          await Future<void>.delayed(Duration.zero);
        }
      }

      final watcher = watch();
      final padding = 'x' * 20000;
      await Future.wait([
        for (var i = 0; i < 40; i++)
          store.createAccount(_account('id-$i', 'user-$i', hash: padding)),
      ]);
      done = true;
      await watcher;

      expect(looks, greaterThan(0));
      expect(File('$path.tmp').existsSync(), isFalse);
      final state =
          jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>;
      expect(state['accounts'], hasLength(40));
    });

    test('concurrent changes are serialised: none is lost', () async {
      final store = await FileServerStore.open(path);
      await store.createAccount(_account('a1', 'ada'));
      await store.putConsent(
        'a1',
        syncConsentPurpose,
        _consent(granted: true),
      );

      // Twenty writers all based on revision 0: exactly one may win.
      final results = await Future.wait([
        for (var i = 0; i < 20; i++)
          store.writeProfile(
            'a1',
            baseRevision: 0,
            data: {'writer': i},
            updatedAt: _t0,
          ),
      ]);
      expect(
        results.where((r) => r.status == ProfileWriteStatus.written),
        hasLength(1),
      );
      expect(
        results.where((r) => r.status == ProfileWriteStatus.conflict),
        hasLength(19),
      );
      await store.close();

      final reopened = await FileServerStore.open(path);
      addTearDown(reopened.close);
      final profile = await reopened.findProfile('a1');
      expect(profile?.revision, 1);
      expect(profile?.data, {'writer': 0});
    });

    test('a failed write changes neither the file nor what the store reports',
        () async {
      final store = await FileServerStore.open(path);
      addTearDown(store.close);
      await store.createAccount(_account('a1', 'ada'));
      final before = File(path).readAsBytesSync();

      // A directory where the temporary file belongs makes the write fail
      // before anything can be renamed over the data file.
      final obstacle = Directory('$path.tmp')..createSync();
      await expectLater(
        store.createAccount(_account('b1', 'bea')),
        throwsA(isA<FileSystemException>()),
      );

      expect(File(path).readAsBytesSync(), before);
      expect(await store.findAccountByHandle('bea'), isNull);
      expect(await store.findAccountByHandle('ada'), isNotNull);

      // Once the obstacle is gone the store carries on.
      obstacle.deleteSync();
      expect(await store.createAccount(_account('b1', 'bea')), isTrue);
      expect(File(path).readAsStringSync(), contains('"handle":"bea"'));
    });

    test('a leftover temporary file from an interrupted write is discarded',
        () async {
      final first = await FileServerStore.open(path);
      await first.createAccount(_account('a1', 'ada'));
      await first.close();

      // Simulate a crash part-way through the next write.
      File('$path.tmp')
          .writeAsStringSync('{"formatVersion":1,"accounts":[{"id"');

      final second = await FileServerStore.open(path);
      addTearDown(second.close);
      expect(await second.findAccountByHandle('ada'), isNotNull);
      expect(File('$path.tmp').existsSync(), isFalse);
    });

    test('a file that is not JSON is refused and left untouched', () async {
      File(path).writeAsStringSync('{"formatVersion":1,"accounts":[');
      await expectLater(
        FileServerStore.open(path),
        throwsA(isA<StoreFormatException>()),
      );
      expect(
        File(path).readAsStringSync(),
        '{"formatVersion":1,"accounts":[',
      );
    });

    test('a file with an unknown layout version is refused', () async {
      File(path).writeAsStringSync(
        jsonEncode({
          'formatVersion': 99,
          'accounts': <Object?>[],
          'tokens': <Object?>[],
          'consents': <String, Object?>{},
          'profiles': <String, Object?>{},
          'catalogs': <String, Object?>{},
        }),
      );
      await expectLater(
        FileServerStore.open(path),
        throwsA(
          isA<StoreFormatException>().having(
            (e) => e.message,
            'message',
            contains('99'),
          ),
        ),
      );
    });

    test('a file of the wrong shape is refused without quoting its contents',
        () async {
      File(path).writeAsStringSync(
        jsonEncode({
          'formatVersion': 1,
          'accounts': [
            {'id': 'a1', 'handle': 'private-handle', 'passphraseHash': 7},
          ],
          'tokens': <Object?>[],
          'consents': <String, Object?>{},
          'profiles': <String, Object?>{},
          'catalogs': <String, Object?>{},
        }),
      );
      await expectLater(
        FileServerStore.open(path),
        throwsA(
          isA<StoreFormatException>().having(
            (e) => e.toString(),
            'text',
            isNot(contains('private-handle')),
          ),
        ),
      );
    });

    test('a file that breaks a store invariant is refused', () async {
      Map<String, Object?> state({
        List<Object?> tokens = const [],
        Map<String, Object?> profiles = const {},
      }) =>
          {
            'formatVersion': 1,
            'accounts': [
              {
                'id': 'a1',
                'handle': 'ada',
                'passphraseHash': 'hash-1',
                'createdAt': _t0.toIso8601String(),
              },
            ],
            'tokens': tokens,
            'consents': <String, Object?>{},
            'profiles': profiles,
            'catalogs': <String, Object?>{},
          };

      // A token for an account that does not exist.
      File(path).writeAsStringSync(
        jsonEncode(
          state(
            tokens: [
              {
                'tokenHash': 't1',
                'accountId': 'ghost',
                'createdAt': _t0.toIso8601String(),
                'expiresAt': _t0.toIso8601String(),
              },
            ],
          ),
        ),
      );
      await expectLater(
        FileServerStore.open(path),
        throwsA(isA<StoreFormatException>()),
      );

      // A profile held without sync consent.
      File(path).writeAsStringSync(
        jsonEncode(
          state(
            profiles: {
              'a1': {
                'revision': 1,
                'updatedAt': _t0.toIso8601String(),
                'data': <String, Object?>{},
              },
            },
          ),
        ),
      );
      await expectLater(
        FileServerStore.open(path),
        throwsA(isA<StoreFormatException>()),
      );
    });

    test('the same file cannot be opened twice at once', () async {
      final first = await FileServerStore.open(path);
      await expectLater(
        FileServerStore.open(path),
        throwsA(isA<FileSystemException>()),
      );
      await first.close();

      // After closing, it can be opened again.
      final second = await FileServerStore.open(path);
      await second.close();
    });

    test('a failed open releases the file for the next attempt', () async {
      File(path).writeAsStringSync('not json');
      await expectLater(
        FileServerStore.open(path),
        throwsA(isA<StoreFormatException>()),
      );
      File(path).deleteSync();
      final store = await FileServerStore.open(path);
      await store.close();
    });

    test('close waits for queued writes and then refuses further use',
        () async {
      final store = await FileServerStore.open(path);
      final pending = [
        for (var i = 0; i < 10; i++)
          store.createAccount(_account('id-$i', 'user-$i')),
      ];
      final closing = store.close();
      final late = store.createAccount(_account('late', 'late'));
      await expectLater(late, throwsStateError);

      expect(await Future.wait(pending), everyElement(isTrue));
      await closing;
      // Closing twice is harmless.
      await store.close();

      final state =
          jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>;
      expect(state['accounts'], hasLength(10));
      await expectLater(store.findAccountByHandle('user-1'), throwsStateError);
    });

    test('a read-only call does not rewrite the file', () async {
      final store = await FileServerStore.open(path);
      addTearDown(store.close);
      await store.createAccount(_account('a1', 'ada'));
      final modified = File(path).lastModifiedSync();
      final bytes = File(path).readAsBytesSync();

      await store.findAccountByHandle('ada');
      await store.deleteToken('never-existed');
      await store.deleteExpiredTokens(_t0);
      expect(await store.createAccount(_account('a2', 'ada')), isFalse);

      expect(File(path).readAsBytesSync(), bytes);
      expect(File(path).lastModifiedSync(), modified);
    });
  });
}

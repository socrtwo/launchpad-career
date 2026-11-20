import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:launchpad_server/launchpad_server.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  late Harness h;

  setUp(() => h = Harness());

  group('POST /v1/accounts', () {
    test('creates an account and returns a token that works', () async {
      final response = await h.send(
        'POST',
        '/v1/accounts',
        json: {'handle': 'ada_l-1', 'passphrase': goodPassphrase},
      );
      expect(response.status, 201);
      expect(response.object.keys, unorderedEquals(['token', 'expiresAt']));
      final token = response.object['token'] as String;
      expect(token, matches(RegExp(r'^[A-Za-z0-9_-]{43}$')));
      expect(
        DateTime.parse(response.object['expiresAt'] as String),
        h.clock.now.add(const Duration(days: 30)),
      );
      expect(response.headers['cache-control'], 'no-store');

      final export = await h.send('GET', '/v1/export', token: token);
      expect(export.status, 200);
      expect(export.object['handle'], 'ada_l-1');
    });

    test('lower-cases the handle before use', () async {
      await h.createAccount('MiXed_Case');
      expect((await h.signIn('mixed_case')).status, 200);
      expect((await h.signIn('MIXED_CASE')).status, 200);
      expect(h.storeDump, contains('"handle":"mixed_case"'));
      expect(h.storeDump, isNot(contains('MiXed')));
    });

    test('stores a salted PBKDF2 hash, never the passphrase or the token',
        () async {
      final token = await h.createAccount('ada', passphrase: 'plain text 12');
      final dump = h.storeDump;
      expect(dump, isNot(contains('plain text 12')));
      expect(dump, isNot(contains(token)));
      expect(dump, contains(r'pbkdf2-sha256$2$'));
      expect(dump, contains(sha256.convert(utf8.encode(token)).toString()));
    });

    test('refuses a handle that is already taken, in any letter case',
        () async {
      await h.createAccount('ada');
      for (final handle in ['ada', 'ADA', 'Ada']) {
        final response = await h.send(
          'POST',
          '/v1/accounts',
          json: {'handle': handle, 'passphrase': 'another passphrase'},
        );
        expectError(response, 409, 'handle_taken');
      }
      // The original passphrase still works; the duplicate changed nothing.
      expect((await h.signIn('ada')).status, 200);
      expect(
        (await h.signIn('ada', passphrase: 'another passphrase')).status,
        401,
      );
    });

    test('accepts handles of 3 and 32 characters', () async {
      await h.createAccount('abc');
      await h.createAccount('a' * 32);
    });

    test('refuses handles outside the allowed shape', () async {
      for (final handle in [
        'ab',
        'a' * 33,
        'has space',
        'dot.ted',
        'émile',
        'semi;colon',
        '',
        'tab\tbed',
      ]) {
        final response = await h.send(
          'POST',
          '/v1/accounts',
          json: {'handle': handle, 'passphrase': goodPassphrase},
        );
        expectError(response, 422, 'invalid_handle');
      }
    });

    test('tells the person not to use an email address', () async {
      final response = await h.send(
        'POST',
        '/v1/accounts',
        json: {'handle': 'ada@example.org', 'passphrase': goodPassphrase},
      );
      expectError(response, 422, 'invalid_handle');
      expect(response.errorMessage, contains('email address'));
      // The message never repeats what was sent.
      expect(response.body, isNot(contains('example.org')));
    });

    test('accepts passphrases of 12 and 256 characters', () async {
      await h.createAccount('twelve', passphrase: 'a' * 12);
      await h.createAccount('long', passphrase: 'a' * 256);
      // Length is counted in characters, not UTF-16 units or bytes.
      await h.createAccount('astral', passphrase: '\u{10400}' * 12);
      await h.createAccount('astral-max', passphrase: '\u{10400}' * 256);
    });

    test('refuses passphrases shorter than 12 or longer than 256 characters',
        () async {
      for (final passphrase in ['a' * 11, 'a' * 257, '', '\u{10400}' * 11]) {
        final response = await h.send(
          'POST',
          '/v1/accounts',
          json: {'handle': 'ada', 'passphrase': passphrase},
        );
        expectError(response, 422, 'invalid_passphrase');
      }
      expect(h.storeDump, isNot(contains('"handle":"ada"')));
    });

    test('refuses missing or non-string fields', () async {
      for (final body in [
        <String, Object?>{},
        {'handle': 'ada'},
        {'passphrase': goodPassphrase},
        {'handle': 7, 'passphrase': goodPassphrase},
        {'handle': 'ada', 'passphrase': 123456789012},
        {'handle': null, 'passphrase': goodPassphrase},
      ]) {
        final response = await h.send('POST', '/v1/accounts', json: body);
        expectError(response, 422, 'invalid_request');
      }
    });

    test('allows 10 attempts an hour per client, then answers 429', () async {
      final proxied = Harness(trustProxy: true);
      const client = {'x-forwarded-for': '203.0.113.7'};
      for (var i = 0; i < 10; i++) {
        await proxied.createAccount('user-$i', headers: client);
      }
      final blocked = await proxied.send(
        'POST',
        '/v1/accounts',
        json: {'handle': 'user-10', 'passphrase': goodPassphrase},
        headers: client,
      );
      expectError(blocked, 429, 'too_many_attempts');
      expect(blocked.headers['retry-after'], '3600');
      expect(proxied.storeDump, isNot(contains('user-10')));

      // Another client is not affected.
      await proxied.createAccount(
        'elsewhere',
        headers: {'x-forwarded-for': '203.0.113.8'},
      );

      // The limit lifts once the hour has passed.
      proxied.clock.advance(const Duration(minutes: 59, seconds: 59));
      expect(
        (await proxied.send(
          'POST',
          '/v1/accounts',
          json: {'handle': 'user-10', 'passphrase': goodPassphrase},
          headers: client,
        ))
            .status,
        429,
      );
      proxied.clock.advance(const Duration(seconds: 1));
      await proxied.createAccount('user-10', headers: client);
    });

    test('attempts that end in handle_taken count towards the limit', () async {
      await h.createAccount('ada');
      for (var i = 0; i < 9; i++) {
        final response = await h.send(
          'POST',
          '/v1/accounts',
          json: {'handle': 'ada', 'passphrase': goodPassphrase},
        );
        expect(response.status, 409);
      }
      final blocked = await h.send(
        'POST',
        '/v1/accounts',
        json: {'handle': 'ada', 'passphrase': goodPassphrase},
      );
      expectError(blocked, 429, 'too_many_attempts');
    });

    test('requests that fail validation do not count towards the limit',
        () async {
      for (var i = 0; i < 15; i++) {
        final response = await h.send(
          'POST',
          '/v1/accounts',
          json: {'handle': 'x', 'passphrase': goodPassphrase},
        );
        expect(response.status, 422);
      }
      await h.createAccount('ada');
    });
  });

  group('POST /v1/sessions', () {
    setUp(() => h.createAccount('ada'));

    test('returns a new token on each sign-in', () async {
      final first = await h.signIn('ada');
      final second = await h.signIn('ada');
      expect(first.status, 200);
      expect(first.object.keys, unorderedEquals(['token', 'expiresAt']));
      expect(first.object['token'], isNot(second.object['token']));
      expect(first.headers['cache-control'], 'no-store');
      for (final response in [first, second]) {
        final export = await h.send(
          'GET',
          '/v1/export',
          token: response.object['token'] as String,
        );
        expect(export.status, 200);
      }
    });

    test('an account holds at most 20 sign-ins; one more revokes the oldest',
        () async {
      // The account was created with one token already.
      final first = (await h.signIn('ada')).object['token'] as String;
      h.clock.advance(const Duration(minutes: 1));
      final second = (await h.signIn('ada')).object['token'] as String;
      for (var i = 0; i < 17; i++) {
        h.clock.advance(const Duration(minutes: 1));
        expect((await h.signIn('ada')).status, 200);
      }
      // 20 sign-ins exist now: nothing has been revoked yet.
      final before = await h.send('GET', '/v1/export', token: first);
      expect(before.object['activeSignIns'], 20);

      h.clock.advance(const Duration(minutes: 1));
      expect((await h.signIn('ada')).status, 200);
      h.clock.advance(const Duration(minutes: 1));
      expect((await h.signIn('ada')).status, 200);

      // The creation token and then the first sign-in were the oldest.
      expect((await h.send('GET', '/v1/export', token: first)).status, 401);
      final after = await h.send('GET', '/v1/export', token: second);
      expect(after.status, 200);
      expect(after.object['activeSignIns'], 20);
    });

    test('an unknown handle and a wrong passphrase are indistinguishable',
        () async {
      final wrongPassphrase =
          await h.signIn('ada', passphrase: 'not the one!!');
      final unknownHandle =
          await h.signIn('nobody', passphrase: 'not the one!!');
      final malformedHandle = await h.signIn(
        'someone@example.org',
        passphrase: 'not the one!!',
      );

      for (final response in [
        wrongPassphrase,
        unknownHandle,
        malformedHandle
      ]) {
        expectError(response, 401, 'invalid_credentials');
      }
      expect(unknownHandle.body, wrongPassphrase.body);
      expect(unknownHandle.headers, wrongPassphrase.headers);
      expect(malformedHandle.body, wrongPassphrase.body);
      expect(malformedHandle.headers, wrongPassphrase.headers);
    });

    test('an unknown handle costs the same hashing work as a wrong passphrase',
        () async {
      Future<int> derivations(String handle, String passphrase) async {
        final before = h.hasher.derivationCount;
        await h.signIn(handle, passphrase: passphrase);
        return h.hasher.derivationCount - before;
      }

      expect(await derivations('ada', 'not the one!!'), 1);
      expect(await derivations('nobody', 'not the one!!'), 1);
      expect(await derivations('not a handle', 'not the one!!'), 1);
      expect(await derivations('nobody', ''), 1);
      expect(await derivations('ada', goodPassphrase), 1);
    });

    test('refuses missing or non-string fields', () async {
      for (final body in [
        <String, Object?>{},
        {'handle': 'ada'},
        {'handle': 'ada', 'passphrase': 5},
        {'handle': <String>[], 'passphrase': goodPassphrase},
      ]) {
        final response = await h.send('POST', '/v1/sessions', json: body);
        expectError(response, 422, 'invalid_request');
      }
    });

    test(
        '5 failures for a handle in 15 minutes lock it, even for the right '
        'passphrase', () async {
      for (var i = 0; i < 5; i++) {
        expect(
            (await h.signIn('ada', passphrase: 'wrong guess $i')).status, 401);
        h.clock.advance(const Duration(minutes: 1));
      }
      final blocked = await h.signIn('ada');
      expectError(blocked, 429, 'too_many_attempts');
      // The first failure was 5 minutes ago, so it leaves the window in 10.
      expect(blocked.headers['retry-after'], '600');
      expect(blocked.errorMessage, contains('600 seconds'));

      // A blocked attempt does no hashing at all.
      final before = h.hasher.derivationCount;
      await h.signIn('ada');
      expect(h.hasher.derivationCount, before);
    });

    test('the lock lifts when the window has passed', () async {
      for (var i = 0; i < 5; i++) {
        await h.signIn('ada', passphrase: 'wrong guess $i');
      }
      h.clock.advance(const Duration(minutes: 14, seconds: 59));
      final stillBlocked = await h.signIn('ada');
      expect(stillBlocked.status, 429);
      expect(stillBlocked.headers['retry-after'], '1');
      h.clock.advance(const Duration(seconds: 1));
      expect((await h.signIn('ada')).status, 200);
    });

    test('a lock on one handle does not affect another', () async {
      await h.createAccount('bea');
      for (var i = 0; i < 5; i++) {
        await h.signIn('ada', passphrase: 'wrong guess $i');
      }
      expect((await h.signIn('ada')).status, 429);
      expect((await h.signIn('bea')).status, 200);
    });

    test('unknown handles are locked exactly like real ones', () async {
      for (var i = 0; i < 5; i++) {
        expect(
          (await h.signIn('nobody', passphrase: 'wrong guess $i')).status,
          401,
        );
      }
      final unknown = await h.signIn('nobody', passphrase: 'wrong guess 5');

      final other = Harness();
      await other.createAccount('nobody');
      for (var i = 0; i < 5; i++) {
        await other.signIn('nobody', passphrase: 'wrong guess $i');
      }
      final real = await other.signIn('nobody', passphrase: 'wrong guess 5');

      expect(unknown.status, 429);
      expect(unknown.body, real.body);
      expect(unknown.headers, real.headers);
    });

    test('successful sign-ins are not counted as failures', () async {
      for (var i = 0; i < 12; i++) {
        expect((await h.signIn('ada')).status, 200);
      }
      // Four failures are still allowed before the fifth locks the handle.
      for (var i = 0; i < 4; i++) {
        expect(
            (await h.signIn('ada', passphrase: 'wrong guess $i')).status, 401);
      }
      expect((await h.signIn('ada')).status, 200);
    });

    test('parallel guesses cannot outrun the limit', () async {
      final responses = await Future.wait([
        for (var i = 0; i < 12; i++)
          h.signIn('ada', passphrase: 'wrong $i....'),
      ]);
      expect(responses.where((r) => r.status == 401), hasLength(5));
      expect(responses.where((r) => r.status == 429), hasLength(7));
    });

    test(
        '20 failures per client in 15 minutes lock that client, across '
        'handles', () async {
      final proxied = Harness(trustProxy: true);
      await proxied.createAccount('ada');
      const attacker = {'x-forwarded-for': '198.51.100.9, 10.0.0.1'};
      for (var i = 0; i < 20; i++) {
        final response = await proxied.signIn(
          'victim-$i',
          passphrase: 'wrong guess!',
          headers: attacker,
        );
        expect(response.status, 401);
      }
      final blocked = await proxied.signIn('ada', headers: attacker);
      expectError(blocked, 429, 'too_many_attempts');
      expect(blocked.headers['retry-after'], '900');

      // Someone else can still sign in to the same account.
      final other = await proxied.signIn(
        'ada',
        headers: {'x-forwarded-for': '198.51.100.10'},
      );
      expect(other.status, 200);

      proxied.clock.advance(const Duration(minutes: 15));
      expect((await proxied.signIn('ada', headers: attacker)).status, 200);
    });

    test('X-Forwarded-For is ignored unless the proxy is trusted', () async {
      // Without TRUST_PROXY a client cannot dodge the per-client limit by
      // inventing a new forwarded address for every request.
      for (var i = 0; i < 20; i++) {
        await h.signIn(
          'victim-$i',
          passphrase: 'wrong guess!',
          headers: {'x-forwarded-for': '198.51.100.$i'},
        );
      }
      final blocked = await h.signIn(
        'ada',
        headers: {'x-forwarded-for': '198.51.100.200'},
      );
      expect(blocked.status, 429);
    });

    test('raising the work factor upgrades the stored hash at next sign-in',
        () async {
      expect(h.storeDump, contains(r'pbkdf2-sha256$2$'));
      final raised = Harness(store: h.store, iterations: 5);

      expect(
          (await raised.signIn('ada', passphrase: 'wrong guess!')).status, 401);
      expect(h.storeDump, contains(r'pbkdf2-sha256$2$'));

      final response = await raised.signIn('ada');
      expect(response.status, 200);
      expect(h.storeDump, contains(r'pbkdf2-sha256$5$'));
      expect(h.storeDump, isNot(contains(r'pbkdf2-sha256$2$')));

      // The token issued alongside the upgrade works, and so does the next
      // sign-in against the upgraded hash.
      final export = await raised.send(
        'GET',
        '/v1/export',
        token: response.object['token'] as String,
      );
      expect(export.status, 200);
      expect((await raised.signIn('ada')).status, 200);
    });
  });

  group('bearer tokens', () {
    late String token;

    setUp(() async => token = await h.createAccount('ada'));

    test('missing, malformed and unknown tokens all answer 401 invalid_token',
        () async {
      final responses = [
        await h.send('GET', '/v1/export'),
        await h.send('GET', '/v1/export', token: 'short'),
        await h.send('GET', '/v1/export', token: 'A' * 43),
        await h.send('GET', '/v1/export', token: '$token-extra'),
        await h.send(
          'GET',
          '/v1/export',
          headers: {'authorization': 'Basic $token'},
        ),
        await h.send('GET', '/v1/export', headers: {'authorization': token}),
        await h.send('GET', '/v1/export', headers: {'authorization': 'Bearer'}),
      ];
      for (final response in responses) {
        expectError(response, 401, 'invalid_token');
        expect(response.headers['www-authenticate'], 'Bearer');
        expect(response.body, responses.first.body);
      }
    });

    test('the scheme name is not case sensitive', () async {
      final response = await h.send(
        'GET',
        '/v1/export',
        headers: {'authorization': 'bearer $token'},
      );
      expect(response.status, 200);
    });

    test('every authenticated route refuses a request without a token',
        () async {
      const routes = [
        ('DELETE', '/v1/sessions/current'),
        ('PUT', '/v1/account/passphrase'),
        ('DELETE', '/v1/account'),
        ('GET', '/v1/consents'),
        ('PUT', '/v1/consents/sync'),
        ('GET', '/v1/profile'),
        ('PUT', '/v1/profile'),
        ('GET', '/v1/export'),
      ];
      for (final (method, path) in routes) {
        final response = await h.send(
          method,
          path,
          json: method == 'GET' ? null : <String, Object?>{},
        );
        expectError(response, 401, 'invalid_token');
      }
    });

    test('a token works until 30 days have passed, and not after', () async {
      h.clock.advance(const Duration(days: 30) - const Duration(seconds: 1));
      expect((await h.send('GET', '/v1/export', token: token)).status, 200);

      h.clock.advance(const Duration(seconds: 1));
      final expired = await h.send('GET', '/v1/export', token: token);
      expectError(expired, 401, 'invalid_token');

      // An expired token is removed when it is presented.
      expect(
        h.storeDump,
        isNot(contains(sha256.convert(utf8.encode(token)).toString())),
      );
      // Turning the clock back does not revive it.
      h.clock.advance(const Duration(days: -10));
      expect((await h.send('GET', '/v1/export', token: token)).status, 401);
    });

    test('an expired token is indistinguishable from an unknown one', () async {
      h.clock.advance(const Duration(days: 31));
      final expired = await h.send('GET', '/v1/export', token: token);
      final unknown = await h.send('GET', '/v1/export', token: 'B' * 43);
      expect(expired.body, unknown.body);
      expect(expired.headers, unknown.headers);
    });
  });

  group('DELETE /v1/sessions/current', () {
    test('revokes that token and no other', () async {
      final first = await h.createAccount('ada');
      final second = (await h.signIn('ada')).object['token'] as String;

      final response = await h.send(
        'DELETE',
        '/v1/sessions/current',
        token: first,
      );
      expect(response.status, 204);
      expect(response.body, isEmpty);
      expect(response.headers['cache-control'], 'no-store');

      expectError(
        await h.send('GET', '/v1/export', token: first),
        401,
        'invalid_token',
      );
      expect((await h.send('GET', '/v1/export', token: second)).status, 200);

      // Signing out twice: the token is already gone.
      expectError(
        await h.send('DELETE', '/v1/sessions/current', token: first),
        401,
        'invalid_token',
      );
    });
  });

  group('PUT /v1/account/passphrase', () {
    const newPassphrase = 'a brand new passphrase';
    late String token;

    setUp(() async => token = await h.createAccount('ada'));

    Future<ApiResponse> change(
      String usingToken, {
      String current = goodPassphrase,
      String replacement = newPassphrase,
    }) {
      return h.send(
        'PUT',
        '/v1/account/passphrase',
        token: usingToken,
        json: {'currentPassphrase': current, 'newPassphrase': replacement},
      );
    }

    test('changes the passphrase and revokes every other token', () async {
      final second = (await h.signIn('ada')).object['token'] as String;
      final third = (await h.signIn('ada')).object['token'] as String;

      final response = await change(second);
      expect(response.status, 204);
      expect(response.body, isEmpty);

      // The token that made the change keeps working; the others do not.
      expect((await h.send('GET', '/v1/export', token: second)).status, 200);
      for (final revoked in [token, third]) {
        expectError(
          await h.send('GET', '/v1/export', token: revoked),
          401,
          'invalid_token',
        );
      }

      expect((await h.signIn('ada')).status, 401);
      expect((await h.signIn('ada', passphrase: newPassphrase)).status, 200);
      expect(h.storeDump, isNot(contains(newPassphrase)));
    });

    test('tokens of other accounts are untouched', () async {
      final other = await h.createAccount('bea');
      expect((await change(token)).status, 204);
      expect((await h.send('GET', '/v1/export', token: other)).status, 200);
    });

    test('refuses a wrong current passphrase and changes nothing', () async {
      final second = (await h.signIn('ada')).object['token'] as String;
      final response = await change(token, current: 'not the current one');
      expectError(response, 403, 'incorrect_passphrase');
      expect((await h.signIn('ada')).status, 200);
      expect((await h.send('GET', '/v1/export', token: second)).status, 200);
    });

    test('refuses a new passphrase that breaks the rules', () async {
      for (final replacement in ['short', 'a' * 257]) {
        expectError(
          await change(token, replacement: replacement),
          422,
          'invalid_passphrase',
        );
      }
      expectError(
        await change(token, replacement: goodPassphrase),
        422,
        'invalid_passphrase',
      );
      expect((await h.signIn('ada')).status, 200);
    });

    test('refuses missing fields', () async {
      final response = await h.send(
        'PUT',
        '/v1/account/passphrase',
        token: token,
        json: {'newPassphrase': newPassphrase},
      );
      expectError(response, 422, 'invalid_request');
    });

    test('wrong guesses with a valid token are rate limited', () async {
      for (var i = 0; i < 5; i++) {
        expect((await change(token, current: 'wrong guess $i')).status, 403);
      }
      final blocked = await change(token);
      expectError(blocked, 429, 'too_many_attempts');
      expect(blocked.headers['retry-after'], '900');
      expect((await h.signIn('ada')).status, 429);

      h.clock.advance(const Duration(minutes: 15));
      expect((await change(token)).status, 204);
    });
  });

  group('DELETE /v1/account', () {
    const secretNote = 'a private note about pharmacy school';
    late String token;

    setUp(() async {
      token = await h.createAccount('ada');
      await h.setSyncConsent(token, granted: true);
      await h.send(
        'PUT',
        '/v1/profile',
        token: token,
        json: {
          'baseRevision': 0,
          'data': {'note': secretNote},
        },
      );
    });

    Future<ApiResponse> delete(String usingToken, {Object? passphrase}) {
      return h.send(
        'DELETE',
        '/v1/account',
        token: usingToken,
        json: {'passphrase': passphrase ?? goodPassphrase},
      );
    }

    test('removes the account, consents, profile and every token', () async {
      final second = (await h.signIn('ada')).object['token'] as String;
      final bystander = await h.createAccount('bea');
      expect(h.storeDump, contains(secretNote));

      final response = await delete(token);
      expect(response.status, 204);
      expect(response.body, isEmpty);

      for (final revoked in [token, second]) {
        expectError(
          await h.send('GET', '/v1/export', token: revoked),
          401,
          'invalid_token',
        );
      }
      expectError(await h.signIn('ada'), 401, 'invalid_credentials');

      // Nothing about the deleted account is left in the store.
      final snapshot = (h.store as InMemoryServerStore).snapshot();
      expect(snapshot['accounts'], hasLength(1));
      expect(snapshot['tokens'], hasLength(1));
      expect((snapshot['consents'] as Map).keys, isEmpty);
      expect((snapshot['profiles'] as Map).keys, isEmpty);
      expect(h.storeDump, isNot(contains('"ada"')));
      expect(h.storeDump, isNot(contains(secretNote)));

      // The other account is untouched.
      expect((await h.send('GET', '/v1/export', token: bystander)).status, 200);
    });

    test('frees the handle, and the new owner inherits nothing', () async {
      await delete(token);
      final fresh =
          await h.createAccount('ada', passphrase: 'someone else now');
      final export = await h.send('GET', '/v1/export', token: fresh);
      expect(export.object['consents'], isEmpty);
      expect(export.object['profile'], isNull);
      expect(export.object['activeSignIns'], 1);
      expectError(
        await h.send('GET', '/v1/profile', token: fresh),
        404,
        'no_profile',
      );
      // The old token does not reach the new account.
      expect((await h.send('GET', '/v1/export', token: token)).status, 401);
    });

    test('requires the passphrase again and deletes nothing without it',
        () async {
      expectError(
        await delete(token, passphrase: 'not the passphrase'),
        403,
        'incorrect_passphrase',
      );
      expectError(
        await h.send(
          'DELETE',
          '/v1/account',
          token: token,
          json: <String, Object?>{},
        ),
        422,
        'invalid_request',
      );
      expectError(await delete(token, passphrase: 12), 422, 'invalid_request');
      expectError(
        await h.send('DELETE', '/v1/account', token: token),
        415,
        'unsupported_media_type',
      );
      expect((await h.send('GET', '/v1/export', token: token)).status, 200);
      expect(h.storeDump, contains(secretNote));
    });

    test('wrong guesses with a valid token are rate limited', () async {
      for (var i = 0; i < 5; i++) {
        expect((await delete(token, passphrase: 'wrong guess $i')).status, 403);
      }
      expectError(await delete(token), 429, 'too_many_attempts');
      expect((await h.send('GET', '/v1/export', token: token)).status, 200);
    });
  });
}

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  late Harness h;
  late String token;

  setUp(() async {
    h = Harness();
    token = await h.createAccount('ada');
  });

  Future<ApiResponse> putProfile(
    String usingToken,
    int baseRevision,
    Object? data,
  ) {
    return h.send(
      'PUT',
      '/v1/profile',
      token: usingToken,
      json: {'baseRevision': baseRevision, 'data': data},
    );
  }

  group('consents', () {
    test('GET returns an empty object before any decision', () async {
      final response = await h.send('GET', '/v1/consents', token: token);
      expect(response.status, 200);
      expect(response.object, {'consents': <String, Object?>{}});
      expect(response.headers['cache-control'], 'no-store');
    });

    test('PUT stores the decision and returns the stored record', () async {
      final response = await h.send(
        'PUT',
        '/v1/consents/sync',
        token: token,
        json: {'granted': true, 'policyVersion': '2026-01'},
      );
      expect(response.status, 200);
      expect(response.object, {
        'granted': true,
        'at': h.clock.now.toIso8601String(),
        'policyVersion': '2026-01',
      });

      final listed = await h.send('GET', '/v1/consents', token: token);
      expect(listed.object, {
        'consents': {'sync': response.object},
      });
    });

    test('a later decision replaces the earlier one', () async {
      await h.setSyncConsent(token, granted: true);
      h.clock.advance(const Duration(days: 3));
      final response = await h.send(
        'PUT',
        '/v1/consents/sync',
        token: token,
        json: {'granted': false, 'policyVersion': '2026-02'},
      );
      expect(response.object['granted'], isFalse);

      final listed = await h.send('GET', '/v1/consents', token: token);
      final sync = (listed.object['consents'] as Map)['sync'] as Map;
      expect(sync['granted'], isFalse);
      expect(sync['policyVersion'], '2026-02');
      expect(sync['at'], h.clock.now.toIso8601String());
    });

    test('refuses a body without a boolean and a policy version', () async {
      for (final body in [
        <String, Object?>{},
        {'granted': true},
        {'policyVersion': '2026-01'},
        {'granted': 'yes', 'policyVersion': '2026-01'},
        {'granted': 1, 'policyVersion': '2026-01'},
        {'granted': true, 'policyVersion': ''},
        {'granted': true, 'policyVersion': 7},
        {'granted': true, 'policyVersion': 'v' * 65},
      ]) {
        final response = await h.send(
          'PUT',
          '/v1/consents/sync',
          token: token,
          json: body,
        );
        expectError(response, 422, 'invalid_request');
      }
      final listed = await h.send('GET', '/v1/consents', token: token);
      expect(listed.object['consents'], isEmpty);
    });

    test('only the sync purpose exists', () async {
      final response = await h.send(
        'PUT',
        '/v1/consents/marketing',
        token: token,
        json: {'granted': true, 'policyVersion': '2026-01'},
      );
      expectError(response, 404, 'not_found');
    });

    test('each account has its own consents', () async {
      final other = await h.createAccount('bea');
      await h.setSyncConsent(token, granted: true);
      final listed = await h.send('GET', '/v1/consents', token: other);
      expect(listed.object['consents'], isEmpty);
    });
  });

  group('profile', () {
    test('GET answers 404 no_profile before anything is stored', () async {
      expectError(
        await h.send('GET', '/v1/profile', token: token),
        404,
        'no_profile',
      );
      await h.setSyncConsent(token, granted: true);
      expectError(
        await h.send('GET', '/v1/profile', token: token),
        404,
        'no_profile',
      );
    });

    test('PUT is refused until sync consent is granted', () async {
      expectError(
        await putProfile(token, 0, {'goal': 'explore'}),
        403,
        'consent_required',
      );
      await h.setSyncConsent(token, granted: false);
      expectError(
        await putProfile(token, 0, {'goal': 'explore'}),
        403,
        'consent_required',
      );
      expect(h.storeDump, isNot(contains('explore')));

      await h.setSyncConsent(token, granted: true);
      expect((await putProfile(token, 0, {'goal': 'explore'})).status, 200);
    });

    test('consent is checked before the body is read', () async {
      final response = await h.send(
        'PUT',
        '/v1/profile',
        token: token,
        body: 'this is not json',
        contentType: 'application/json',
      );
      expectError(response, 403, 'consent_required');
    });

    test('stores the document and returns it unchanged', () async {
      await h.setSyncConsent(token, granted: true);
      final data = {
        'goal': 'explore',
        'freeText': 'Not sure where to begin, é中\u{10400} "quoted"',
        'list': [1, 2.5, true, null, 'x'],
        'nested': {
          'deeper': {'empty': <String, Object?>{}, 'none': <Object?>[]},
        },
      };
      final written = await putProfile(token, 0, data);
      expect(written.status, 200);
      expect(written.object, {
        'revision': 1,
        'updatedAt': h.clock.now.toIso8601String(),
      });
      expect(written.headers['cache-control'], 'no-store');

      final read = await h.send('GET', '/v1/profile', token: token);
      expect(read.status, 200);
      expect(read.object, {
        'revision': 1,
        'updatedAt': h.clock.now.toIso8601String(),
        'data': data,
      });
      expect(read.headers['cache-control'], 'no-store');
    });

    test('each write must be based on the stored revision', () async {
      await h.setSyncConsent(token, granted: true);
      expect((await putProfile(token, 0, {'n': 1})).object['revision'], 1);
      h.clock.advance(const Duration(minutes: 2));
      expect((await putProfile(token, 1, {'n': 2})).object['revision'], 2);
      final updatedAt = h.clock.now.toIso8601String();
      h.clock.advance(const Duration(minutes: 2));

      for (final stale in [0, 1, 3, 99]) {
        final conflict = await putProfile(token, stale, {'n': 'lost'});
        expectError(conflict, 409, 'revision_conflict');
        expect(conflict.object['current'], {
          'revision': 2,
          'updatedAt': updatedAt,
          'data': {'n': 2},
        });
      }

      // The conflict changed nothing, and the reported revision is the one
      // to build on.
      final read = await h.send('GET', '/v1/profile', token: token);
      expect(read.object['data'], {'n': 2});
      expect((await putProfile(token, 2, {'n': 3})).object['revision'], 3);
    });

    test('a non-zero base revision conflicts when nothing is stored', () async {
      await h.setSyncConsent(token, granted: true);
      final conflict = await putProfile(token, 4, {'n': 1});
      expectError(conflict, 409, 'revision_conflict');
      expect(conflict.object['current'], {
        'revision': 0,
        'updatedAt': null,
        'data': null,
      });
    });

    test('two devices writing at once: one wins, the other gets a conflict',
        () async {
      await h.setSyncConsent(token, granted: true);
      final responses = await Future.wait([
        putProfile(token, 0, {'device': 'phone'}),
        putProfile(token, 0, {'device': 'laptop'}),
      ]);
      expect(responses.map((r) => r.status), unorderedEquals([200, 409]));
    });

    test('refuses an invalid baseRevision or data', () async {
      await h.setSyncConsent(token, granted: true);
      for (final body in [
        <String, Object?>{},
        {'data': <String, Object?>{}},
        {'baseRevision': 0},
        {'baseRevision': -1, 'data': <String, Object?>{}},
        {'baseRevision': '0', 'data': <String, Object?>{}},
        {'baseRevision': 0.5, 'data': <String, Object?>{}},
        {'baseRevision': null, 'data': <String, Object?>{}},
        {'baseRevision': 0, 'data': 'text'},
        {'baseRevision': 0, 'data': <Object?>[]},
        {'baseRevision': 0, 'data': null},
      ]) {
        final response = await h.send(
          'PUT',
          '/v1/profile',
          token: token,
          json: body,
        );
        expectError(response, 422, 'invalid_request');
      }
      expectError(
        await h.send('GET', '/v1/profile', token: token),
        404,
        'no_profile',
      );
    });

    test('accepts data of exactly 256 KiB and refuses one byte more', () async {
      await h.setSyncConsent(token, granted: true);
      const limit = 256 * 1024;
      // {"k":"..."} is 8 bytes of framing around the string.
      final atLimit = {'k': 'a' * (limit - 8)};
      expect(utf8.encode(jsonEncode(atLimit)), hasLength(limit));

      final tooBig = await putProfile(token, 0, {'k': 'a' * (limit - 7)});
      expectError(tooBig, 413, 'body_too_large');
      expectError(
        await h.send('GET', '/v1/profile', token: token),
        404,
        'no_profile',
      );

      expect((await putProfile(token, 0, atLimit)).status, 200);
    });

    test('refuses data nested too deeply to store safely', () async {
      await h.setSyncConsent(token, granted: true);
      final deep = '${'[' * 5000}${']' * 5000}';
      final response = await h.send(
        'PUT',
        '/v1/profile',
        token: token,
        body: '{"baseRevision":0,"data":{"k":$deep}}',
        contentType: 'application/json',
      );
      expectError(response, 422, 'invalid_request');
      expect(response.errorMessage, contains('nested'));
    });

    test('each account has its own profile', () async {
      final other = await h.createAccount('bea');
      await h.setSyncConsent(token, granted: true);
      await h.setSyncConsent(other, granted: true);
      await putProfile(token, 0, {'owner': 'ada'});
      expectError(
        await h.send('GET', '/v1/profile', token: other),
        404,
        'no_profile',
      );
      await putProfile(other, 0, {'owner': 'bea'});
      final read = await h.send('GET', '/v1/profile', token: token);
      expect(read.object['data'], {'owner': 'ada'});
    });

    test('withdrawing consent deletes the stored profile immediately',
        () async {
      await h.setSyncConsent(token, granted: true);
      await putProfile(token, 0, {'note': 'keep this private'});
      expect(h.storeDump, contains('keep this private'));

      final withdrawn = await h.setSyncConsent(token, granted: false);
      expect(withdrawn.status, 200);
      expect(withdrawn.object['granted'], isFalse);

      expect(h.storeDump, isNot(contains('keep this private')));
      expectError(
        await h.send('GET', '/v1/profile', token: token),
        404,
        'no_profile',
      );
      expectError(
        await putProfile(token, 1, {'note': 'again'}),
        403,
        'consent_required',
      );
      final export = await h.send('GET', '/v1/export', token: token);
      expect(export.object['profile'], isNull);

      // Granting again does not restore it; the next write starts from 0.
      await h.setSyncConsent(token, granted: true);
      expectError(
        await h.send('GET', '/v1/profile', token: token),
        404,
        'no_profile',
      );
      final fresh = await putProfile(token, 0, {'note': 'new'});
      expect(fresh.object['revision'], 1);
    });
  });

  group('GET /v1/export', () {
    test('returns everything held about the account', () async {
      final createdAt = h.clock.now.toIso8601String();
      h.clock.advance(const Duration(hours: 1));
      await h.setSyncConsent(token, granted: true);
      final consentAt = h.clock.now.toIso8601String();
      await putProfile(token, 0, {'goal': 'explore'});
      await h.signIn('ada');
      h.clock.advance(const Duration(hours: 1));

      final response = await h.send('GET', '/v1/export', token: token);
      expect(response.status, 200);
      expect(response.headers['cache-control'], 'no-store');
      expect(response.object, {
        'handle': 'ada',
        'createdAt': createdAt,
        'consents': {
          'sync': {
            'granted': true,
            'at': consentAt,
            'policyVersion': '2026-01',
          },
        },
        'profile': {
          'revision': 1,
          'updatedAt': consentAt,
          'data': {'goal': 'explore'},
        },
        'activeSignIns': 2,
        'exportedAt': h.clock.now.toIso8601String(),
      });
    });

    test('profile is null and consents empty when nothing is stored', () async {
      final response = await h.send('GET', '/v1/export', token: token);
      expect(response.object['profile'], isNull);
      expect(response.object['consents'], isEmpty);
      expect(response.object['activeSignIns'], 1);
    });

    test('counts only sign-ins that are still usable', () async {
      h.clock.advance(const Duration(days: 20));
      final later = (await h.signIn('ada')).object['token'] as String;
      final third = (await h.signIn('ada')).object['token'] as String;
      expect(
        (await h.send('GET', '/v1/export', token: later))
            .object['activeSignIns'],
        3,
      );

      await h.send('DELETE', '/v1/sessions/current', token: third);
      expect(
        (await h.send('GET', '/v1/export', token: later))
            .object['activeSignIns'],
        2,
      );

      // The first token expires 30 days after it was issued.
      h.clock.advance(const Duration(days: 11));
      expect(
        (await h.send('GET', '/v1/export', token: later))
            .object['activeSignIns'],
        1,
      );
    });

    test('contains no hash, salt or token material', () async {
      await h.setSyncConsent(token, granted: true);
      await putProfile(token, 0, {'goal': 'explore'});
      final second = (await h.signIn('ada')).object['token'] as String;

      final response = await h.send('GET', '/v1/export', token: token);
      final body = response.body;

      final storedHash = RegExp(r'pbkdf2-sha256\$\d+\$([^$"]+)\$([^$"]+)')
          .firstMatch(h.storeDump)!;
      expect(body, isNot(contains('pbkdf2')));
      expect(body, isNot(contains(storedHash.group(0)!)));
      expect(body, isNot(contains(storedHash.group(1)!)), reason: 'salt');
      expect(body, isNot(contains(storedHash.group(2)!)), reason: 'hash');
      for (final issued in [token, second]) {
        expect(body, isNot(contains(issued)));
        expect(
          body,
          isNot(contains(sha256.convert(utf8.encode(issued)).toString())),
        );
      }
      expect(body, isNot(contains(goodPassphrase)));
      expect(body.toLowerCase(), isNot(contains('hash')));
      expect(body.toLowerCase(), isNot(contains('salt')));
      expect(
        response.object.keys,
        unorderedEquals([
          'handle',
          'createdAt',
          'consents',
          'profile',
          'activeSignIns',
          'exportedAt',
        ]),
      );
    });
  });
}

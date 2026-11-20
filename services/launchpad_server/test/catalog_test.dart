import 'dart:convert';

import 'package:test/test.dart';

import 'support.dart';

void main() {
  late Harness h;

  setUp(() => h = Harness());

  group('GET /v1/catalog/<name>', () {
    test('answers 404 no_catalog before anything is published', () async {
      for (final name in ['goals', 'occupations']) {
        expectError(
            await h.send('GET', '/v1/catalog/$name'), 404, 'no_catalog');
      }
    });

    test('answers 404 for names that are not catalogues', () async {
      for (final name in ['skills', 'GOALS', 'goals.json', '..']) {
        expectError(await h.send('GET', '/v1/catalog/$name'), 404, 'not_found');
      }
    });

    test('is public and returns the published document', () async {
      await h.publish('goals', validCatalog());
      final response = await h.send('GET', '/v1/catalog/goals');
      expect(response.status, 200);
      expect(response.object, {
        'revision': 1,
        'updatedAt': h.clock.now.toIso8601String(),
        'document': validCatalog(),
      });
      expect(response.headers['content-type'], 'application/json');
      expect(response.headers['x-content-type-options'], 'nosniff');
    });

    test('carries a strong ETag and allows revalidated caching', () async {
      await h.publish('goals', validCatalog());
      final response = await h.send('GET', '/v1/catalog/goals');
      final etag = response.headers['etag']!;
      expect(etag, matches(RegExp(r'^"[A-Za-z0-9_-]{43}"$')));
      expect(etag, isNot(startsWith('W/')));
      expect(response.headers['cache-control'], 'public, no-cache');

      // The same revision always has the same ETag.
      final again = await h.send('GET', '/v1/catalog/goals');
      expect(again.headers['etag'], etag);
    });

    test('If-None-Match with the current ETag answers 304 with no body',
        () async {
      await h.publish('goals', validCatalog());
      final etag = (await h.send('GET', '/v1/catalog/goals')).headers['etag']!;

      for (final header in [etag, 'W/$etag', '"other", $etag', '*']) {
        final response = await h.send(
          'GET',
          '/v1/catalog/goals',
          headers: {'if-none-match': header},
        );
        expect(response.status, 304, reason: header);
        expect(response.body, isEmpty);
        expect(response.headers['etag'], etag);
        expect(response.headers['cache-control'], 'public, no-cache');
        expect(response.headers['x-content-type-options'], 'nosniff');
      }
    });

    test('If-None-Match with another ETag answers 200 with the document',
        () async {
      await h.publish('goals', validCatalog());
      final response = await h.send(
        'GET',
        '/v1/catalog/goals',
        headers: {'if-none-match': '"something-else"'},
      );
      expect(response.status, 200);
      expect(response.object['revision'], 1);
    });

    test('the ETag changes when a new revision is published', () async {
      await h.publish('goals', validCatalog());
      final first = (await h.send('GET', '/v1/catalog/goals')).headers['etag']!;
      await h.publish('goals', validCatalog(title: 'Explore your options'));

      final response = await h.send(
        'GET',
        '/v1/catalog/goals',
        headers: {'if-none-match': first},
      );
      expect(response.status, 200);
      expect(response.headers['etag'], isNot(first));
      expect(response.object['revision'], 2);
    });

    test('the two catalogues are independent', () async {
      await h.publish('goals', validCatalog());
      expectError(
        await h.send('GET', '/v1/catalog/occupations'),
        404,
        'no_catalog',
      );
      await h.publish('occupations', {
        'schemaVersion': 2,
        'items': [
          {'id': 'pharmacist'},
        ],
      });
      final goals = await h.send('GET', '/v1/catalog/goals');
      final occupations = await h.send('GET', '/v1/catalog/occupations');
      expect(goals.object['document'], validCatalog());
      expect((occupations.object['document'] as Map)['schemaVersion'], 2);
      expect(goals.headers['etag'], isNot(occupations.headers['etag']));
    });

    test('HEAD returns the headers without the body', () async {
      await h.publish('goals', validCatalog());
      final response = await h.send('HEAD', '/v1/catalog/goals');
      expect(response.status, 200);
      expect(response.body, isEmpty);
      expect(response.headers['etag'], isNotNull);
    });
  });

  group('PUT /v1/admin/catalog/<name>', () {
    test('publishes and increments the revision each time', () async {
      final first = await h.publish('goals', validCatalog());
      expect(first.status, 200);
      expect(first.object, {
        'revision': 1,
        'updatedAt': h.clock.now.toIso8601String(),
      });
      expect(first.headers['cache-control'], 'no-store');

      h.clock.advance(const Duration(hours: 2));
      final second = await h.publish('goals', validCatalog(title: 'Changed'));
      expect(second.object, {
        'revision': 2,
        'updatedAt': h.clock.now.toIso8601String(),
      });
    });

    test('requires the admin token', () async {
      final userToken = await h.createAccount('ada');
      final attempts = [
        await h.send('PUT', '/v1/admin/catalog/goals', json: validCatalog()),
        await h.send(
          'PUT',
          '/v1/admin/catalog/goals',
          json: validCatalog(),
          token: 'wrong-admin-token-0123456789abcdef',
        ),
        await h.send(
          'PUT',
          '/v1/admin/catalog/goals',
          json: validCatalog(),
          token: '${testAdminToken}x',
        ),
        await h.send(
          'PUT',
          '/v1/admin/catalog/goals',
          json: validCatalog(),
          token: testAdminToken.substring(0, testAdminToken.length - 1),
        ),
        await h.send(
          'PUT',
          '/v1/admin/catalog/goals',
          json: validCatalog(),
          token: userToken,
        ),
        await h.send(
          'PUT',
          '/v1/admin/catalog/goals',
          json: validCatalog(),
          headers: {'authorization': 'Basic $testAdminToken'},
        ),
      ];
      for (final response in attempts) {
        expectError(response, 401, 'invalid_token');
        expect(response.body, isNot(contains(testAdminToken)));
      }
      expectError(await h.send('GET', '/v1/catalog/goals'), 404, 'no_catalog');
    });

    test('the admin token is not a user token', () async {
      expectError(
        await h.send('GET', '/v1/export', token: testAdminToken),
        401,
        'invalid_token',
      );
    });

    test('answers 404 for names that are not catalogues', () async {
      expectError(await h.publish('skills', validCatalog()), 404, 'not_found');
    });

    test('does not reveal which names exist to callers without the token',
        () async {
      final real = await h.send(
        'PUT',
        '/v1/admin/catalog/goals',
        json: validCatalog(),
      );
      final unreal = await h.send(
        'PUT',
        '/v1/admin/catalog/skills',
        json: validCatalog(),
      );
      expect(unreal.status, real.status);
      expect(unreal.body, real.body);
    });

    test('refuses an invalid document with the list of problems', () async {
      final response = await h.publish('goals', {
        'schemaVersion': '1',
        'items': [
          {'id': 'a'},
          {'id': 'a'},
          {'title': 'no id'},
        ],
      });
      expectError(response, 422, 'invalid_catalog');
      final error = response.object['error'] as Map<String, Object?>;
      expect(error['problems'], [
        '"schemaVersion" must be an integer.',
        'items[1].id repeats an id used by an earlier item.',
        'items[2].id must be a non-empty string.',
      ]);
      expectError(await h.send('GET', '/v1/catalog/goals'), 404, 'no_catalog');
    });

    test('refuses a body that is JSON but not an object', () async {
      for (final document in [<Object?>[], 'text', 7]) {
        final response = await h.send(
          'PUT',
          '/v1/admin/catalog/goals',
          token: testAdminToken,
          body: jsonEncode(document),
          contentType: 'application/json',
        );
        expectError(response, 422, 'invalid_catalog');
        expect(
          (response.object['error'] as Map)['problems'],
          ['The document must be a JSON object.'],
        );
      }
    });

    test('refuses outcome promises in nested strings', () async {
      final response = await h.publish('goals', {
        'schemaVersion': 1,
        'items': [
          {
            'id': 'interviews',
            'title': 'Prepare for interviews',
            'sections': [
              {
                'heading': 'Practice',
                'steps': [
                  {'text': 'Answer common questions out loud.'},
                  {'text': 'This approach will LAND YOU the offer.'},
                ],
              },
            ],
          },
        ],
        'meta': {'tagline': 'Results guaranteed'},
      });
      expectError(response, 422, 'invalid_catalog');
      final problems = ((response.object['error'] as Map)['problems'] as List)
          .cast<String>();
      expect(problems, hasLength(2));
      expect(
        problems[0],
        startsWith('items[0].sections[0].steps[1].text contains'),
      );
      expect(problems[1], startsWith('meta.tagline contains'));
      expectError(await h.send('GET', '/v1/catalog/goals'), 404, 'no_catalog');
    });

    test('a refused document leaves the published revision in place', () async {
      await h.publish('goals', validCatalog());
      final refused = await h.publish(
        'goals',
        validCatalog(title: 'We guarantee you a job'),
      );
      expect(refused.status, 422);
      final current = await h.send('GET', '/v1/catalog/goals');
      expect(current.object['revision'], 1);
      expect(current.object['document'], validCatalog());
    });

    test('refuses documents larger than 1 MiB', () async {
      final response = await h.publish('goals', {
        'schemaVersion': 1,
        'items': [
          {'id': 'big', 'text': 'a' * (1024 * 1024)},
        ],
      });
      expectError(response, 413, 'body_too_large');
    });

    test('accepts a large document under the limit', () async {
      final document = {
        'schemaVersion': 1,
        'items': [
          for (var i = 0; i < 2000; i++) {'id': 'item-$i', 'text': 'b' * 400},
        ],
      };
      expect((await h.publish('goals', document)).status, 200);
      final read = await h.send('GET', '/v1/catalog/goals');
      expect((read.object['document'] as Map)['items'], hasLength(2000));
    });

    test('refuses invalid JSON and other content types', () async {
      expectError(
        await h.send(
          'PUT',
          '/v1/admin/catalog/goals',
          token: testAdminToken,
          body: '{"schemaVersion": 1, "items": [',
          contentType: 'application/json',
        ),
        400,
        'invalid_json',
      );
      expectError(
        await h.send(
          'PUT',
          '/v1/admin/catalog/goals',
          token: testAdminToken,
          body: jsonEncode(validCatalog()),
          contentType: 'text/plain',
        ),
        415,
        'unsupported_media_type',
      );
    });
  });

  group('POST /v1/admin/catalog/<name>/rollback', () {
    Future<ApiResponse> rollback(String name,
        {String? token = testAdminToken}) {
      return h.send('POST', '/v1/admin/catalog/$name/rollback', token: token);
    }

    test('restores the previous document under a new revision', () async {
      await h.publish('goals', validCatalog(title: 'First'));
      await h.publish('goals', validCatalog(title: 'Second'));
      final etagBefore =
          (await h.send('GET', '/v1/catalog/goals')).headers['etag']!;
      h.clock.advance(const Duration(minutes: 30));

      final response = await rollback('goals');
      expect(response.status, 200);
      expect(response.object, {
        'revision': 3,
        'updatedAt': h.clock.now.toIso8601String(),
      });

      final current = await h.send(
        'GET',
        '/v1/catalog/goals',
        headers: {'if-none-match': etagBefore},
      );
      expect(current.status, 200);
      expect(current.object['revision'], 3);
      expect(current.object['document'], validCatalog(title: 'First'));
    });

    test('a second rollback undoes the first', () async {
      await h.publish('goals', validCatalog(title: 'First'));
      await h.publish('goals', validCatalog(title: 'Second'));
      await rollback('goals');
      final response = await rollback('goals');
      expect(response.object['revision'], 4);
      final current = await h.send('GET', '/v1/catalog/goals');
      expect(current.object['document'], validCatalog(title: 'Second'));
    });

    test('answers 409 when there is only one revision', () async {
      await h.publish('goals', validCatalog());
      expectError(await rollback('goals'), 409, 'no_previous_revision');
      expect((await h.send('GET', '/v1/catalog/goals')).object['revision'], 1);
    });

    test('answers 404 when nothing was ever published or the name is unknown',
        () async {
      expectError(await rollback('goals'), 404, 'no_catalog');
      expectError(await rollback('skills'), 404, 'not_found');
    });

    test('requires the admin token', () async {
      await h.publish('goals', validCatalog(title: 'First'));
      await h.publish('goals', validCatalog(title: 'Second'));
      expectError(await rollback('goals', token: null), 401, 'invalid_token');
      expectError(
        await rollback('goals', token: 'not-the-admin-token-0123456789abc'),
        401,
        'invalid_token',
      );
      expect((await h.send('GET', '/v1/catalog/goals')).object['revision'], 2);
    });

    test('rolls back one catalogue without touching the other', () async {
      await h.publish('goals', validCatalog(title: 'First'));
      await h.publish('goals', validCatalog(title: 'Second'));
      await h.publish('occupations', validCatalog(title: 'Occupations'));
      await rollback('goals');
      final occupations = await h.send('GET', '/v1/catalog/occupations');
      expect(occupations.object['revision'], 1);
    });
  });

  group('with no admin token configured', () {
    setUp(() => h = Harness(adminToken: null));

    test('admin routes answer 404, exactly like an address that is not there',
        () async {
      final missing = await h.send('PUT', '/v1/no/such/route');
      expectError(missing, 404, 'not_found');

      final attempts = [
        await h.send('PUT', '/v1/admin/catalog/goals', json: validCatalog()),
        await h.publish('goals', validCatalog()),
        await h.send(
          'POST',
          '/v1/admin/catalog/goals/rollback',
          token: testAdminToken,
        ),
        await h.send('POST', '/v1/admin/catalog/goals/rollback'),
        await h.send(
          'PUT',
          '/v1/admin/catalog/goals',
          json: validCatalog(),
          headers: {'authorization': 'Bearer '},
        ),
      ];
      for (final response in attempts) {
        expectError(response, 404, 'not_found');
        expect(response.body, missing.body);
        expect(response.headers.containsKey('www-authenticate'), isFalse);
      }
    });

    test('the public catalogue route still works', () async {
      expectError(await h.send('GET', '/v1/catalog/goals'), 404, 'no_catalog');
    });
  });
}

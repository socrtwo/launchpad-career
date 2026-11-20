import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:launchpad_server/launchpad_server.dart';
import 'package:test/test.dart';

import 'support.dart';

const String _origin = 'https://app.example.org';

final class _FakeConnection implements HttpConnectionInfo {
  _FakeConnection(String address) : remoteAddress = InternetAddress(address);

  @override
  final InternetAddress remoteAddress;

  @override
  int get localPort => 8080;

  @override
  int get remotePort => 50123;
}

/// A store whose every operation fails, with a message that must never
/// reach a client or a log.
final class _BrokenStore implements ServerStore {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw StateError('disk failure in /secret/location for handle ada');
  }
}

void main() {
  late Harness h;

  setUp(() => h = Harness(allowedOrigins: [_origin]));

  group('GET /healthz', () {
    test('answers 200 with the status and nothing else', () async {
      final response = await h.send('GET', '/healthz');
      expect(response.status, 200);
      expect(response.body, '{"status":"ok"}');
      expect(response.headers['content-type'], 'application/json');
    });

    test('says nothing about the store, even when the store is failing',
        () async {
      final broken = Harness(store: _BrokenStore());
      final response = await broken.send('GET', '/healthz');
      expect(response.status, 200);
      expect(response.body, '{"status":"ok"}');
    });
  });

  group('errors', () {
    test('an address that does not exist answers 404 not_found', () async {
      for (final (method, path) in [
        ('GET', '/'),
        ('GET', '/v1'),
        ('GET', '/v1/accounts'),
        ('POST', '/healthz'),
        ('PATCH', '/v1/profile'),
        ('GET', '/v1/admin/catalog/goals'),
        ('GET', '/v1/profile/extra'),
      ]) {
        expectError(await h.send(method, path), 404, 'not_found');
      }
    });

    test('every error has the one shape, a snake_case code and a full sentence',
        () async {
      final token = await h.createAccount('ada');
      final responses = [
        await h.send('GET', '/nowhere'),
        await h.send('GET', '/v1/export'),
        await h.send('GET', '/v1/profile', token: token),
        await h.send('GET', '/v1/catalog/goals'),
        await h.signIn('ada', passphrase: 'wrong guess!'),
        await h.send(
          'POST',
          '/v1/accounts',
          json: {'handle': 'ada', 'passphrase': goodPassphrase},
        ),
        await h.send(
          'POST',
          '/v1/accounts',
          json: {'handle': 'a@b', 'passphrase': goodPassphrase},
        ),
        await h.send(
          'POST',
          '/v1/accounts',
          json: {'handle': 'bea', 'passphrase': 'short'},
        ),
        await h.send(
          'PUT',
          '/v1/profile',
          token: token,
          json: {'baseRevision': 0, 'data': <String, Object?>{}},
        ),
        await h.send(
          'POST',
          '/v1/sessions',
          body: '{',
          contentType: 'application/json',
        ),
        await h.send('POST', '/v1/sessions', body: '{}'),
        await h.send('PUT', '/v1/admin/catalog/goals', json: validCatalog()),
        await h.publish('goals', {'schemaVersion': 1}),
        await h.send(
          'POST',
          '/v1/admin/catalog/goals/rollback',
          token: testAdminToken,
        ),
      ];
      final codes = <String>{};
      for (final response in responses) {
        expect(response.status, greaterThanOrEqualTo(400));
        expectError(response, response.status, response.errorCode);
        expect(response.headers['content-type'], 'application/json');
        expect(response.headers['x-content-type-options'], 'nosniff');
        expect(response.headers['cache-control'], 'no-store');
        // The error object has a code and a message, plus "problems" for
        // an invalid catalogue. Nothing else.
        final error = response.object['error'] as Map<String, Object?>;
        expect(
          error.keys.toSet().difference({'code', 'message', 'problems'}),
          isEmpty,
        );
        codes.add(response.errorCode);
      }
      expect(
        codes,
        containsAll([
          'not_found',
          'invalid_token',
          'no_profile',
          'no_catalog',
          'invalid_credentials',
          'handle_taken',
          'invalid_handle',
          'invalid_passphrase',
          'consent_required',
          'invalid_json',
          'unsupported_media_type',
          'invalid_catalog',
        ]),
      );
    });

    test('an unexpected failure answers 500 without saying why', () async {
      final broken = Harness(store: _BrokenStore());
      final response = await broken.send(
        'GET',
        '/v1/export',
        token: 'A' * 43,
      );
      expectError(response, 500, 'internal_error');
      expect(response.body, isNot(contains('disk failure')));
      expect(response.body, isNot(contains('secret')));
      expect(response.headers['cache-control'], 'no-store');

      // The log names the kind of error, not its message.
      expect(
        broken.logs.single,
        matches(
          RegExp(
            r'^request method=GET route=/v1/export status=500 '
            r'duration_ms=\d+ error=StateError$',
          ),
        ),
      );
      expect(broken.logs.single, isNot(contains('disk failure')));
      expect(broken.logs.single, isNot(contains('ada')));
    });

    test('too many sign-ins queued at once answers 503 with Retry-After',
        () async {
      // One derivation at a time and no queue, with a work factor high
      // enough that the first derivation is still running when the
      // sign-ins below arrive.
      final hasher = PassphraseHasher(
        iterations: 50000,
        maxConcurrent: 1,
        maxQueued: 0,
      );
      final handler = buildHandler(
        ServerConfig(pbkdf2Iterations: 50000),
        InMemoryServerStore(),
        hasher: hasher,
      );
      final busy = Harness.around(handler);

      final occupied = hasher.hash('occupies the only slot');
      for (var i = 0; i < 8; i++) {
        final refused = await busy.signIn('ada');
        expectError(refused, 503, 'server_busy');
        expect(refused.headers['retry-after'], '5');
      }
      await occupied;

      // A sign-in that was turned away is not a failed attempt: after eight
      // of them the handle is still not locked.
      expectError(await busy.signIn('ada'), 401, 'invalid_credentials');
    });
  });

  group('request bodies', () {
    test('must be application/json', () async {
      final body = jsonEncode({'handle': 'ada', 'passphrase': goodPassphrase});
      for (final contentType in [
        null,
        'text/plain',
        'application/x-www-form-urlencoded',
        'application/json-seq',
        'text/json',
      ]) {
        final response = await h.send(
          'POST',
          '/v1/accounts',
          body: body,
          contentType: contentType,
        );
        expectError(response, 415, 'unsupported_media_type');
      }
      expect(h.storeDump, isNot(contains('ada')));
    });

    test('may carry a charset parameter', () async {
      final response = await h.send(
        'POST',
        '/v1/accounts',
        body: jsonEncode({'handle': 'ada', 'passphrase': goodPassphrase}),
        contentType: 'application/json; charset=utf-8',
      );
      expect(response.status, 201);
    });

    test('invalid JSON answers 400 invalid_json', () async {
      for (final body in [
        '',
        '{',
        '{"handle": "ada",}',
        "{'handle': 'ada'}",
        'handle=ada',
        '{"handle": "ada"} trailing',
      ]) {
        final response = await h.send(
          'POST',
          '/v1/accounts',
          body: body,
          contentType: 'application/json',
        );
        expectError(response, 400, 'invalid_json');
      }
    });

    test('bytes that are not UTF-8 answer 400 invalid_json', () async {
      final response = await h.send(
        'POST',
        '/v1/accounts',
        body: Stream.value([0x7b, 0x22, 0xff, 0xfe, 0x22, 0x7d]),
        contentType: 'application/json',
      );
      expectError(response, 400, 'invalid_json');
    });

    test('JSON that is not an object answers 422 invalid_request', () async {
      for (final body in ['[]', '"text"', '42', 'null', 'true']) {
        final response = await h.send(
          'POST',
          '/v1/accounts',
          body: body,
          contentType: 'application/json',
        );
        expectError(response, 422, 'invalid_request');
      }
    });

    test('the error for a bad body never repeats the body', () async {
      final response = await h.send(
        'POST',
        '/v1/sessions',
        body: '{"handle": "ada", "passphrase": "leaked-passphrase-value",}',
        contentType: 'application/json',
      );
      expectError(response, 400, 'invalid_json');
      expect(response.body, isNot(contains('leaked-passphrase-value')));
    });

    test('a body over the limit answers 413', () async {
      final response = await h.send(
        'POST',
        '/v1/accounts',
        json: {'handle': 'ada', 'passphrase': 'a' * (16 * 1024)},
      );
      expectError(response, 413, 'body_too_large');
    });

    test('the limit is enforced while reading, not after buffering', () async {
      var chunksPulled = 0;
      var cancelled = false;
      // An endless body with no Content-Length: 1 KiB at a time, for ever.
      Stream<List<int>> endless() async* {
        try {
          while (true) {
            chunksPulled++;
            yield List<int>.filled(1024, 0x20);
          }
        } finally {
          cancelled = true;
        }
      }

      final response = await h.send(
        'POST',
        '/v1/accounts',
        body: endless(),
        contentType: 'application/json',
      );
      expectError(response, 413, 'body_too_large');

      // The small-body limit is 16 KiB, so reading stopped after roughly
      // 16 chunks rather than running until memory was exhausted.
      await Future<void>.delayed(Duration.zero);
      expect(cancelled, isTrue);
      expect(chunksPulled, lessThanOrEqualTo(18));
    });

    test('a body that lies about its length is still cut off', () async {
      // Content-Length claims 10 bytes; the stream delivers far more.
      final response = await h.send(
        'POST',
        '/v1/accounts',
        body: Stream.fromIterable([
          for (var i = 0; i < 64; i++) List<int>.filled(1024, 0x20),
        ]),
        contentType: 'application/json',
        headers: {'content-length': '10'},
      );
      expectError(response, 413, 'body_too_large');
    });

    test('a body that never finishes answers 408', () async {
      final slow = Harness(bodyReadTimeout: const Duration(milliseconds: 50));
      final never = StreamController<List<int>>();
      addTearDown(never.close);
      never.add(utf8.encode('{"handle":'));

      final response = await slow.send(
        'POST',
        '/v1/accounts',
        body: never.stream,
        contentType: 'application/json',
      );
      expectError(response, 408, 'request_timeout');
      expect(never.hasListener, isFalse);
    });

    test('a body that breaks off answers 400 incomplete_body', () async {
      final response = await h.send(
        'POST',
        '/v1/accounts',
        body: Stream<List<int>>.error(const SocketException('reset')),
        contentType: 'application/json',
      );
      expectError(response, 400, 'incomplete_body');
    });
  });

  group('response headers', () {
    test('every response carries nosniff', () async {
      final token = await h.createAccount('ada');
      await h.publish('goals', validCatalog());
      final responses = [
        await h.send('GET', '/healthz'),
        await h.send('GET', '/nowhere'),
        await h.send('GET', '/v1/catalog/goals'),
        await h
            .send('GET', '/v1/catalog/goals', headers: {'if-none-match': '*'}),
        await h.send('GET', '/v1/export', token: token),
        await h.send('GET', '/v1/export'),
        await h.send('DELETE', '/v1/sessions/current', token: token),
        await h.send(
          'OPTIONS',
          '/v1/profile',
          headers: {'origin': _origin, 'access-control-request-method': 'PUT'},
        ),
        await h.send(
          'OPTIONS',
          '/v1/profile',
          headers: {
            'origin': 'https://evil.example',
            'access-control-request-method': 'PUT',
          },
        ),
      ];
      for (final response in responses) {
        expect(
          response.headers['x-content-type-options'],
          'nosniff',
          reason: '${response.status} ${response.body}',
        );
      }
    });

    test('every account response carries Cache-Control: no-store', () async {
      final created = await h.send(
        'POST',
        '/v1/accounts',
        json: {'handle': 'ada', 'passphrase': goodPassphrase},
      );
      final token = created.object['token'] as String;
      final responses = [
        created,
        await h.signIn('ada'),
        await h.signIn('ada', passphrase: 'wrong guess!'),
        await h.setSyncConsent(token, granted: true),
        await h.send('GET', '/v1/consents', token: token),
        await h.send(
          'PUT',
          '/v1/profile',
          token: token,
          json: {
            'baseRevision': 0,
            'data': {'k': 'v'},
          },
        ),
        await h.send(
          'PUT',
          '/v1/profile',
          token: token,
          json: {
            'baseRevision': 0,
            'data': {'k': 'v'},
          },
        ),
        await h.send('GET', '/v1/profile', token: token),
        await h.send('GET', '/v1/export', token: token),
        await h.send(
          'PUT',
          '/v1/account/passphrase',
          token: token,
          json: {
            'currentPassphrase': goodPassphrase,
            'newPassphrase': 'another passphrase',
          },
        ),
        await h.send(
          'DELETE',
          '/v1/account',
          token: token,
          json: {'passphrase': 'another passphrase'},
        ),
        await h.send('GET', '/v1/export', token: token),
      ];
      expect(
        responses.map((r) => r.status),
        [201, 200, 401, 200, 200, 200, 409, 200, 200, 204, 204, 401],
      );
      for (final response in responses) {
        expect(
          response.headers['cache-control'],
          'no-store',
          reason: '${response.status}',
        );
      }
    });

    test('no response sets a cookie', () async {
      final created = await h.send(
        'POST',
        '/v1/accounts',
        json: {'handle': 'ada', 'passphrase': goodPassphrase},
        headers: {'origin': _origin},
      );
      expect(created.headers.containsKey('set-cookie'), isFalse);
      final signedIn = await h.signIn('ada', headers: {'origin': _origin});
      expect(signedIn.headers.containsKey('set-cookie'), isFalse);
    });
  });

  group('CORS', () {
    test('echoes a listed origin', () async {
      final response = await h.send(
        'GET',
        '/v1/catalog/goals',
        headers: {'origin': _origin},
      );
      expect(response.headers['access-control-allow-origin'], _origin);
      expect(response.headers['vary'], 'Origin');
      expect(
        response.headers['access-control-expose-headers'],
        'etag, retry-after',
      );
      expect(
        response.headers.containsKey('access-control-allow-credentials'),
        isFalse,
      );
    });

    test('applies to errors and authenticated responses too', () async {
      final token = await h.createAccount('ada', headers: {'origin': _origin});
      final ok = await h.send(
        'GET',
        '/v1/export',
        token: token,
        headers: {'origin': _origin},
      );
      final unauthorised = await h.send(
        'GET',
        '/v1/export',
        headers: {'origin': _origin},
      );
      expect(ok.headers['access-control-allow-origin'], _origin);
      expect(unauthorised.headers['access-control-allow-origin'], _origin);
    });

    test('sends no CORS headers to an origin that is not listed', () async {
      for (final origin in [
        'https://evil.example',
        'https://app.example.org.evil.example',
        'http://app.example.org',
        'https://app.example.org:8443',
        'HTTPS://APP.EXAMPLE.ORG',
        'null',
        '*',
      ]) {
        final response = await h.send(
          'GET',
          '/v1/catalog/goals',
          headers: {'origin': origin},
        );
        expect(
          response.headers.keys.where((k) => k.startsWith('access-control-')),
          isEmpty,
          reason: origin,
        );
        expect(response.headers['vary'], 'Origin');
      }
    });

    test('sends no CORS headers when there is no Origin header', () async {
      final response = await h.send('GET', '/healthz');
      expect(
        response.headers.keys.where((k) => k.startsWith('access-control-')),
        isEmpty,
      );
    });

    test('answers a preflight from a listed origin', () async {
      final response = await h.send(
        'OPTIONS',
        '/v1/profile',
        headers: {
          'origin': _origin,
          'access-control-request-method': 'PUT',
          'access-control-request-headers': 'authorization, content-type',
        },
      );
      expect(response.status, 204);
      expect(response.body, isEmpty);
      expect(response.headers['access-control-allow-origin'], _origin);
      expect(
        response.headers['access-control-allow-headers'],
        'authorization, content-type, if-none-match',
      );
      expect(
        response.headers['access-control-allow-methods'],
        'GET, HEAD, POST, PUT, DELETE, OPTIONS',
      );
      expect(response.headers['access-control-max-age'], '600');
      expect(response.headers['vary'], 'Origin');
      expect(
        response.headers.containsKey('access-control-allow-credentials'),
        isFalse,
      );
    });

    test('refuses a preflight from an origin that is not listed', () async {
      final response = await h.send(
        'OPTIONS',
        '/v1/profile',
        headers: {
          'origin': 'https://evil.example',
          'access-control-request-method': 'PUT',
        },
      );
      expectError(response, 403, 'origin_not_allowed');
      expect(
        response.headers.keys.where((k) => k.startsWith('access-control-')),
        isEmpty,
      );
    });

    test('a preflight does not reach the route behind it', () async {
      final token = await h.createAccount('ada');
      final response = await h.send(
        'OPTIONS',
        '/v1/account',
        token: token,
        headers: {
          'origin': _origin,
          'access-control-request-method': 'DELETE',
        },
      );
      expect(response.status, 204);
      expect((await h.send('GET', '/v1/export', token: token)).status, 200);
    });

    test('never answers with a wildcard origin', () async {
      final open = Harness();
      for (final origin in [_origin, '*', 'null']) {
        final simple = await open.send(
          'GET',
          '/healthz',
          headers: {'origin': origin},
        );
        final preflight = await open.send(
          'OPTIONS',
          '/healthz',
          headers: {'origin': origin, 'access-control-request-method': 'GET'},
        );
        for (final response in [simple, preflight]) {
          expect(
            response.headers.containsKey('access-control-allow-origin'),
            isFalse,
          );
        }
      }
    });
  });

  group('client identification', () {
    test('uses the socket address when the proxy is not trusted', () async {
      await h.createAccount('ada');
      final attacker = {
        'shelf.io.connection_info': _FakeConnection('192.0.2.1')
      };
      final other = {'shelf.io.connection_info': _FakeConnection('192.0.2.2')};

      for (var i = 0; i < 20; i++) {
        final response = await h.send(
          'POST',
          '/v1/sessions',
          json: {'handle': 'victim-$i', 'passphrase': 'wrong guess!'},
          context: attacker,
        );
        expect(response.status, 401);
      }
      Future<ApiResponse> signIn(Map<String, Object> context) => h.send(
            'POST',
            '/v1/sessions',
            json: {'handle': 'ada', 'passphrase': goodPassphrase},
            context: context,
          );
      expect((await signIn(attacker)).status, 429);
      expect((await signIn(other)).status, 200);
    });

    test(
        'falls back to the socket address when a trusted proxy sends no '
        'X-Forwarded-For', () async {
      final proxied = Harness(trustProxy: true);
      await proxied.createAccount('ada');
      final direct = {'shelf.io.connection_info': _FakeConnection('192.0.2.1')};
      for (var i = 0; i < 20; i++) {
        await proxied.send(
          'POST',
          '/v1/sessions',
          json: {'handle': 'victim-$i', 'passphrase': 'wrong guess!'},
          context: direct,
        );
      }
      final blocked = await proxied.send(
        'POST',
        '/v1/sessions',
        json: {'handle': 'ada', 'passphrase': goodPassphrase},
        context: direct,
      );
      expect(blocked.status, 429);
      // A forwarded address is a different client.
      final forwarded = await proxied.signIn(
        'ada',
        headers: {'x-forwarded-for': '198.51.100.1'},
      );
      expect(forwarded.status, 200);
    });

    test('treats one IPv6 /64 as one client', () async {
      final proxied = Harness(trustProxy: true);
      await proxied.createAccount('ada');
      for (var i = 0; i < 20; i++) {
        await proxied.signIn(
          'victim-$i',
          passphrase: 'wrong guess!',
          headers: {'x-forwarded-for': '2001:db8:1:2::$i'},
        );
      }
      final sameNetwork = await proxied.signIn(
        'ada',
        headers: {'x-forwarded-for': '2001:db8:1:2:ffff::1'},
      );
      final otherNetwork = await proxied.signIn(
        'ada',
        headers: {'x-forwarded-for': '2001:db8:1:3::1'},
      );
      expect(sameNetwork.status, 429);
      expect(otherNetwork.status, 200);
    });
  });

  group('client identification, IPv4 through IPv6', () {
    test(
        'an IPv4-mapped address is the same client as the plain address, '
        'and different mapped addresses are different clients', () async {
      final proxied = Harness(trustProxy: true);
      await proxied.createAccount('ada');
      for (var i = 0; i < 20; i++) {
        await proxied.signIn(
          'victim-$i',
          passphrase: 'wrong guess!',
          headers: {'x-forwarded-for': '::ffff:203.0.113.5'},
        );
      }
      final samePlain = await proxied.signIn(
        'ada',
        headers: {'x-forwarded-for': '203.0.113.5'},
      );
      final otherMapped = await proxied.signIn(
        'ada',
        headers: {'x-forwarded-for': '::ffff:203.0.113.6'},
      );
      expect(samePlain.status, 429);
      expect(otherMapped.status, 200);
    });

    test('a forwarded value that is not an address still identifies a client',
        () async {
      final proxied = Harness(trustProxy: true);
      await proxied.createAccount('ada');
      for (var i = 0; i < 20; i++) {
        await proxied.signIn(
          'victim-$i',
          passphrase: 'wrong guess!',
          headers: {'x-forwarded-for': 'unknown-${'x' * 5000}'},
        );
      }
      final same = await proxied.signIn(
        'ada',
        headers: {'x-forwarded-for': 'unknown-${'x' * 5000}'},
      );
      final other = await proxied.signIn(
        'ada',
        headers: {'x-forwarded-for': 'unknown-${'x' * 4999}'},
      );
      expect(same.status, 429);
      expect(other.status, 200);
    });
  });

  group('request log', () {
    final linePattern = RegExp(
      r'^request method=[A-Z]+ route=\S+ status=\d{3} duration_ms=\d+'
      r'( error=\w+)?$',
    );

    test('writes one line per request with the route template', () async {
      await h.publish('goals', validCatalog());
      await h.send('GET', '/v1/catalog/goals?cachebust=12345');
      await h.send('GET', '/v1/catalog/unknown-name');
      await h.send('POST', '/v1/admin/catalog/goals/rollback');
      await h.send('GET', '/some/made-up/path?with=query');
      await h.send('GET', '/healthz');
      await h.send(
        'OPTIONS',
        '/v1/profile',
        headers: {'origin': _origin, 'access-control-request-method': 'PUT'},
      );
      await h.send('BREW', '/v1/profile');

      expect(h.logs, hasLength(8));
      for (final line in h.logs) {
        expect(line, matches(linePattern));
      }
      String withoutDuration(String line) =>
          line.replaceFirst(RegExp(r' duration_ms=\d+'), '');
      expect(h.logs.map(withoutDuration), [
        'request method=PUT route=/v1/admin/catalog/<name> status=200',
        'request method=GET route=/v1/catalog/<name> status=200',
        'request method=GET route=/v1/catalog/<name> status=404',
        'request method=POST route=/v1/admin/catalog/<name>/rollback status=401',
        'request method=GET route=<unmatched> status=404',
        'request method=GET route=/healthz status=200',
        'request method=OPTIONS route=<preflight> status=204',
        'request method=OTHER route=<unmatched> status=404',
      ]);
    });

    test(
        'never contains a handle, passphrase, token, profile content, admin '
        'token, query string, origin or client address', () async {
      const handle = 'zelda_handle_9431';
      const passphrase = 'Xq7-unique-passphrase-5528';
      const newPassphrase = 'Rw3-replacement-phrase-7719';
      const note = 'free-text-note-about-nursing-6642';
      const policy = 'policy-version-marker-3317';
      const clientAddress = '203.0.113.77';
      const catalogText = 'catalogue-body-marker-9950';
      const query = 'querymarker8812';

      final proxied = Harness(
        trustProxy: true,
        allowedOrigins: [_origin],
      );
      final common = {'x-forwarded-for': clientAddress, 'origin': _origin};
      Future<ApiResponse> send(
        String method,
        String path, {
        Object? json,
        Object? body,
        String? token,
        String? contentType,
      }) {
        return proxied.send(
          method,
          path,
          json: json,
          body: body,
          token: token,
          contentType: contentType,
          headers: common,
        );
      }

      final created = await send(
        'POST',
        '/v1/accounts?$query=1',
        json: {'handle': handle, 'passphrase': passphrase},
      );
      final firstToken = created.object['token'] as String;
      final signedIn = await send(
        'POST',
        '/v1/sessions',
        json: {'handle': handle, 'passphrase': passphrase},
      );
      final token = signedIn.object['token'] as String;

      // Failures and malformed requests are logged as carefully as successes.
      await send(
        'POST',
        '/v1/sessions',
        json: {'handle': handle, 'passphrase': '$passphrase-wrong'},
      );
      await send(
        'POST',
        '/v1/sessions',
        body: '{"handle":"$handle","passphrase":"$passphrase",',
        contentType: 'application/json',
      );
      await send(
        'POST',
        '/v1/accounts',
        json: {'handle': '$handle@example.org', 'passphrase': passphrase},
      );
      await send('GET', '/v1/$handle/$passphrase?token=$token');
      await send('GET', '/v1/export?$query=$token', token: 'not-$token');

      await send(
        'PUT',
        '/v1/consents/sync',
        token: token,
        json: {'granted': true, 'policyVersion': policy},
      );
      await send('GET', '/v1/consents', token: token);
      await send(
        'PUT',
        '/v1/profile',
        token: token,
        json: {
          'baseRevision': 0,
          'data': {'note': note},
        },
      );
      await send(
        'PUT',
        '/v1/profile',
        token: token,
        json: {
          'baseRevision': 7,
          'data': {'note': note},
        },
      );
      await send('GET', '/v1/profile', token: token);
      await send('GET', '/v1/export', token: token);
      await send(
        'PUT',
        '/v1/admin/catalog/goals',
        token: testAdminToken,
        json: validCatalog(title: catalogText),
      );
      await send(
        'PUT',
        '/v1/admin/catalog/goals',
        token: testAdminToken,
        json: validCatalog(title: '$catalogText guaranteed'),
      );
      await send('GET', '/v1/catalog/goals?$query=2');
      await send(
        'PUT',
        '/v1/account/passphrase',
        token: token,
        json: {'currentPassphrase': passphrase, 'newPassphrase': newPassphrase},
      );
      await send('DELETE', '/v1/sessions/current', token: firstToken);
      await send(
        'DELETE',
        '/v1/account',
        token: token,
        json: {'passphrase': newPassphrase},
      );

      expect(proxied.logs, hasLength(19));
      final output = proxied.logs.join('\n');
      for (final secret in [
        handle,
        passphrase,
        newPassphrase,
        firstToken,
        token,
        testAdminToken,
        note,
        policy,
        clientAddress,
        catalogText,
        query,
        'example.org',
        'Bearer',
      ]) {
        expect(output, isNot(contains(secret)), reason: secret);
      }
      for (final line in proxied.logs) {
        expect(line, matches(linePattern));
      }
      // The scenario really did exercise the routes it meant to.
      expect(output, contains('route=/v1/accounts status=201'));
      expect(output, contains('route=/v1/profile status=200'));
      expect(output, contains('route=/v1/profile status=409'));
      expect(output, contains('route=/v1/account status=204'));
      expect(output, contains('route=/v1/admin/catalog/<name> status=422'));
    });

    test('logging is optional', () async {
      final handler = buildHandler(
        ServerConfig(pbkdf2Iterations: 2),
        InMemoryServerStore(),
      );
      final quiet = Harness.around(handler);
      expect((await quiet.send('GET', '/healthz')).status, 200);
    });
  });
}

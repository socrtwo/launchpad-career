import 'dart:convert';
import 'dart:io';

import 'package:launchpad_server/launchpad_server.dart';
import 'package:test/test.dart';

import 'support.dart';

/// One exchange over a real socket.
final class _Reply {
  _Reply(this.status, this.headers, this.body);

  final int status;
  final HttpHeaders headers;
  final String body;

  Map<String, Object?> get object => jsonDecode(body) as Map<String, Object?>;

  String get errorCode =>
      (object['error'] as Map<String, Object?>)['code'] as String;
}

void main() {
  late HttpServer server;
  late HttpClient client;
  late InMemoryServerStore store;
  late List<String> logs;

  setUp(() async {
    store = InMemoryServerStore();
    logs = [];
    final handler = buildHandler(
      ServerConfig(
        adminToken: testAdminToken,
        allowedOrigins: const ['https://app.example.org'],
        pbkdf2Iterations: 2,
      ),
      store,
      logSink: logs.add,
    );
    server = await serveHandler(
      handler,
      address: InternetAddress.loopbackIPv4,
      port: 0,
    );
    client = HttpClient();
  });

  tearDown(() async {
    client.close(force: true);
    await server.close(force: true);
  });

  Future<_Reply> call(
    String method,
    String path, {
    Object? json,
    String? token,
    Map<String, String> headers = const {},
  }) async {
    final request = await client.open(method, 'localhost', server.port, path);
    request.followRedirects = false;
    headers.forEach(request.headers.set);
    if (token != null) {
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    }
    if (json != null) {
      final bytes = utf8.encode(jsonEncode(json));
      request.headers.contentType = ContentType.json;
      request.contentLength = bytes.length;
      request.add(bytes);
    }
    final response = await request.close();
    final body = await utf8.decodeStream(response);
    return _Reply(response.statusCode, response.headers, body);
  }

  test('a full round trip over a real socket', () async {
    final health = await call('GET', '/healthz');
    expect(health.status, 200);
    expect(health.body, '{"status":"ok"}');

    final created = await call(
      'POST',
      '/v1/accounts',
      json: {'handle': 'Socket_User', 'passphrase': goodPassphrase},
    );
    expect(created.status, 201);
    final firstToken = created.object['token'] as String;

    final wrong = await call(
      'POST',
      '/v1/sessions',
      json: {'handle': 'socket_user', 'passphrase': 'not the passphrase'},
    );
    expect(wrong.status, 401);
    expect(wrong.errorCode, 'invalid_credentials');

    final signedIn = await call(
      'POST',
      '/v1/sessions',
      json: {'handle': 'socket_user', 'passphrase': goodPassphrase},
    );
    expect(signedIn.status, 200);
    final token = signedIn.object['token'] as String;

    final refused = await call(
      'PUT',
      '/v1/profile',
      token: token,
      json: {
        'baseRevision': 0,
        'data': {'goal': 'explore'},
      },
    );
    expect(refused.status, 403);
    expect(refused.errorCode, 'consent_required');

    final consent = await call(
      'PUT',
      '/v1/consents/sync',
      token: token,
      json: {'granted': true, 'policyVersion': '2026-01'},
    );
    expect(consent.status, 200);

    final written = await call(
      'PUT',
      '/v1/profile',
      token: token,
      json: {
        'baseRevision': 0,
        'data': {
          'goal': 'explore',
          'note': 'café 中文',
        },
      },
    );
    expect(written.status, 200);
    expect(written.object['revision'], 1);

    final profile = await call('GET', '/v1/profile', token: token);
    expect(profile.status, 200);
    expect(profile.object['data'], {
      'goal': 'explore',
      'note': 'café 中文',
    });
    expect(profile.headers.value('cache-control'), 'no-store');

    final conflict = await call(
      'PUT',
      '/v1/profile',
      token: token,
      json: {
        'baseRevision': 0,
        'data': {'goal': 'other'},
      },
    );
    expect(conflict.status, 409);
    expect((conflict.object['current'] as Map)['revision'], 1);

    final export = await call('GET', '/v1/export', token: token);
    expect(export.status, 200);
    expect(export.object['handle'], 'socket_user');
    expect(export.object['activeSignIns'], 2);

    final signedOut = await call(
      'DELETE',
      '/v1/sessions/current',
      token: firstToken,
    );
    expect(signedOut.status, 204);
    expect((await call('GET', '/v1/export', token: firstToken)).status, 401);

    final deleted = await call(
      'DELETE',
      '/v1/account',
      token: token,
      json: {'passphrase': goodPassphrase},
    );
    expect(deleted.status, 204);
    expect((await call('GET', '/v1/export', token: token)).status, 401);
    expect(jsonEncode(store.snapshot()), isNot(contains('socket_user')));

    // One log line per request, none of them naming the person.
    expect(logs, hasLength(14));
    expect(logs.join('\n'), isNot(contains('socket_user')));
    expect(logs.join('\n'), isNot(contains('127.0.0.1')));
  });

  test('catalogue publishing, ETag revalidation and CORS over a socket',
      () async {
    final published = await call(
      'PUT',
      '/v1/admin/catalog/goals',
      token: testAdminToken,
      json: validCatalog(),
    );
    expect(published.status, 200);

    final first = await call(
      'GET',
      '/v1/catalog/goals',
      headers: {'origin': 'https://app.example.org'},
    );
    expect(first.status, 200);
    expect(first.object['document'], validCatalog());
    expect(
      first.headers.value('access-control-allow-origin'),
      'https://app.example.org',
    );
    final etag = first.headers.value('etag')!;

    final revalidated = await call(
      'GET',
      '/v1/catalog/goals',
      headers: {'if-none-match': etag},
    );
    expect(revalidated.status, 304);
    expect(revalidated.body, isEmpty);

    final preflight = await call(
      'OPTIONS',
      '/v1/profile',
      headers: {
        'origin': 'https://evil.example',
        'access-control-request-method': 'PUT',
      },
    );
    expect(preflight.status, 403);
    expect(preflight.headers.value('access-control-allow-origin'), isNull);
  });

  test('the wire carries the security headers and no stack fingerprint',
      () async {
    final reply = await call('GET', '/healthz');
    expect(reply.headers.value('x-content-type-options'), 'nosniff');
    expect(reply.headers.value('cache-control'), 'no-store');
    expect(reply.headers.value('x-powered-by'), isNull);
    expect(reply.headers.value('server'), isNull);
    expect(reply.headers.value('set-cookie'), isNull);
  });

  test('an oversized upload is refused over a socket', () async {
    final request = await client.open(
      'POST',
      'localhost',
      server.port,
      '/v1/accounts',
    );
    request.headers.contentType = ContentType.json;
    // Chunked, so there is no Content-Length for the server to trust.
    request.headers.chunkedTransferEncoding = true;
    request.add(utf8.encode('{"handle":"ada","passphrase":"'));
    request.add(List<int>.filled(64 * 1024, 0x61));
    request.add(utf8.encode('"}'));
    final response = await request.close();
    final body = await utf8.decodeStream(response);
    expect(response.statusCode, 413);
    expect(
      ((jsonDecode(body) as Map)['error'] as Map)['code'],
      'body_too_large',
    );
    expect(jsonEncode(store.snapshot()), isNot(contains('ada')));
  });

  test('the socket address identifies the client for rate limiting', () async {
    for (var i = 0; i < 20; i++) {
      final reply = await call(
        'POST',
        '/v1/sessions',
        // X-Forwarded-For is not trusted here, so varying it changes
        // nothing.
        headers: {'x-forwarded-for': '198.51.100.$i'},
        json: {'handle': 'nobody-$i', 'passphrase': 'wrong guess!'},
      );
      expect(reply.status, 401);
    }
    final blocked = await call(
      'POST',
      '/v1/sessions',
      json: {'handle': 'somebody', 'passphrase': 'wrong guess!'},
    );
    expect(blocked.status, 429);
    expect(blocked.errorCode, 'too_many_attempts');
    expect(int.parse(blocked.headers.value('retry-after')!), greaterThan(0));
  });
}

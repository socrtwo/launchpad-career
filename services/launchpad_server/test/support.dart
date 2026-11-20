import 'dart:convert';

import 'package:launchpad_server/launchpad_server.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

/// An admin token of the minimum accepted length.
const String testAdminToken = 'admin-token-for-tests-0123456789';

/// A passphrase that passes validation.
const String goodPassphrase = 'correct horse battery';

/// A clock the test moves by hand.
final class TestClock {
  DateTime now = DateTime.utc(2026, 1, 15, 9);

  DateTime call() => now;

  void advance(Duration duration) => now = now.add(duration);
}

/// A decoded response.
final class ApiResponse {
  ApiResponse(this.status, this.headers, this.body);

  final int status;
  final Map<String, String> headers;
  final String body;

  /// The body decoded as JSON. Fails the test when the body is empty.
  Object? get json => jsonDecode(body);

  Map<String, Object?> get object => json as Map<String, Object?>;

  /// The `error.code` of an error response.
  String get errorCode => _error['code'] as String;

  /// The `error.message` of an error response.
  String get errorMessage => _error['message'] as String;

  Map<String, Object?> get _error => object['error'] as Map<String, Object?>;
}

/// The handler under test with everything around it that a test controls.
final class Harness {
  Harness({
    String? adminToken = testAdminToken,
    Iterable<String> allowedOrigins = const [],
    bool trustProxy = false,
    int iterations = 2,
    int maxProfileBytes = 256 * 1024,
    Duration bodyReadTimeout = const Duration(seconds: 30),
    ServerStore? store,
    TestClock? clock,
  })  : store = store ?? InMemoryServerStore(),
        clock = clock ?? TestClock(),
        config = ServerConfig(
          adminToken: adminToken,
          allowedOrigins: allowedOrigins,
          trustProxy: trustProxy,
          pbkdf2Iterations: iterations,
          maxProfileBytes: maxProfileBytes,
          bodyReadTimeout: bodyReadTimeout,
        ) {
    hasher = PassphraseHasher(iterations: iterations);
    handler = buildHandler(
      config,
      this.store,
      clock: this.clock.call,
      logSink: logs.add,
      hasher: hasher,
    );
  }

  /// Wraps a handler built elsewhere, for tests that need to pass
  /// `buildHandler` something the main constructor does not offer.
  Harness.around(this.handler)
      : store = InMemoryServerStore(),
        clock = TestClock(),
        config = ServerConfig(pbkdf2Iterations: 2),
        hasher = PassphraseHasher(iterations: 2);

  final ServerStore store;
  final TestClock clock;
  final ServerConfig config;
  final List<String> logs = [];
  late final PassphraseHasher hasher;
  late final Handler handler;

  /// The in-memory store's contents as one JSON string, for assertions
  /// about what is and is not held.
  String get storeDump => jsonEncode((store as InMemoryServerStore).snapshot());

  /// Calls the handler directly. [json] is encoded as the body with a JSON
  /// content type; [body] is sent as given, with [contentType] when set.
  Future<ApiResponse> send(
    String method,
    String path, {
    Object? json,
    Object? body,
    String? contentType,
    String? token,
    Map<String, String> headers = const {},
    Map<String, Object> context = const {},
  }) async {
    final hasJson = json != null;
    final request = Request(
      method,
      Uri.parse('http://localhost$path'),
      body: hasJson ? jsonEncode(json) : body,
      headers: {
        if (hasJson) 'content-type': 'application/json',
        if (contentType != null) 'content-type': contentType,
        if (token != null) 'authorization': 'Bearer $token',
        ...headers,
      },
      context: context,
    );
    final response = await handler(request);
    return ApiResponse(
      response.statusCode,
      response.headers,
      await response.readAsString(),
    );
  }

  /// Creates an account and returns its token.
  Future<String> createAccount(
    String handle, {
    String passphrase = goodPassphrase,
    Map<String, String> headers = const {},
  }) async {
    final response = await send(
      'POST',
      '/v1/accounts',
      json: {'handle': handle, 'passphrase': passphrase},
      headers: headers,
    );
    expect(response.status, 201, reason: response.body);
    return response.object['token'] as String;
  }

  /// Signs in and returns the response, whatever its status.
  Future<ApiResponse> signIn(
    String handle, {
    String passphrase = goodPassphrase,
    Map<String, String> headers = const {},
  }) {
    return send(
      'POST',
      '/v1/sessions',
      json: {'handle': handle, 'passphrase': passphrase},
      headers: headers,
    );
  }

  /// Records the sync consent decision for the account behind [token].
  Future<ApiResponse> setSyncConsent(String token, {required bool granted}) {
    return send(
      'PUT',
      '/v1/consents/sync',
      token: token,
      json: {'granted': granted, 'policyVersion': '2026-01'},
    );
  }

  /// Publishes [document] to the catalogue called [name] as the admin.
  Future<ApiResponse> publish(String name, Object? document) {
    return send(
      'PUT',
      '/v1/admin/catalog/$name',
      token: testAdminToken,
      json: document,
    );
  }
}

/// A catalogue document that passes validation.
Map<String, Object?> validCatalog({String title = 'Explore options'}) => {
      'schemaVersion': 1,
      'items': [
        {'id': 'explore', 'title': title},
        {'id': 'resume', 'title': 'Improve my resume and LinkedIn'},
      ],
    };

/// Asserts that [response] is an error in the API's one error shape.
void expectError(ApiResponse response, int status, String code) {
  expect(response.status, status, reason: response.body);
  expect(response.object.keys, contains('error'));
  expect(response.errorCode, code);
  expect(response.errorCode, matches(RegExp(r'^[a-z]+(_[a-z]+)*$')));
  final message = response.errorMessage;
  expect(message, isNotEmpty);
  expect(message, endsWith('.'), reason: 'messages are full sentences');
  expect(
    message.toLowerCase(),
    isNot(anyOf(contains('sorry'), contains('oops'), contains('apolog'))),
    reason: 'errors do not apologise',
  );
  expect(
    message.toLowerCase(),
    isNot(contains('something went wrong')),
    reason: 'errors are never vague',
  );
}

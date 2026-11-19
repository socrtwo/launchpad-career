import 'dart:math';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'api/accounts_api.dart';
import 'api/api_context.dart';
import 'api/catalog_api.dart';
import 'api/sync_api.dart';
import 'config.dart';
import 'crypto/passphrase_hasher.dart';
import 'http/middleware.dart';
import 'store/server_store.dart';

/// Builds the complete request handler: routes plus the logging, header,
/// cross-origin and error-handling layers around them.
///
/// Tests call the result directly with `shelf` `Request` objects; the entry
/// point binds it to a socket with `serveHandler`.
///
/// * [clock] supplies the time for expiry, rate limiting and timestamps.
/// * [logSink] receives one line per request. Null means no request log.
/// * [random] must be cryptographically secure; it produces salts, tokens
///   and identifiers. The default is `Random.secure()`.
/// * [hasher] replaces the passphrase hasher built from [config].
Handler buildHandler(
  ServerConfig config,
  ServerStore store, {
  Clock? clock,
  LogSink? logSink,
  Random? random,
  PassphraseHasher? hasher,
}) {
  final secureRandom = random ?? Random.secure();
  final context = ApiContext(
    config: config,
    store: store,
    clock: clock ?? _utcNow,
    random: secureRandom,
    hasher: hasher ??
        PassphraseHasher(
          iterations: config.pbkdf2Iterations,
          random: secureRandom,
          maxConcurrent: config.hashConcurrency,
        ),
  );
  final accounts = AccountsApi(context);
  final sync = SyncApi(context);
  final catalog = CatalogApi(context);

  final router = Router(notFoundHandler: CatalogApi.notFound);

  /// Registers [handler] and makes sure the request log sees the route
  /// template rather than the address the client asked for.
  void route(String verb, String template, Handler handler) {
    router.add(verb, template, (Request request) {
      RequestLogEntry.of(request)?.route = template;
      return handler(request);
    });
  }

  route('GET', '/healthz', _health);

  route('POST', '/v1/accounts', accounts.createAccount);
  route('POST', '/v1/sessions', accounts.signIn);
  route('DELETE', '/v1/sessions/current', accounts.signOut);
  route('PUT', '/v1/account/passphrase', accounts.changePassphrase);
  route('DELETE', '/v1/account', accounts.deleteAccount);

  route('GET', '/v1/consents', sync.listConsents);
  route('PUT', '/v1/consents/sync', sync.putSyncConsent);
  route('GET', '/v1/profile', sync.getProfile);
  route('PUT', '/v1/profile', sync.putProfile);
  route('GET', '/v1/export', sync.export);

  route('GET', '/v1/catalog/<name>', catalog.getCatalog);
  route('PUT', '/v1/admin/catalog/<name>', catalog.publishCatalog);
  route('POST', '/v1/admin/catalog/<name>/rollback', catalog.rollbackCatalog);

  return const Pipeline()
      .addMiddleware(logRequestLines(logSink))
      .addMiddleware(addSecurityHeaders())
      .addMiddleware(cors(config.allowedOrigins))
      .addMiddleware(handleErrors())
      .addHandler(router.call);
}

DateTime _utcNow() => DateTime.now().toUtc();

Response _health(Request request) {
  return Response.ok(
    '{"status":"ok"}',
    headers: {'content-type': 'application/json'},
  );
}

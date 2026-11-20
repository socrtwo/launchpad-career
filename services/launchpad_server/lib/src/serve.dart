import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

/// Binds [handler] to [address] and [port] over plain HTTP.
///
/// TLS is not handled here. Put a reverse proxy that terminates TLS in
/// front of the server; see the README.
Future<HttpServer> serveHandler(
  Handler handler, {
  required Object address,
  required int port,
}) async {
  final server = await shelf_io.serve(
    handler,
    address,
    port,
    // No "X-Powered-By": there is no reason to advertise the stack.
    poweredByHeader: null,
  );
  // `dart:io` adds X-Frame-Options and the obsolete X-XSS-Protection by
  // default. The handler sets the headers this API needs on every response
  // it produces; these two remain as the fallback for anything that does
  // not pass through the handler.
  server.defaultResponseHeaders
    ..clear()
    ..set('x-content-type-options', 'nosniff')
    ..set('cache-control', 'no-store');
  return server;
}

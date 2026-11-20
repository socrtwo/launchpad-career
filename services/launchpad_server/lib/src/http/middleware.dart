import 'package:shelf/shelf.dart';

import '../config.dart';
import '../crypto/passphrase_hasher.dart';
import 'api_exception.dart';
import 'responses.dart';

/// Carries what the request log needs from the inside of the pipeline to
/// the logging middleware at its edge.
final class RequestLogEntry {
  /// The route template that matched, such as `/v1/catalog/<name>`. Never
  /// the concrete path.
  String route = unmatchedRoute;

  /// The class name of an unexpected error, when one was thrown. Only the
  /// name: error messages can quote request content.
  String? errorType;

  static const String unmatchedRoute = '<unmatched>';
  static const String preflightRoute = '<preflight>';

  static const String _contextKey = 'launchpad.log_entry';

  /// The entry for [request], when the logging middleware is installed.
  static RequestLogEntry? of(Request request) {
    final entry = request.context[_contextKey];
    return entry is RequestLogEntry ? entry : null;
  }
}

const Set<String> _loggedMethods = {
  'GET',
  'HEAD',
  'POST',
  'PUT',
  'DELETE',
  'OPTIONS',
  'PATCH',
};

/// Writes one line per request to [sink]: method, route template, status
/// and duration.
///
/// The line is built only from values the server chose. It never contains
/// the request path, query string, headers, body or client address, so
/// handles, passphrases, tokens and profile content cannot reach the log.
Middleware logRequestLines(LogSink? sink) {
  return (inner) {
    return (request) async {
      final entry = RequestLogEntry();
      final stopwatch = Stopwatch()..start();
      // Anything outside the usual verbs is logged as OTHER, so a client
      // cannot write text of its choosing into the log.
      final method =
          _loggedMethods.contains(request.method) ? request.method : 'OTHER';

      void write(int status) {
        if (sink == null) return;
        final error = entry.errorType;
        sink(
          'request method=$method route=${entry.route} status=$status '
          'duration_ms=${stopwatch.elapsedMilliseconds}'
          '${error == null ? '' : ' error=$error'}',
        );
      }

      try {
        final response = await inner(
          request.change(context: {RequestLogEntry._contextKey: entry}),
        );
        write(response.statusCode);
        return response;
      } on HijackException {
        rethrow;
      } on Object catch (error) {
        entry.errorType ??= error.runtimeType.toString();
        write(500);
        rethrow;
      }
    };
  };
}

/// Turns thrown errors into responses in the API's one error shape.
///
/// An unexpected error becomes a 500 whose body says nothing about the
/// cause; only the error's class name is passed to the request log.
Middleware handleErrors() {
  return (inner) {
    return (request) async {
      try {
        return await inner(request);
      } on ApiException catch (error) {
        return errorResponse(error);
      } on HasherBusyException {
        return errorResponse(
          const ApiException(
            503,
            'server_busy',
            'The server is handling too many sign-ins at the moment. Wait a '
                'few seconds and try again.',
            headers: {'retry-after': '5'},
          ),
        );
      } on HijackException {
        rethrow;
      } on Object catch (error) {
        RequestLogEntry.of(request)?.errorType = error.runtimeType.toString();
        return errorResponse(
          const ApiException(
            500,
            'internal_error',
            'The server could not complete the request. Try again in a few '
                'minutes.',
          ),
        );
      }
    };
  };
}

/// Adds the headers every response carries.
///
/// `Cache-Control: no-store` is the default, so account data and error
/// bodies are never cached. A handler that wants caching, such as the
/// public catalogue, sets its own `Cache-Control`.
Middleware addSecurityHeaders() {
  return (inner) {
    return (request) async {
      final response = await inner(request);
      return response.change(
        headers: {
          'x-content-type-options': 'nosniff',
          'referrer-policy': 'no-referrer',
          'content-security-policy': "default-src 'none'; "
              "frame-ancestors 'none'",
          if (!response.headers.containsKey('cache-control'))
            'cache-control': 'no-store',
        },
      );
    };
  };
}

const String _allowedMethods = 'GET, HEAD, POST, PUT, DELETE, OPTIONS';
const String _allowedHeaders = 'authorization, content-type, if-none-match';
const String _exposedHeaders = 'etag, retry-after';

/// Applies the cross-origin policy.
///
/// The request's `Origin` is echoed back only when it is in
/// [allowedOrigins]; `*` is never sent. Credentials mode is never enabled,
/// because the API uses bearer tokens and no cookies.
Middleware cors(Set<String> allowedOrigins) {
  return (inner) {
    return (request) async {
      final requestOrigin = request.headers['origin'];
      final origin =
          requestOrigin != null && allowedOrigins.contains(requestOrigin)
              ? requestOrigin
              : null;
      final isPreflight = request.method == 'OPTIONS' &&
          request.headers.containsKey('access-control-request-method');

      if (isPreflight) {
        RequestLogEntry.of(request)?.route = RequestLogEntry.preflightRoute;
        if (origin == null) {
          return errorResponse(
            const ApiException(
              403,
              'origin_not_allowed',
              'This origin is not allowed to call the API. Ask the operator '
                  'to add it to ALLOWED_ORIGINS.',
              headers: {'vary': 'Origin'},
            ),
          );
        }
        return Response(
          204,
          headers: {
            'access-control-allow-origin': origin,
            'access-control-allow-methods': _allowedMethods,
            'access-control-allow-headers': _allowedHeaders,
            'access-control-max-age': '600',
            'vary': 'Origin',
          },
        );
      }

      final response = await inner(request);
      return response.change(
        headers: {
          'vary': 'Origin',
          if (origin != null) ...{
            'access-control-allow-origin': origin,
            'access-control-expose-headers': _exposedHeaders,
          },
        },
      );
    };
  };
}

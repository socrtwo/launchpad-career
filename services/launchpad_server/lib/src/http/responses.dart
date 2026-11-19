import 'dart:convert';

import 'package:shelf/shelf.dart';

import 'api_exception.dart';

const String jsonContentType = 'application/json';

/// A JSON response with [status].
Response jsonResponse(
  int status,
  Object? body, {
  Map<String, String> headers = const {},
}) {
  return jsonBytesResponse(status, utf8.encode(jsonEncode(body)), headers);
}

/// A JSON response from already encoded [bytes].
Response jsonBytesResponse(
  int status,
  List<int> bytes, [
  Map<String, String> headers = const {},
]) {
  return Response(
    status,
    body: bytes,
    headers: {'content-type': jsonContentType, ...headers},
  );
}

/// An empty 204 response.
Response noContent() => Response(204);

/// The response for [error], in the one error shape the API uses.
Response errorResponse(ApiException error) {
  return jsonResponse(
    error.status,
    {
      'error': {
        'code': error.code,
        'message': error.message,
        ...error.errorDetails,
      },
      ...error.extra,
    },
    headers: error.headers,
  );
}

/// Formats [time] the way every timestamp in the API is written.
String isoTime(DateTime time) => time.toUtc().toIso8601String();

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:shelf/shelf.dart';

import '../json_guard.dart';
import 'api_exception.dart';
import 'responses.dart';

/// The deepest nesting accepted in any request body.
const int maxBodyDepth = 64;

/// Reads the request body as JSON of at most [maxBytes] bytes.
///
/// The limit is enforced while the stream is read: the body is never
/// buffered beyond [maxBytes], whatever `Content-Length` claims, and the
/// rest of an oversized body is not read at all. Throws an [ApiException]
/// with
///
/// * 415 `unsupported_media_type` unless the body is `application/json`;
/// * 413 `body_too_large` over the limit;
/// * 408 `request_timeout` when the whole body takes longer than [timeout];
/// * 400 `incomplete_body` when the connection breaks part-way through;
/// * 400 `invalid_json` when the body is not UTF-8 JSON.
Future<Object?> readJson(
  Request request, {
  required int maxBytes,
  required Duration timeout,
}) async {
  if (request.mimeType != jsonContentType) {
    throw const ApiException(
      415,
      'unsupported_media_type',
      'Send the request body as JSON with the header '
          '"Content-Type: application/json".',
    );
  }

  final tooLarge = ApiException(
    413,
    'body_too_large',
    'The request body is larger than the $maxBytes bytes this endpoint '
        'accepts. Send a smaller body.',
  );

  final declared = request.contentLength;
  if (declared != null && declared > maxBytes) throw tooLarge;

  final bytes = await _collect(request.read(), maxBytes, timeout, tooLarge);
  try {
    return jsonDecode(utf8.decode(bytes));
  } on FormatException {
    throw const ApiException(
      400,
      'invalid_json',
      'The request body is not valid JSON. Check the syntax and send it '
          'again.',
    );
  }
}

/// Reads the request body as a JSON object. See [readJson] for the limits
/// and errors; in addition this throws 422 `invalid_request` when the JSON
/// is not an object or is nested deeper than [maxBodyDepth] levels.
Future<Map<String, Object?>> readJsonObject(
  Request request, {
  required int maxBytes,
  required Duration timeout,
}) async {
  final decoded = await readJson(
    request,
    maxBytes: maxBytes,
    timeout: timeout,
  );
  if (decoded is! Map<String, Object?>) {
    throw const ApiException(
      422,
      'invalid_request',
      'The request body must be a JSON object. Wrap the fields in braces.',
    );
  }
  if (jsonDepth(decoded, limit: maxBodyDepth) > maxBodyDepth) {
    throw const ApiException(
      422,
      'invalid_request',
      'The request body is nested more than $maxBodyDepth levels deep. '
          'Flatten the document and send it again.',
    );
  }
  return decoded;
}

Future<Uint8List> _collect(
  Stream<List<int>> body,
  int maxBytes,
  Duration timeout,
  ApiException tooLarge,
) {
  final result = Completer<Uint8List>();
  final buffer = BytesBuilder(copy: false);
  late final StreamSubscription<List<int>> subscription;

  void fail(ApiException error) {
    // Cancelling stops reading: nothing more is pulled from the client.
    unawaited(subscription.cancel());
    if (!result.isCompleted) result.completeError(error);
  }

  final deadline = Timer(timeout, () {
    fail(
      const ApiException(
        408,
        'request_timeout',
        'The request body took too long to arrive. Send the request again.',
      ),
    );
  });

  subscription = body.listen(
    (chunk) {
      if (buffer.length + chunk.length > maxBytes) {
        fail(tooLarge);
      } else {
        buffer.add(chunk);
      }
    },
    onError: (Object _) {
      fail(
        const ApiException(
          400,
          'incomplete_body',
          'The request body ended before it was complete. Send the request '
              'again.',
        ),
      );
    },
    onDone: () {
      if (!result.isCompleted) result.complete(buffer.takeBytes());
    },
    cancelOnError: true,
  );

  return result.future.whenComplete(deadline.cancel);
}

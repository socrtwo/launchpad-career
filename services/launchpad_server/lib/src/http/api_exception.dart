/// An error that is sent to the client as
/// `{"error":{"code":...,"message":...}}`.
///
/// [message] says what happened and what to do about it. It must never
/// contain anything the client sent.
final class ApiException implements Exception {
  const ApiException(
    this.status,
    this.code,
    this.message, {
    this.headers = const {},
    this.errorDetails = const {},
    this.extra = const {},
  });

  final int status;

  /// A stable `snake_case` identifier clients can branch on.
  final String code;

  final String message;

  /// Additional response headers, such as `Retry-After`.
  final Map<String, String> headers;

  /// Additional members of the `error` object, such as `problems`.
  final Map<String, Object?> errorDetails;

  /// Additional top-level members of the body, such as `current`.
  final Map<String, Object?> extra;

  @override
  String toString() => 'ApiException($status, $code)';
}

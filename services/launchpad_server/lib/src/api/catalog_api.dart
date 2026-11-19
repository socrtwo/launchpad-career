import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../catalog_validator.dart';
import '../crypto/secure_compare.dart';
import '../http/api_exception.dart';
import '../http/body_reader.dart';
import '../http/responses.dart';
import '../store/records.dart';
import 'api_context.dart';

/// The catalogues the server publishes.
const Set<String> catalogNames = {'goals', 'occupations'};

/// The public catalogue endpoint and the admin endpoints that manage it.
final class CatalogApi {
  CatalogApi(this._context);

  final ApiContext _context;
  final Map<String, _EncodedCatalog> _encoded = {};

  static const ApiException _notFound = ApiException(
    404,
    'not_found',
    'Nothing exists at this address. Check the method and path against '
        'API.md.',
  );

  static const ApiException _noCatalog = ApiException(
    404,
    'no_catalog',
    'Nothing has been published for this catalogue yet. Try again after '
        'the first publication.',
  );

  /// The response for any address that is not part of the API.
  static Response notFound(Request request) => errorResponse(_notFound);

  /// `GET /v1/catalog/<name>`
  Future<Response> getCatalog(Request request) async {
    final name = _catalogName(request);
    final catalog = await _context.store.findCatalog(name);
    if (catalog == null) throw _noCatalog;

    final encoded = _encode(name, catalog);
    final headers = {
      'etag': encoded.etag,
      // Shared caches may keep the catalogue, but must revalidate it. The
      // ETag makes that revalidation cheap.
      'cache-control': 'public, no-cache',
    };
    final ifNoneMatch = request.headers['if-none-match'];
    if (ifNoneMatch != null && _matchesEtag(ifNoneMatch, encoded.etag)) {
      return Response.notModified(headers: headers);
    }
    return jsonBytesResponse(200, encoded.bytes, headers);
  }

  /// `PUT /v1/admin/catalog/<name>`
  Future<Response> publishCatalog(Request request) async {
    _requireAdmin(request);
    final name = _catalogName(request);
    final document = await readJson(
      request,
      maxBytes: _context.config.maxCatalogBytes,
      timeout: _context.config.bodyReadTimeout,
    );

    final problems = validateCatalogDocument(document);
    if (problems.isNotEmpty) {
      throw ApiException(
        422,
        'invalid_catalog',
        'The catalogue was not published because it breaks the rules listed '
            'in "problems". Correct them and send it again.',
        errorDetails: {'problems': problems},
      );
    }

    final published = await _context.store.publishCatalog(
      name,
      document as Map<String, Object?>,
      _context.clock(),
    );
    return jsonResponse(200, _summary(published));
  }

  /// `POST /v1/admin/catalog/<name>/rollback`
  Future<Response> rollbackCatalog(Request request) async {
    _requireAdmin(request);
    final name = _catalogName(request);
    final result = await _context.store.rollbackCatalog(
      name,
      _context.clock(),
    );
    switch (result.status) {
      case CatalogRollbackStatus.rolledBack:
        return jsonResponse(200, _summary(result.catalog!));
      case CatalogRollbackStatus.noCatalog:
        throw _noCatalog;
      case CatalogRollbackStatus.noPreviousRevision:
        throw const ApiException(
          409,
          'no_previous_revision',
          'This catalogue has only one published revision, so there is '
              'nothing to roll back to. Publish a corrected document '
              'instead.',
        );
    }
  }

  /// Admin routes do not exist unless an admin token is configured, and
  /// they look exactly like any other missing address when it is not.
  void _requireAdmin(Request request) {
    final adminToken = _context.config.adminToken;
    if (adminToken == null) throw _notFound;
    final presented = ApiContext.bearerCredentials(request);
    // Compared in constant time even when nothing was presented.
    final matches = constantTimeStringEqual(presented ?? '', adminToken);
    if (presented == null || !matches) {
      throw const ApiException(
        401,
        'invalid_token',
        'The admin token is missing or not correct. Send the configured '
            'ADMIN_TOKEN as a bearer token.',
        headers: {'www-authenticate': 'Bearer'},
      );
    }
  }

  String _catalogName(Request request) {
    final name = request.params['name'];
    if (name == null || !catalogNames.contains(name)) throw _notFound;
    return name;
  }

  _EncodedCatalog _encode(String name, CatalogRecord catalog) {
    final cached = _encoded[name];
    if (cached != null &&
        cached.revision == catalog.revision &&
        cached.updatedAt == catalog.updatedAt) {
      return cached;
    }
    final bytes = utf8.encode(
      jsonEncode({..._summary(catalog), 'document': catalog.document}),
    );
    // A strong validator: it is derived from the exact bytes served.
    final digest = base64Url.encode(sha256.convert(bytes).bytes);
    return _encoded[name] = _EncodedCatalog(
      catalog.revision,
      catalog.updatedAt,
      bytes,
      '"${digest.replaceAll('=', '')}"',
    );
  }

  static Map<String, Object?> _summary(CatalogRecord catalog) => {
        'revision': catalog.revision,
        'updatedAt': isoTime(catalog.updatedAt),
      };

  /// `If-None-Match` uses weak comparison, so a `W/` prefix is ignored.
  static bool _matchesEtag(String header, String etag) {
    for (final part in header.split(',')) {
      var candidate = part.trim();
      if (candidate == '*') return true;
      if (candidate.startsWith('W/')) candidate = candidate.substring(2);
      if (candidate == etag) return true;
    }
    return false;
  }
}

final class _EncodedCatalog {
  const _EncodedCatalog(this.revision, this.updatedAt, this.bytes, this.etag);

  final int revision;
  final DateTime updatedAt;
  final List<int> bytes;
  final String etag;
}

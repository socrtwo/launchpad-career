import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:launchpad_domain/launchpad_domain.dart';

import '../key_value_store.dart';
import '../persistent_session_repository.dart';
import '../session_codec.dart';

/// The account client for the Launchpad Career server
/// (`services/launchpad_server`, interface in its `API.md`).
///
/// What this class guarantees:
///
///  * the passphrase is passed straight to the service and kept nowhere;
///  * the sign-in token lives in memory, and is written to the device store
///    only while the person has storage turned on;
///  * what is sent as the profile is exactly what the device would store:
///    [SessionCodec.encode] without the "Something else" text;
///  * nothing here logs, and no error carries what the person typed.
class HttpAccountRepository implements AccountRepository {
  HttpAccountRepository({
    required Uri baseUrl,
    required http.Client client,
    required KeyValueStore store,
    required bool Function() mayPersist,
    DateTime Function()? clock,
    this.timeout = const Duration(seconds: 20),
  })  : _baseUrl = baseUrl,
        _client = client,
        _store = store,
        _mayPersist = mayPersist,
        _clock = clock ?? DateTime.now {
    _restore();
  }

  /// Version of the sync wording the person agreed to, recorded with the
  /// consent on the service.
  static const String syncPolicyVersion = '2026-11';

  /// Whether [url] may be used as the service address: HTTPS, or plain HTTP
  /// to this machine for development. A passphrase is never sent in the clear
  /// to another host.
  static bool isAcceptableBaseUrl(Uri url) {
    if (!url.hasAuthority || url.host.isEmpty) return false;
    if (url.scheme == 'https') return true;
    return url.scheme == 'http' &&
        (url.host == 'localhost' || url.host == '127.0.0.1');
  }

  final Uri _baseUrl;
  final http.Client _client;
  final KeyValueStore _store;
  final bool Function() _mayPersist;
  final DateTime Function() _clock;
  final Duration timeout;

  AccountStatus? _status;
  String? _token;

  @override
  AccountStatus? get current => _status;

  @override
  Future<AccountStatus> createAccount({
    required String handle,
    required String passphrase,
  }) =>
      _enter('/v1/accounts', handle, passphrase);

  @override
  Future<AccountStatus> signIn({
    required String handle,
    required String passphrase,
  }) =>
      _enter('/v1/sessions', handle, passphrase);

  Future<AccountStatus> _enter(
    String path,
    String handle,
    String passphrase,
  ) async {
    final normalised = handle.trim().toLowerCase();
    final reply = await _send(
      'POST',
      path,
      body: <String, Object?>{'handle': normalised, 'passphrase': passphrase},
      authenticated: false,
    );
    final token = reply.json['token'];
    if (token is! String || token.isEmpty) {
      throw const AccountException(AccountFailure.server);
    }
    _token = token;
    _status = AccountStatus(
      handle: normalised,
      expiresAt: DateTime.tryParse('${reply.json['expiresAt']}')?.toUtc(),
    );
    await persistIfAllowed();
    return _status!;
  }

  @override
  Future<void> signOut() async {
    try {
      if (_token != null) await _send('DELETE', '/v1/sessions/current');
    } on AccountException {
      // The device forgets the sign-in whether or not the service heard.
    }
    await _forget();
  }

  @override
  Future<bool> syncConsent() async {
    final reply = await _send('GET', '/v1/consents');
    final consents = reply.json['consents'];
    final sync = consents is Map ? consents['sync'] : null;
    return sync is Map && sync['granted'] == true;
  }

  @override
  Future<void> setSyncConsent({required bool granted}) async {
    await _send(
      'PUT',
      '/v1/consents/sync',
      body: <String, Object?>{
        'granted': granted,
        'policyVersion': syncPolicyVersion,
      },
    );
    // The service starts a new document after consent changes, so any
    // revision this device remembered no longer means anything.
    await _setRevision(null);
  }

  @override
  Future<SyncResult> upload(Session session, {int? baseRevision}) async {
    final data = SessionCodec.encode(session);
    var base = baseRevision ?? _status?.syncedRevision ?? 0;
    for (var attempt = 0; attempt < 2; attempt++) {
      final reply = await _send(
        'PUT',
        '/v1/profile',
        body: <String, Object?>{'baseRevision': base, 'data': data},
        allowConflict: true,
      );
      if (reply.status != 409) {
        final revision = reply.json['revision'];
        if (revision is! int) {
          throw const AccountException(AccountFailure.server);
        }
        await _setRevision(revision);
        return SyncUploaded(revision);
      }
      final remote = _remote(reply.json['current']);
      if (remote != null) return SyncConflict(remote);
      // Nothing is stored after all (sync was turned off and on again
      // elsewhere): send it as the first revision.
      base = 0;
    }
    throw const AccountException(AccountFailure.server);
  }

  @override
  Future<RemoteProfile?> download() async {
    final reply = await _send('GET', '/v1/profile', allowMissing: true);
    if (reply.status == 404) {
      await _setRevision(null);
      return null;
    }
    final remote = _remote(reply.json);
    if (remote == null) throw const AccountException(AccountFailure.server);
    await _setRevision(remote.revision);
    return remote;
  }

  @override
  Future<String> exportData() async {
    final reply = await _send('GET', '/v1/export');
    return const JsonEncoder.withIndent('  ').convert(reply.json);
  }

  @override
  Future<void> deleteAccount({required String passphrase}) async {
    await _send(
      'DELETE',
      '/v1/account',
      body: <String, Object?>{'passphrase': passphrase},
    );
    await _forget();
  }

  @override
  Future<void> persistIfAllowed() async {
    final status = _status;
    final token = _token;
    if (status == null || token == null || !_mayPersist()) return;
    await _store.write(
      PersistentSessionRepository.accountKey,
      jsonEncode(<String, Object?>{
        'handle': status.handle,
        'token': token,
        if (status.expiresAt != null)
          'expiresAt': status.expiresAt!.toIso8601String(),
        if (status.syncedRevision != null)
          'syncedRevision': status.syncedRevision,
      }),
    );
  }

  Future<void> _setRevision(int? revision) async {
    final status = _status;
    if (status == null) return;
    _status = AccountStatus(
      handle: status.handle,
      expiresAt: status.expiresAt,
      syncedRevision: revision,
    );
    await persistIfAllowed();
  }

  Future<void> _forget() async {
    _status = null;
    _token = null;
    await _store.delete(PersistentSessionRepository.accountKey);
  }

  void _restore() {
    if (!_mayPersist()) return;
    final raw = _store.read(PersistentSessionRepository.accountKey);
    if (raw == null) return;
    try {
      final json = jsonDecode(raw);
      if (json is! Map) return;
      final handle = json['handle'];
      final token = json['token'];
      final expiresAt = DateTime.tryParse('${json['expiresAt']}')?.toUtc();
      if (handle is! String || token is! String) return;
      if (expiresAt != null && !expiresAt.isAfter(_clock().toUtc())) {
        unawaited(_store.delete(PersistentSessionRepository.accountKey));
        return;
      }
      final revision = json['syncedRevision'];
      _token = token;
      _status = AccountStatus(
        handle: handle,
        expiresAt: expiresAt,
        syncedRevision: revision is int ? revision : null,
      );
    } on FormatException {
      // A damaged copy is treated as no sign-in.
    }
  }

  static RemoteProfile? _remote(Object? json) {
    if (json is! Map) return null;
    final revision = json['revision'];
    final data = json['data'];
    if (revision is! int || revision < 1 || data is! Map) return null;
    return RemoteProfile(
      revision: revision,
      updatedAt: DateTime.tryParse('${json['updatedAt']}')?.toUtc(),
      session: SessionCodec.decode(
        data.map((key, value) => MapEntry(key.toString(), value as Object?)),
      ),
    );
  }

  Future<_Reply> _send(
    String method,
    String path, {
    Map<String, Object?>? body,
    bool authenticated = true,
    bool allowConflict = false,
    bool allowMissing = false,
  }) async {
    final token = _token;
    if (authenticated && token == null) {
      throw const AccountException(AccountFailure.signedOut);
    }
    final request = http.Request(method, _baseUrl.resolve(path))
      ..headers['accept'] = 'application/json';
    if (authenticated) request.headers['authorization'] = 'Bearer $token';
    if (body != null) {
      request.headers['content-type'] = 'application/json';
      request.body = jsonEncode(body);
    }

    final http.Response response;
    try {
      response = await http.Response.fromStream(
        await _client.send(request).timeout(timeout),
      );
    } on Exception {
      throw const AccountException(AccountFailure.network);
    }

    var json = const <String, Object?>{};
    if (response.bodyBytes.isNotEmpty) {
      try {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is Map) {
          json = decoded.map(
            (key, value) => MapEntry(key.toString(), value as Object?),
          );
        }
      } on FormatException {
        throw const AccountException(AccountFailure.server);
      }
    }

    final status = response.statusCode;
    if (status >= 200 && status < 300) return _Reply(status, json);
    if (status == 409 && allowConflict) return _Reply(status, json);
    if (status == 404 && allowMissing) return _Reply(status, json);

    final error = json['error'];
    final code = error is Map ? error['code'] : null;
    final failure = switch (code) {
      'invalid_credentials' => AccountFailure.invalidCredentials,
      'handle_taken' => AccountFailure.handleTaken,
      'invalid_handle' => AccountFailure.invalidHandle,
      'invalid_passphrase' => AccountFailure.invalidPassphrase,
      'incorrect_passphrase' => AccountFailure.incorrectPassphrase,
      'too_many_attempts' => AccountFailure.tooManyAttempts,
      'server_busy' => AccountFailure.serverBusy,
      'invalid_token' => AccountFailure.signedOut,
      'consent_required' => AccountFailure.consentRequired,
      'body_too_large' => AccountFailure.tooLarge,
      _ => AccountFailure.server,
    };
    if (failure == AccountFailure.signedOut) await _forget();
    throw AccountException(
      failure,
      retryAfterSeconds: int.tryParse(response.headers['retry-after'] ?? ''),
    );
  }
}

class _Reply {
  const _Reply(this.status, this.json);
  final int status;
  final Map<String, Object?> json;
}

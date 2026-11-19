import 'dart:convert';

import 'package:shelf/shelf.dart';

import '../http/api_exception.dart';
import '../http/body_reader.dart';
import '../http/responses.dart';
import '../store/records.dart';
import 'api_context.dart';

/// Room for the `{"baseRevision":...,"data":...}` wrapper around a profile
/// document of the maximum size.
const int _profileEnvelopeAllowance = 1024;

const int _maxPolicyVersionLength = 64;

/// Consent, the synced profile document, and export.
final class SyncApi {
  const SyncApi(this._context);

  final ApiContext _context;

  static const ApiException _accountGone = ApiException(
    401,
    'invalid_token',
    'The account for this token no longer exists. Create an account or '
        'sign in to a different one.',
    headers: {'www-authenticate': 'Bearer'},
  );

  static const ApiException _consentRequired = ApiException(
    403,
    'consent_required',
    'Sync is turned off for this account. Grant sync consent with '
        'PUT /v1/consents/sync, then send the profile again.',
  );

  /// `GET /v1/consents`
  Future<Response> listConsents(Request request) async {
    final auth = await _context.authenticate(request);
    final consents = await _context.store.listConsents(auth.account.id);
    return jsonResponse(200, {'consents': _consentsJson(consents)});
  }

  /// `PUT /v1/consents/sync`
  Future<Response> putSyncConsent(Request request) async {
    final auth = await _context.authenticate(request);
    final body = await _context.readSmallBody(request);

    final granted = body['granted'];
    if (granted is! bool) {
      throw const ApiException(
        422,
        'invalid_request',
        'The field "granted" is missing or is not true or false. Send it as '
            'a JSON boolean.',
      );
    }
    final policyVersion = body['policyVersion'];
    if (policyVersion is! String ||
        policyVersion.isEmpty ||
        policyVersion.length > _maxPolicyVersionLength) {
      throw const ApiException(
        422,
        'invalid_request',
        'The field "policyVersion" must be a string of 1 to '
            '$_maxPolicyVersionLength characters naming the policy text '
            'the person saw.',
      );
    }

    final consent = ConsentRecord(
      granted: granted,
      at: _context.clock(),
      policyVersion: policyVersion,
    );
    // Withdrawing consent deletes the profile document in the same step.
    final stored = await _context.store.putConsent(
      auth.account.id,
      syncConsentPurpose,
      consent,
    );
    if (!stored) throw _accountGone;
    return jsonResponse(200, _consentJson(consent));
  }

  /// `GET /v1/profile`
  Future<Response> getProfile(Request request) async {
    final auth = await _context.authenticate(request);
    final profile = await _context.store.findProfile(auth.account.id);
    if (profile == null) {
      throw const ApiException(
        404,
        'no_profile',
        'No profile is stored for this account. Send one with '
            'PUT /v1/profile and baseRevision 0.',
      );
    }
    return jsonResponse(200, _profileJson(profile));
  }

  /// `PUT /v1/profile`
  Future<Response> putProfile(Request request) async {
    final auth = await _context.authenticate(request);

    // Checked here so a large body is not read for nothing, and again
    // inside the store, atomically with the write.
    final consents = await _context.store.listConsents(auth.account.id);
    if (consents[syncConsentPurpose]?.granted != true) throw _consentRequired;

    final maxBytes = _context.config.maxProfileBytes;
    final body = await readJsonObject(
      request,
      maxBytes: maxBytes + _profileEnvelopeAllowance,
      timeout: _context.config.bodyReadTimeout,
    );

    final baseRevision = body['baseRevision'];
    if (baseRevision is! int || baseRevision < 0) {
      throw const ApiException(
        422,
        'invalid_request',
        'The field "baseRevision" must be a whole number of 0 or more: the '
            'revision this change is based on, or 0 when no profile exists.',
      );
    }
    final data = body['data'];
    if (data is! Map<String, Object?>) {
      throw const ApiException(
        422,
        'invalid_request',
        'The field "data" is missing or is not a JSON object. Send the '
            'profile as an object.',
      );
    }
    // The server does not look inside the document; it only measures it.
    if (utf8.encode(jsonEncode(data)).length > maxBytes) {
      throw ApiException(
        413,
        'body_too_large',
        'The profile data is larger than the $maxBytes bytes this endpoint '
            'accepts. Send a smaller document.',
      );
    }

    final result = await _context.store.writeProfile(
      auth.account.id,
      baseRevision: baseRevision,
      data: data,
      updatedAt: _context.clock(),
    );
    switch (result.status) {
      case ProfileWriteStatus.written:
        final profile = result.profile!;
        return jsonResponse(200, {
          'revision': profile.revision,
          'updatedAt': isoTime(profile.updatedAt),
        });
      case ProfileWriteStatus.conflict:
        final current = result.profile;
        throw ApiException(
          409,
          'revision_conflict',
          'The stored profile has changed since the revision this request '
              'was based on. Merge your changes into "current" and send them '
              'again with its revision as baseRevision.',
          extra: {
            'current': current == null
                ? {'revision': 0, 'updatedAt': null, 'data': null}
                : _profileJson(current),
          },
        );
      case ProfileWriteStatus.consentRequired:
        throw _consentRequired;
      case ProfileWriteStatus.accountMissing:
        throw _accountGone;
    }
  }

  /// `GET /v1/export`
  Future<Response> export(Request request) async {
    final auth = await _context.authenticate(request);
    final account = auth.account;
    final now = _context.clock();
    final consents = await _context.store.listConsents(account.id);
    final profile = await _context.store.findProfile(account.id);
    final activeSignIns = await _context.store.countActiveTokens(
      account.id,
      now,
    );
    // Everything held about the account, and nothing that could be used to
    // sign in: no passphrase hash, no salt, no token hashes.
    return jsonResponse(200, {
      'handle': account.handle,
      'createdAt': isoTime(account.createdAt),
      'consents': _consentsJson(consents),
      'profile': profile == null ? null : _profileJson(profile),
      'activeSignIns': activeSignIns,
      'exportedAt': isoTime(now),
    });
  }

  static Map<String, Object?> _consentsJson(
    Map<String, ConsentRecord> consents,
  ) {
    return {
      for (final entry in consents.entries)
        entry.key: _consentJson(entry.value),
    };
  }

  static Map<String, Object?> _consentJson(ConsentRecord consent) => {
        'granted': consent.granted,
        'at': isoTime(consent.at),
        'policyVersion': consent.policyVersion,
      };

  static Map<String, Object?> _profileJson(ProfileRecord profile) => {
        'revision': profile.revision,
        'updatedAt': isoTime(profile.updatedAt),
        'data': profile.data,
      };
}

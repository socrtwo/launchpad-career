import 'package:shelf/shelf.dart';

import '../crypto/tokens.dart';
import '../http/api_exception.dart';
import '../http/responses.dart';
import '../store/records.dart';
import 'api_context.dart';

final RegExp _handlePattern = RegExp(r'^[a-z0-9_-]{3,32}$');

const int _minPassphraseLength = 12;
const int _maxPassphraseLength = 256;

/// Accounts, sign-in, sign-out, passphrase change and account deletion.
final class AccountsApi {
  const AccountsApi(this._context);

  final ApiContext _context;

  static const ApiException _invalidCredentials = ApiException(
    401,
    'invalid_credentials',
    'The handle or passphrase is not correct. Check both and try again.',
  );

  static const ApiException _incorrectPassphrase = ApiException(
    403,
    'incorrect_passphrase',
    'The current passphrase is not correct. Check it and try again.',
  );

  static const ApiException _accountChanged = ApiException(
    409,
    'account_changed',
    'The account changed while this request was in progress. Sign in again '
        'and repeat the request.',
  );

  static const ApiException _handleTaken = ApiException(
    409,
    'handle_taken',
    'That handle is already in use. Choose a different one.',
  );

  /// `POST /v1/accounts`
  Future<Response> createAccount(Request request) async {
    final body = await _context.readSmallBody(request);
    final handle = _validHandle(_string(body, 'handle'));
    final passphrase = _validPassphrase(_string(body, 'passphrase'));

    // Every attempt that reaches this point counts, whether or not it ends
    // in an account: each costs a passphrase derivation, and the 409 below
    // would otherwise be an unmetered way to test which handles exist.
    final client = _context.clientKey(request);
    final wait = _context.creationsByClient.retryAfter(client);
    if (wait != null) throw ApiContext.tooManyAttempts(wait);
    _context.creationsByClient.record(client);

    if (await _context.store.findAccountByHandle(handle) != null) {
      throw _handleTaken;
    }

    final account = AccountRecord(
      id: generateId(_context.random),
      handle: handle,
      passphraseHash: await _context.hasher.hash(passphrase),
      createdAt: _context.clock(),
    );
    if (!await _context.store.createAccount(account)) throw _handleTaken;

    final session = await _context.issueToken(account);
    if (session == null) throw _accountChanged;
    return jsonResponse(201, session);
  }

  /// `POST /v1/sessions`
  Future<Response> signIn(Request request) async {
    final body = await _context.readSmallBody(request);
    final handle = _string(body, 'handle').toLowerCase();
    final passphrase = _string(body, 'passphrase');

    // A handle that could never have been registered is treated exactly
    // like one that was not: same work, same response.
    final wellFormed = _handlePattern.hasMatch(handle);
    var account =
        wellFormed ? await _context.store.findAccountByHandle(handle) : null;

    final matches = await _context.checkPassphrase(
      request,
      handleKey: wellFormed ? handle : null,
      account: account,
      passphrase: passphrase,
    );
    if (!matches || account == null) throw _invalidCredentials;

    if (_context.hasher.needsRehash(account.passphraseHash)) {
      // The work factor was raised since this hash was made. The passphrase
      // is in hand and known to be right, so bring the hash up to date.
      final upgraded = await _context.hasher.hash(passphrase);
      final replaced = await _context.store.replacePassphraseHash(
        accountId: account.id,
        expectedPassphraseHash: account.passphraseHash,
        newPassphraseHash: upgraded,
        revokeOtherTokens: false,
      );
      if (!replaced) throw _invalidCredentials;
      account = account.withPassphraseHash(upgraded);
    }

    final session = await _context.issueToken(account);
    // Null means the passphrase was changed or the account deleted while
    // this sign-in was being checked, so what was presented no longer holds.
    if (session == null) throw _invalidCredentials;
    return jsonResponse(200, session);
  }

  /// `DELETE /v1/sessions/current`
  Future<Response> signOut(Request request) async {
    final auth = await _context.authenticate(request);
    await _context.store.deleteToken(auth.tokenHash);
    return noContent();
  }

  /// `PUT /v1/account/passphrase`
  Future<Response> changePassphrase(Request request) async {
    final auth = await _context.authenticate(request);
    final body = await _context.readSmallBody(request);
    final current = _string(body, 'currentPassphrase');
    final replacement = _validPassphrase(_string(body, 'newPassphrase'));

    await _reauthenticate(request, auth.account, current);
    if (replacement == current) {
      throw const ApiException(
        422,
        'invalid_passphrase',
        'The new passphrase is the same as the current one. Choose a '
            'different passphrase.',
      );
    }

    final replaced = await _context.store.replacePassphraseHash(
      accountId: auth.account.id,
      expectedPassphraseHash: auth.account.passphraseHash,
      newPassphraseHash: await _context.hasher.hash(replacement),
      revokeOtherTokens: true,
      keepTokenHash: auth.tokenHash,
    );
    if (!replaced) throw _accountChanged;
    return noContent();
  }

  /// `DELETE /v1/account`
  Future<Response> deleteAccount(Request request) async {
    final auth = await _context.authenticate(request);
    final body = await _context.readSmallBody(request);
    final passphrase = _string(body, 'passphrase');

    await _reauthenticate(request, auth.account, passphrase);

    final deleted = await _context.store.deleteAccount(
      accountId: auth.account.id,
      expectedPassphraseHash: auth.account.passphraseHash,
    );
    if (!deleted) throw _accountChanged;
    return noContent();
  }

  /// A valid token is not enough for the two irreversible account actions:
  /// the passphrase is checked again, under the same limits as sign-in, so
  /// a stolen token cannot be used to guess it.
  Future<void> _reauthenticate(
    Request request,
    AccountRecord account,
    String passphrase,
  ) async {
    final matches = await _context.checkPassphrase(
      request,
      handleKey: account.handle,
      account: account,
      passphrase: passphrase,
    );
    if (!matches) throw _incorrectPassphrase;
  }

  static String _string(Map<String, Object?> body, String field) {
    final value = body[field];
    if (value is String) return value;
    throw ApiException(
      422,
      'invalid_request',
      'The field "$field" is missing or is not a string. Send it as a JSON '
          'string.',
    );
  }

  static String _validHandle(String raw) {
    final handle = raw.toLowerCase();
    if (handle.contains('@')) {
      throw const ApiException(
        422,
        'invalid_handle',
        'Do not use an email address as your handle. This service keeps no '
            'contact details. Choose 3 to 32 letters, digits, hyphens or '
            'underscores instead.',
      );
    }
    if (!_handlePattern.hasMatch(handle)) {
      throw const ApiException(
        422,
        'invalid_handle',
        'Choose a handle of 3 to 32 characters using only the letters a to '
            'z, digits, hyphens and underscores.',
      );
    }
    return handle;
  }

  static String _validPassphrase(String passphrase) {
    // Counted in Unicode code points, so a character outside the basic
    // plane is one character, not two.
    final length = passphrase.runes.length;
    if (length < _minPassphraseLength || length > _maxPassphraseLength) {
      throw const ApiException(
        422,
        'invalid_passphrase',
        'Choose a passphrase of $_minPassphraseLength to '
            '$_maxPassphraseLength characters.',
      );
    }
    return passphrase;
  }
}

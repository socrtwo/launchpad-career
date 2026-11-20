import 'dart:math';

import 'package:shelf/shelf.dart';

import '../config.dart';
import '../crypto/passphrase_hasher.dart';
import '../crypto/tokens.dart';
import '../http/api_exception.dart';
import '../http/body_reader.dart';
import '../http/client_key.dart';
import '../rate_limiter.dart';
import '../store/records.dart';
import '../store/server_store.dart';

/// The largest body accepted by the small account, session and consent
/// endpoints. Generous enough for two 256-character passphrases written
/// entirely as JSON escapes.
const int smallBodyLimit = 16 * 1024;

/// An authenticated request: the account, and the hash of the token used.
final class Authenticated {
  const Authenticated(this.account, this.tokenHash);

  final AccountRecord account;
  final String tokenHash;
}

/// What every endpoint group shares: configuration, the store, the clock,
/// the hasher, the rate limiters, and the authentication steps.
final class ApiContext {
  ApiContext({
    required this.config,
    required this.store,
    required this.clock,
    required this.hasher,
    required this.random,
  })  : failuresByHandle = RateLimiter(
          limit: 5,
          window: const Duration(minutes: 15),
          clock: clock,
        ),
        failuresByClient = RateLimiter(
          limit: 20,
          window: const Duration(minutes: 15),
          clock: clock,
        ),
        creationsByClient = RateLimiter(
          limit: 10,
          window: const Duration(hours: 1),
          clock: clock,
        );

  final ServerConfig config;
  final ServerStore store;
  final Clock clock;
  final PassphraseHasher hasher;
  final Random random;

  /// Failed passphrase checks per handle: 5 in 15 minutes.
  final RateLimiter failuresByHandle;

  /// Failed passphrase checks per client: 20 in 15 minutes.
  final RateLimiter failuresByClient;

  /// Account creation attempts per client: 10 in an hour.
  final RateLimiter creationsByClient;

  static final RegExp _bearer =
      RegExp(r'^Bearer +(\S+)$', caseSensitive: false);

  static const ApiException _invalidToken = ApiException(
    401,
    'invalid_token',
    'The sign-in token is missing, expired or revoked. Sign in again to get '
        'a new one.',
    headers: {'www-authenticate': 'Bearer'},
  );

  /// The credentials from `Authorization: Bearer <credentials>`, or null.
  static String? bearerCredentials(Request request) {
    final header = request.headers['authorization'];
    if (header == null) return null;
    return _bearer.firstMatch(header.trim())?.group(1);
  }

  String clientKey(Request request) =>
      clientKeyFor(request, trustProxy: config.trustProxy);

  Future<Map<String, Object?>> readSmallBody(Request request) {
    return readJsonObject(
      request,
      maxBytes: smallBodyLimit,
      timeout: config.bodyReadTimeout,
    );
  }

  /// Resolves the bearer token to its account, or throws 401
  /// `invalid_token`. A missing, malformed, unknown, expired or orphaned
  /// token all produce the same response.
  Future<Authenticated> authenticate(Request request) async {
    final token = bearerCredentials(request);
    if (token == null || !looksLikeToken(token)) throw _invalidToken;

    final tokenHash = hashToken(token);
    final record = await store.findToken(tokenHash);
    if (record == null) throw _invalidToken;
    if (record.isExpiredAt(clock())) {
      await store.deleteToken(tokenHash);
      throw _invalidToken;
    }
    final account = await store.findAccountById(record.accountId);
    if (account == null) throw _invalidToken;
    return Authenticated(account, tokenHash);
  }

  /// Checks [passphrase] against [account] under the failed-attempt limits.
  ///
  /// [account] is null for a handle that does not exist; the same amount of
  /// hashing work is done either way. [handleKey] is null when the handle
  /// could not belong to any account, in which case only the per-client
  /// limit applies.
  ///
  /// The attempt is counted *before* the passphrase is checked and taken
  /// back if the check succeeds, so parallel guesses cannot outrun the
  /// limit. Throws 429 `too_many_attempts` when a limit is already reached.
  Future<bool> checkPassphrase(
    Request request, {
    required String? handleKey,
    required AccountRecord? account,
    required String passphrase,
  }) async {
    final client = clientKey(request);
    final waits = [
      failuresByClient.retryAfter(client),
      if (handleKey != null) failuresByHandle.retryAfter(handleKey),
    ].whereType<Duration>();
    if (waits.isNotEmpty) {
      throw tooManyAttempts(waits.reduce((a, b) => a > b ? a : b));
    }

    final attempts = [
      failuresByClient.record(client),
      if (handleKey != null) failuresByHandle.record(handleKey),
    ];
    void forget() {
      for (final attempt in attempts) {
        attempt.cancel();
      }
    }

    final bool matches;
    try {
      if (account == null) {
        await hasher.burn(passphrase);
        matches = false;
      } else {
        matches = await hasher.verify(passphrase, account.passphraseHash);
      }
    } on Object {
      // The check did not run, so it is not a failed attempt.
      forget();
      rethrow;
    }
    if (matches) forget();
    return matches;
  }

  /// The 429 response for a limit that frees up after [wait].
  static ApiException tooManyAttempts(Duration wait) {
    final seconds = max(1, (wait.inMilliseconds / 1000).ceil());
    return ApiException(
      429,
      'too_many_attempts',
      'Too many attempts. Wait $seconds seconds, then try again.',
      headers: {'retry-after': '$seconds'},
    );
  }

  /// Creates a token for [account] and returns its JSON body, or null when
  /// the account changed or disappeared since [account] was read.
  Future<Map<String, Object?>?> issueToken(AccountRecord account) async {
    final token = generateToken(random);
    final now = clock();
    final expiresAt = now.add(config.tokenLifetime);
    final created = await store.createToken(
      TokenRecord(
        tokenHash: hashToken(token),
        accountId: account.id,
        createdAt: now,
        expiresAt: expiresAt,
      ),
      expectedPassphraseHash: account.passphraseHash,
      maxPerAccount: config.maxSignInsPerAccount,
    );
    if (!created) return null;
    return {
      'token': token,
      'expiresAt': expiresAt.toUtc().toIso8601String(),
    };
  }
}

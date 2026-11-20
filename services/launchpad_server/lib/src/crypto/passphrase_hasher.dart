import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'pbkdf2.dart';
import 'secure_compare.dart';
import 'tokens.dart';

/// Thrown when too many passphrase derivations are already waiting.
///
/// Each derivation costs around a second of processor time at the default
/// work factor, so the queue is bounded rather than allowed to grow until
/// the process runs out of memory.
final class HasherBusyException implements Exception {
  const HasherBusyException();

  @override
  String toString() => 'HasherBusyException';
}

/// Hashes and verifies passphrases with PBKDF2-HMAC-SHA256.
///
/// Stored form: `pbkdf2-sha256$<iterations>$<salt b64>$<hash b64>`. The
/// iteration count travels with each hash, so [iterations] can be raised
/// later without invalidating existing accounts; [needsRehash] reports which
/// stored hashes are behind the current setting.
final class PassphraseHasher {
  PassphraseHasher({
    this.iterations = defaultIterations,
    Random? random,
    this.useIsolate = true,
    this.maxConcurrent = 2,
    this.maxQueued = 32,
  }) : _random = random ?? Random.secure() {
    if (iterations < 1) {
      throw ArgumentError.value(iterations, 'iterations', 'must be at least 1');
    }
    if (maxConcurrent < 1) {
      throw ArgumentError.value(maxConcurrent, 'maxConcurrent');
    }
    if (maxQueued < 0) {
      throw ArgumentError.value(maxQueued, 'maxQueued');
    }
  }

  /// The work factor used for new hashes when none is configured.
  static const int defaultIterations = 600000;

  /// The scheme label at the front of every stored hash.
  static const String scheme = 'pbkdf2-sha256';

  /// Stored hashes claiming more iterations than this are treated as
  /// corrupt rather than run, so a damaged data file cannot stall the server.
  static const int maxStoredIterations = 100000000;

  static const int _saltLength = 16;
  static const int _hashLength = 32;

  /// The work factor used for new hashes.
  final int iterations;

  /// Whether derivations run on a separate isolate. Turn this off only in
  /// tests that need to run without isolates.
  final bool useIsolate;

  /// How many derivations may run at the same time.
  final int maxConcurrent;

  /// How many derivations may wait for a free slot before new ones are
  /// refused with [HasherBusyException].
  final int maxQueued;

  final Random _random;
  final Queue<Completer<void>> _waiting = Queue<Completer<void>>();
  int _running = 0;
  int _derivationCount = 0;

  /// How many derivations this hasher has started. Tests use it to confirm
  /// that a sign-in for an unknown handle does the same work as one with a
  /// wrong passphrase.
  int get derivationCount => _derivationCount;

  /// Hashes [passphrase] with a fresh random salt.
  Future<String> hash(String passphrase) async {
    final salt = randomBytes(_random, _saltLength);
    final derived = await _derive(passphrase, salt, iterations);
    return '$scheme\$$iterations\$${base64.encode(salt)}'
        '\$${base64.encode(derived)}';
  }

  /// Whether [passphrase] matches [stored]. A malformed [stored] value never
  /// matches.
  Future<bool> verify(String passphrase, String stored) async {
    final parsed = _ParsedHash.tryParse(stored);
    if (parsed == null) {
      // Spend comparable effort so a corrupt record is not a timing signal.
      await burn(passphrase);
      return false;
    }
    final derived = await _derive(passphrase, parsed.salt, parsed.iterations);
    return constantTimeBytesEqual(derived, parsed.hash);
  }

  /// Runs one derivation at the current work factor and discards the result.
  ///
  /// Sign-in calls this for handles that do not exist, so an unknown handle
  /// and a wrong passphrase take a comparable amount of time.
  Future<void> burn(String passphrase) async {
    await _derive(passphrase, randomBytes(_random, _saltLength), iterations);
  }

  /// Whether [stored] was produced with a lower work factor than the current
  /// one and should be replaced after a successful verification.
  ///
  /// A hash made with a higher work factor is left alone: lowering the
  /// setting never weakens an existing hash.
  bool needsRehash(String stored) {
    final parsed = _ParsedHash.tryParse(stored);
    return parsed != null && parsed.iterations < iterations;
  }

  Future<Uint8List> _derive(
    String passphrase,
    Uint8List salt,
    int iterations,
  ) async {
    await _acquire();
    _derivationCount++;
    try {
      final password = utf8.encode(passphrase);
      if (!useIsolate) {
        return pbkdf2HmacSha256(password, salt, iterations, _hashLength);
      }
      return await _deriveOnIsolate(password, salt, iterations);
    } finally {
      _release();
    }
  }

  Future<void> _acquire() {
    if (_running < maxConcurrent) {
      _running++;
      return Future<void>.value();
    }
    if (_waiting.length >= maxQueued) {
      throw const HasherBusyException();
    }
    final turn = Completer<void>();
    _waiting.add(turn);
    return turn.future;
  }

  void _release() {
    if (_waiting.isNotEmpty) {
      // Hand the slot straight to the next waiter; [_running] is unchanged.
      _waiting.removeFirst().complete();
    } else {
      _running--;
    }
  }
}

/// Kept at the top level so the closure sent to the isolate captures only
/// these three values and nothing from the hasher or the request.
Future<Uint8List> _deriveOnIsolate(
  Uint8List password,
  Uint8List salt,
  int iterations,
) {
  return Isolate.run(
    () => pbkdf2HmacSha256(password, salt, iterations, 32),
  );
}

final class _ParsedHash {
  const _ParsedHash(this.iterations, this.salt, this.hash);

  final int iterations;
  final Uint8List salt;
  final Uint8List hash;

  static _ParsedHash? tryParse(String stored) {
    final parts = stored.split(r'$');
    if (parts.length != 4 || parts[0] != PassphraseHasher.scheme) return null;
    final iterations = int.tryParse(parts[1]);
    if (iterations == null ||
        iterations < 1 ||
        iterations > PassphraseHasher.maxStoredIterations) {
      return null;
    }
    try {
      final salt = base64.decode(parts[2]);
      final hash = base64.decode(parts[3]);
      if (salt.isEmpty || hash.length != PassphraseHasher._hashLength) {
        return null;
      }
      return _ParsedHash(iterations, salt, hash);
    } on FormatException {
      return null;
    }
  }
}

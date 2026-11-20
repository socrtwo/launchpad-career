import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:launchpad_server/launchpad_server.dart';
import 'package:launchpad_server/src/crypto/tokens.dart';
import 'package:test/test.dart';

String _hex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

void main() {
  group('pbkdf2HmacSha256', () {
    final password = utf8.encode('password');
    final salt = utf8.encode('salt');

    test('matches the published vector for 1 iteration', () {
      expect(
        _hex(pbkdf2HmacSha256(password, salt, 1, 32)),
        '120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b',
      );
    });

    test('matches the published vector for 2 iterations', () {
      expect(
        _hex(pbkdf2HmacSha256(password, salt, 2, 32)),
        'ae4d0c95af6b46d32d0adff928f06dd02a303f8ef3c251dfd6e2d85a95474c43',
      );
    });

    test('matches the published vector for 4096 iterations', () {
      expect(
        _hex(pbkdf2HmacSha256(password, salt, 4096, 32)),
        'c5e478d59288c841aa530db6845c4c8d962893a001ce4e11a4963873aa98134a',
      );
    });

    test('matches the published multi-block vector (40 bytes)', () {
      expect(
        _hex(
          pbkdf2HmacSha256(
            utf8.encode('passwordPASSWORDpassword'),
            utf8.encode('saltSALTsaltSALTsaltSALTsaltSALTsalt'),
            4096,
            40,
          ),
        ),
        '348c89dbcbd32b2f32d814b8116e84cf2b17347ebc1800181c4e2a1fb8dd53e1'
        'c635518c7dac47e9',
      );
    });

    test('a shorter output is a prefix of a longer one', () {
      final long = pbkdf2HmacSha256(password, salt, 3, 64);
      final short = pbkdf2HmacSha256(password, salt, 3, 20);
      expect(short, long.sublist(0, 20));
    });

    test('rejects a non-positive iteration count or length', () {
      expect(
          () => pbkdf2HmacSha256(password, salt, 0, 32), throwsArgumentError);
      expect(() => pbkdf2HmacSha256(password, salt, 1, 0), throwsArgumentError);
    });
  });

  group('PassphraseHasher', () {
    test('stores scheme, iterations, a 16-byte salt and a 32-byte hash',
        () async {
      final hasher = PassphraseHasher(iterations: 3);
      final stored = await hasher.hash('correct horse battery');
      final parts = stored.split(r'$');
      expect(parts, hasLength(4));
      expect(parts[0], 'pbkdf2-sha256');
      expect(parts[1], '3');
      expect(base64.decode(parts[2]), hasLength(16));
      expect(base64.decode(parts[3]), hasLength(32));
      expect(stored, isNot(contains('correct horse')));
    });

    test('the stored hash is PBKDF2 of the passphrase with that salt',
        () async {
      final stored = await PassphraseHasher(iterations: 5).hash('pass phrase');
      final parts = stored.split(r'$');
      expect(
        base64.encode(
          pbkdf2HmacSha256(
            utf8.encode('pass phrase'),
            base64.decode(parts[2]),
            5,
            32,
          ),
        ),
        parts[3],
      );
    });

    test('uses a fresh salt every time', () async {
      final hasher = PassphraseHasher(iterations: 2);
      final first = await hasher.hash('same passphrase');
      final second = await hasher.hash('same passphrase');
      expect(first, isNot(second));
      expect(first.split(r'$')[2], isNot(second.split(r'$')[2]));
    });

    test('verifies the right passphrase and rejects a wrong one', () async {
      final hasher = PassphraseHasher(iterations: 3);
      final stored = await hasher.hash('correct horse battery');
      expect(await hasher.verify('correct horse battery', stored), isTrue);
      expect(await hasher.verify('correct horse batterz', stored), isFalse);
      expect(await hasher.verify('', stored), isFalse);
    });

    test('verifies with the iteration count stored in the hash', () async {
      final stored = await PassphraseHasher(iterations: 2).hash('a passphrase');
      final later = PassphraseHasher(iterations: 7);
      expect(await later.verify('a passphrase', stored), isTrue);
      expect(later.needsRehash(stored), isTrue);
      expect(later.needsRehash(await later.hash('a passphrase')), isFalse);
    });

    test('does not ask for a rehash when the stored work factor is higher',
        () async {
      final stored = await PassphraseHasher(iterations: 9).hash('a passphrase');
      expect(PassphraseHasher(iterations: 4).needsRehash(stored), isFalse);
    });

    test('gives the same answers with and without an isolate', () async {
      final inline = PassphraseHasher(iterations: 3, useIsolate: false);
      final isolated = PassphraseHasher(iterations: 3);
      final stored = await inline.hash('correct horse battery');
      expect(await isolated.verify('correct horse battery', stored), isTrue);
      expect(await isolated.verify('something else here', stored), isFalse);
    });

    test('never matches a malformed stored value', () async {
      final hasher = PassphraseHasher(iterations: 2);
      for (final stored in [
        '',
        'plaintext',
        r'pbkdf2-sha256$2$c2FsdA==',
        r'bcrypt$2$c2FsdA==$aGFzaA==',
        r'pbkdf2-sha256$0$c2FsdA==$aGFzaA==',
        r'pbkdf2-sha256$x$c2FsdA==$aGFzaA==',
        r'pbkdf2-sha256$2$!!!$aGFzaA==',
        r'pbkdf2-sha256$2$c2FsdA==$aGFzaA==',
        r'pbkdf2-sha256$999999999999$c2FsdA==$aGFzaA==',
      ]) {
        expect(await hasher.verify('anything', stored), isFalse,
            reason: stored);
        expect(hasher.needsRehash(stored), isFalse, reason: stored);
      }
    });

    test('counts one derivation each for hash, verify and burn', () async {
      final hasher = PassphraseHasher(iterations: 2);
      final stored = await hasher.hash('a passphrase');
      expect(hasher.derivationCount, 1);
      await hasher.verify('a passphrase', stored);
      expect(hasher.derivationCount, 2);
      await hasher.burn('a passphrase');
      expect(hasher.derivationCount, 3);
    });

    test('queues beyond maxConcurrent and refuses beyond maxQueued', () async {
      final hasher = PassphraseHasher(
        iterations: 2,
        maxConcurrent: 1,
        maxQueued: 2,
      );
      final accepted = [
        hasher.hash('first passphrase'),
        hasher.hash('second passphrase'),
        hasher.hash('third passphrase'),
      ];
      await expectLater(
        hasher.hash('fourth passphrase'),
        throwsA(isA<HasherBusyException>()),
      );
      expect(await Future.wait(accepted), hasLength(3));
      // Once the queue has drained, new work is accepted again.
      expect(
          await hasher.hash('fifth passphrase'), startsWith('pbkdf2-sha256'));
    });

    test('rejects a non-positive work factor', () {
      expect(() => PassphraseHasher(iterations: 0), throwsArgumentError);
    });
  });

  group('constant-time comparison', () {
    test('compares byte sequences', () {
      expect(constantTimeBytesEqual([1, 2, 3], [1, 2, 3]), isTrue);
      expect(constantTimeBytesEqual([1, 2, 3], [1, 2, 4]), isFalse);
      expect(constantTimeBytesEqual([9, 2, 3], [1, 2, 3]), isFalse);
      expect(constantTimeBytesEqual([1, 2, 3], [1, 2]), isFalse);
      expect(constantTimeBytesEqual([], []), isTrue);
    });

    test('compares strings of any length', () {
      expect(constantTimeStringEqual('secret', 'secret'), isTrue);
      expect(constantTimeStringEqual('secret', 'secreT'), isFalse);
      expect(constantTimeStringEqual('secret', 'secret-and-more'), isFalse);
      expect(constantTimeStringEqual('', 'secret'), isFalse);
    });
  });

  group('tokens', () {
    test('are 32 random bytes in unpadded base64url', () {
      final token = generateToken(Random.secure());
      expect(token, matches(RegExp(r'^[A-Za-z0-9_-]{43}$')));
      expect(base64Url.decode('$token='), hasLength(32));
      expect(looksLikeToken(token), isTrue);
    });

    test('do not repeat', () {
      final random = Random.secure();
      final tokens = {for (var i = 0; i < 200; i++) generateToken(random)};
      expect(tokens, hasLength(200));
    });

    test('are stored as the SHA-256 of their text', () {
      const token = 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
      expect(hashToken(token), sha256.convert(utf8.encode(token)).toString());
      expect(hashToken(token), hasLength(64));
    });

    test('anything of another shape does not look like a token', () {
      expect(looksLikeToken(''), isFalse);
      expect(looksLikeToken('short'), isFalse);
      expect(looksLikeToken('${'A' * 42}='), isFalse);
      expect(looksLikeToken('A' * 44), isFalse);
      expect(looksLikeToken('${'A' * 42} '), isFalse);
    });
  });
}

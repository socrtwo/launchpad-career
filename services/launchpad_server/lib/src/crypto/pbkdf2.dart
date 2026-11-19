import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Length in bytes of one HMAC-SHA256 output block.
const int _blockLength = 32;

/// Derives [length] bytes from [password] and [salt] with PBKDF2-HMAC-SHA256
/// (RFC 8018, section 5.2).
///
/// This is deliberately slow for large [iterations] and runs synchronously.
/// Call it through `PassphraseHasher`, which moves the work off the main
/// isolate, rather than directly from a request handler.
Uint8List pbkdf2HmacSha256(
  List<int> password,
  List<int> salt,
  int iterations,
  int length,
) {
  if (iterations < 1) {
    throw ArgumentError.value(iterations, 'iterations', 'must be at least 1');
  }
  if (length < 1) {
    throw ArgumentError.value(length, 'length', 'must be at least 1');
  }

  final hmac = Hmac(sha256, password);
  final output = Uint8List(length);
  final blockCount = (length + _blockLength - 1) ~/ _blockLength;
  final saltAndIndex = Uint8List(salt.length + 4)
    ..setRange(0, salt.length, salt);

  for (var block = 1; block <= blockCount; block++) {
    saltAndIndex[salt.length] = (block >> 24) & 0xff;
    saltAndIndex[salt.length + 1] = (block >> 16) & 0xff;
    saltAndIndex[salt.length + 2] = (block >> 8) & 0xff;
    saltAndIndex[salt.length + 3] = block & 0xff;

    var u = hmac.convert(saltAndIndex).bytes;
    final t = Uint8List.fromList(u);
    for (var i = 1; i < iterations; i++) {
      u = hmac.convert(u).bytes;
      for (var k = 0; k < _blockLength; k++) {
        t[k] ^= u[k];
      }
    }

    final offset = (block - 1) * _blockLength;
    final remaining = length - offset;
    output.setRange(
      offset,
      offset + (remaining < _blockLength ? remaining : _blockLength),
      t,
    );
  }
  return output;
}

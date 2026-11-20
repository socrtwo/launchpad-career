import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// The shape of every bearer token this server issues: 32 random bytes in
/// unpadded base64url, which is always 43 characters.
final RegExp _tokenPattern = RegExp(r'^[A-Za-z0-9_-]{43}$');

/// Returns [length] bytes from [random].
Uint8List randomBytes(Random random, int length) {
  final bytes = Uint8List(length);
  for (var i = 0; i < length; i++) {
    bytes[i] = random.nextInt(256);
  }
  return bytes;
}

/// Generates a new bearer token: 32 random bytes, base64url without padding.
///
/// The value is returned to the client once and never stored; only
/// [hashToken] of it is kept.
String generateToken(Random random) {
  return base64Url.encode(randomBytes(random, 32)).replaceAll('=', '');
}

/// Generates an opaque internal identifier (16 random bytes, base64url).
String generateId(Random random) {
  return base64Url.encode(randomBytes(random, 16)).replaceAll('=', '');
}

/// Whether [token] has the shape of a token issued by [generateToken].
bool looksLikeToken(String token) => _tokenPattern.hasMatch(token);

/// The value stored for a token: the SHA-256 of its text, hex encoded.
///
/// Tokens carry 256 bits of entropy, so a plain hash is enough; a slow hash
/// is only needed for low-entropy secrets such as passphrases.
String hashToken(String token) => sha256.convert(utf8.encode(token)).toString();

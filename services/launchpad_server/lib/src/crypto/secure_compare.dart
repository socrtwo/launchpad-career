import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Compares two byte sequences without stopping at the first difference.
///
/// The running time depends only on the lengths, never on where the
/// sequences differ. Sequences of different lengths are unequal.
bool constantTimeBytesEqual(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  var difference = 0;
  for (var i = 0; i < a.length; i++) {
    difference |= a[i] ^ b[i];
  }
  return difference == 0;
}

/// Compares two secrets in constant time, without revealing their lengths.
///
/// Both strings are hashed first, so the comparison always runs over two
/// 32-byte digests whatever the caller supplied.
bool constantTimeStringEqual(String a, String b) {
  return constantTimeBytesEqual(
    sha256.convert(utf8.encode(a)).bytes,
    sha256.convert(utf8.encode(b)).bytes,
  );
}

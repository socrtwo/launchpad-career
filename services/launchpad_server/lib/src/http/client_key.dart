import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:shelf/shelf.dart';

/// The key used when nothing identifies the client, for example when the
/// handler is called directly without a socket.
const String unknownClientKey = 'unknown';

/// Identifies the client for rate limiting.
///
/// With [trustProxy], this is the first value of `X-Forwarded-For`;
/// otherwise, or when that header is absent, the socket's remote address.
/// IPv6 addresses are reduced to their /64 prefix, because one subscriber
/// usually controls a whole /64.
///
/// The result is held in memory by the rate limiters only. It is never
/// logged and never stored.
String clientKeyFor(Request request, {required bool trustProxy}) {
  if (trustProxy) {
    final forwarded = request.headers['x-forwarded-for'];
    if (forwarded != null) {
      final first = forwarded.split(',').first.trim();
      if (first.isNotEmpty) return _normalise(first);
    }
  }
  final connection = request.context['shelf.io.connection_info'];
  if (connection is HttpConnectionInfo) {
    return _normalise(connection.remoteAddress.address);
  }
  return unknownClientKey;
}

String _normalise(String value) {
  final address = InternetAddress.tryParse(value);
  if (address == null) {
    // Not an address. Hash it so the key has a fixed size whatever the
    // header contained.
    return 'other:${sha256.convert(utf8.encode(value))}';
  }
  if (address.type != InternetAddressType.IPv6) return 'v4:${address.address}';

  final raw = address.rawAddress;
  if (_isIPv4Mapped(raw)) {
    // ::ffff:a.b.c.d is an IPv4 client seen through an IPv6 socket. Keying
    // it by /64 would put every such client in one bucket.
    return 'v4:${raw[12]}.${raw[13]}.${raw[14]}.${raw[15]}';
  }
  final prefix = raw.sublist(0, 8);
  return 'v6:${prefix.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
}

bool _isIPv4Mapped(List<int> raw) {
  for (var i = 0; i < 10; i++) {
    if (raw[i] != 0) return false;
  }
  return raw[10] == 0xff && raw[11] == 0xff;
}

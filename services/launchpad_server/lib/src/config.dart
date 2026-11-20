import 'dart:io' show Platform;

import 'package:meta/meta.dart';

import 'crypto/passphrase_hasher.dart';

/// Supplies the current time. Tests inject a clock they control.
typedef Clock = DateTime Function();

/// Receives one log line per request.
typedef LogSink = void Function(String line);

/// Thrown when the configuration is not safe or not usable.
final class ConfigException implements Exception {
  const ConfigException(this.message);

  final String message;

  @override
  String toString() => 'ConfigException: $message';
}

/// Everything about the server that an operator can change.
@immutable
final class ServerConfig {
  /// Throws [ConfigException] when a value is unsafe: an admin token shorter
  /// than [minAdminTokenLength], a wildcard or malformed origin, or a
  /// non-positive limit.
  ServerConfig({
    this.port = 8080,
    this.dataFile,
    this.adminToken,
    Iterable<String> allowedOrigins = const [],
    this.pbkdf2Iterations = PassphraseHasher.defaultIterations,
    this.trustProxy = false,
    this.tokenLifetime = const Duration(days: 30),
    this.maxProfileBytes = 256 * 1024,
    this.maxCatalogBytes = 1024 * 1024,
    this.bodyReadTimeout = const Duration(seconds: 30),
    this.maxSignInsPerAccount = 20,
    int? hashConcurrency,
  })  : allowedOrigins = Set.unmodifiable(allowedOrigins),
        hashConcurrency =
            hashConcurrency ?? Platform.numberOfProcessors.clamp(1, 8) {
    if (port < 0 || port > 65535) {
      throw const ConfigException('PORT must be between 0 and 65535.');
    }
    final token = adminToken;
    if (token != null && token.length < minAdminTokenLength) {
      throw const ConfigException(
        'ADMIN_TOKEN must be at least $minAdminTokenLength characters. '
        'Generate a long random value, or leave it unset to turn the admin '
        'routes off.',
      );
    }
    for (final origin in this.allowedOrigins) {
      if (!_isExactOrigin(origin)) {
        throw const ConfigException(
          'ALLOWED_ORIGINS must list exact origins such as '
          'https://app.example.org, separated by commas. Wildcards, paths '
          'and trailing slashes are not accepted.',
        );
      }
    }
    if (pbkdf2Iterations < 1) {
      throw const ConfigException(
        'PBKDF2_ITERATIONS must be a positive whole number.',
      );
    }
    if (maxProfileBytes < 1 || maxCatalogBytes < 1) {
      throw const ConfigException('Body limits must be positive.');
    }
    if (maxSignInsPerAccount < 1) {
      throw const ConfigException('maxSignInsPerAccount must be at least 1.');
    }
    if (this.hashConcurrency < 1) {
      throw const ConfigException('hashConcurrency must be at least 1.');
    }
  }

  /// Reads the configuration from environment variables.
  ///
  /// Recognised: `PORT`, `DATA_FILE`, `ADMIN_TOKEN`, `ALLOWED_ORIGINS`,
  /// `PBKDF2_ITERATIONS`, `TRUST_PROXY`. Empty values count as unset.
  factory ServerConfig.fromEnvironment(Map<String, String> environment) {
    String? read(String name) {
      final value = environment[name]?.trim();
      return value == null || value.isEmpty ? null : value;
    }

    int readInt(String name, int fallback) {
      final raw = read(name);
      if (raw == null) return fallback;
      final value = int.tryParse(raw);
      if (value == null) {
        throw ConfigException('$name must be a whole number.');
      }
      return value;
    }

    bool readBool(String name) {
      final raw = read(name)?.toLowerCase();
      if (raw == null || raw == 'false' || raw == '0') return false;
      if (raw == 'true' || raw == '1') return true;
      throw ConfigException('$name must be true or false.');
    }

    final origins = read('ALLOWED_ORIGINS');
    return ServerConfig(
      port: readInt('PORT', 8080),
      dataFile: read('DATA_FILE'),
      adminToken: read('ADMIN_TOKEN'),
      allowedOrigins: origins == null
          ? const []
          : origins
              .split(',')
              .map((origin) => origin.trim())
              .where((origin) => origin.isNotEmpty),
      pbkdf2Iterations: readInt(
        'PBKDF2_ITERATIONS',
        PassphraseHasher.defaultIterations,
      ),
      trustProxy: readBool('TRUST_PROXY'),
    );
  }

  /// The shortest admin token the server accepts.
  static const int minAdminTokenLength = 32;

  /// The TCP port to listen on. 0 asks the system for a free port.
  final int port;

  /// Where `FileServerStore` keeps its data. Null means nothing is
  /// persisted.
  final String? dataFile;

  /// The bearer token for the admin routes. Null turns those routes off:
  /// they answer 404.
  final String? adminToken;

  /// The browser origins allowed to call the API. Never a wildcard.
  final Set<String> allowedOrigins;

  /// The PBKDF2 work factor for new passphrase hashes.
  final int pbkdf2Iterations;

  /// Whether the first `X-Forwarded-For` value identifies the client. Turn
  /// this on only behind a reverse proxy that overwrites that header.
  final bool trustProxy;

  /// How long a sign-in lasts.
  final Duration tokenLifetime;

  /// The largest profile document accepted, as compact UTF-8 JSON.
  final int maxProfileBytes;

  /// The largest catalogue upload accepted.
  final int maxCatalogBytes;

  /// How long a client may take to send a request body.
  final Duration bodyReadTimeout;

  /// How many sign-ins one account may hold at once. A further sign-in
  /// revokes the oldest.
  final int maxSignInsPerAccount;

  /// How many passphrase derivations may run at the same time.
  final int hashConcurrency;

  static bool _isExactOrigin(String origin) {
    if (origin.contains('*')) return false;
    final uri = Uri.tryParse(origin);
    if (uri == null) return false;
    if (uri.scheme != 'http' && uri.scheme != 'https') return false;
    if (uri.host.isEmpty || uri.userInfo.isNotEmpty) return false;
    if (uri.path.isNotEmpty || uri.hasQuery || uri.hasFragment) return false;
    // Browsers send origins in lower case with no default port, and the
    // comparison is exact, so anything else would never match.
    return origin == uri.origin;
  }
}

import 'package:launchpad_server/launchpad_server.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  group('ServerConfig.fromEnvironment', () {
    test('has safe defaults when nothing is set', () {
      final config = ServerConfig.fromEnvironment(const {});
      expect(config.port, 8080);
      expect(config.dataFile, isNull);
      expect(config.adminToken, isNull);
      expect(config.allowedOrigins, isEmpty);
      expect(config.pbkdf2Iterations, 600000);
      expect(config.trustProxy, isFalse);
      expect(config.tokenLifetime, const Duration(days: 30));
      expect(config.maxProfileBytes, 256 * 1024);
      expect(config.maxCatalogBytes, 1024 * 1024);
    });

    test('reads every variable', () {
      final config = ServerConfig.fromEnvironment(const {
        'PORT': '9090',
        'DATA_FILE': '/data/launchpad.json',
        'ADMIN_TOKEN': testAdminToken,
        'ALLOWED_ORIGINS': 'https://app.example.org, http://localhost:5000',
        'PBKDF2_ITERATIONS': '700000',
        'TRUST_PROXY': 'true',
      });
      expect(config.port, 9090);
      expect(config.dataFile, '/data/launchpad.json');
      expect(config.adminToken, testAdminToken);
      expect(
        config.allowedOrigins,
        {'https://app.example.org', 'http://localhost:5000'},
      );
      expect(config.pbkdf2Iterations, 700000);
      expect(config.trustProxy, isTrue);
    });

    test('treats empty values as unset', () {
      final config = ServerConfig.fromEnvironment(const {
        'DATA_FILE': '',
        'ADMIN_TOKEN': '  ',
        'ALLOWED_ORIGINS': '',
        'TRUST_PROXY': '',
      });
      expect(config.dataFile, isNull);
      expect(config.adminToken, isNull);
      expect(config.allowedOrigins, isEmpty);
      expect(config.trustProxy, isFalse);
    });

    test('refuses an admin token shorter than 32 characters', () {
      expect(
        () => ServerConfig.fromEnvironment({'ADMIN_TOKEN': 'a' * 31}),
        throwsA(
          isA<ConfigException>().having(
            (e) => e.message,
            'message',
            allOf(contains('ADMIN_TOKEN'), contains('32')),
          ),
        ),
      );
      expect(
        ServerConfig.fromEnvironment({'ADMIN_TOKEN': 'a' * 32}).adminToken,
        'a' * 32,
      );
    });

    test('the refusal does not repeat the token', () {
      try {
        ServerConfig.fromEnvironment(const {'ADMIN_TOKEN': 'hunter2-secret'});
        fail('expected a ConfigException');
      } on ConfigException catch (error) {
        expect(error.toString(), isNot(contains('hunter2')));
      }
    });

    test('refuses a wildcard origin', () {
      expect(
        () => ServerConfig.fromEnvironment(const {'ALLOWED_ORIGINS': '*'}),
        throwsA(isA<ConfigException>()),
      );
      expect(
        () => ServerConfig.fromEnvironment(
          const {'ALLOWED_ORIGINS': 'https://*.example.org'},
        ),
        throwsA(isA<ConfigException>()),
      );
    });

    test('refuses origins that could never match a browser origin', () {
      for (final origin in [
        'app.example.org',
        'https://app.example.org/',
        'https://app.example.org/path',
        'https://APP.example.org',
        'https://app.example.org:443',
        'ftp://app.example.org',
        'https://user@app.example.org',
        'null',
      ]) {
        expect(
          () => ServerConfig.fromEnvironment({'ALLOWED_ORIGINS': origin}),
          throwsA(isA<ConfigException>()),
          reason: origin,
        );
      }
    });

    test('refuses values that are not numbers or booleans', () {
      expect(
        () => ServerConfig.fromEnvironment(const {'PORT': 'eighty'}),
        throwsA(isA<ConfigException>()),
      );
      expect(
        () => ServerConfig.fromEnvironment(const {'PORT': '70000'}),
        throwsA(isA<ConfigException>()),
      );
      expect(
        () => ServerConfig.fromEnvironment(const {'PBKDF2_ITERATIONS': '0'}),
        throwsA(isA<ConfigException>()),
      );
      expect(
        () => ServerConfig.fromEnvironment(const {'TRUST_PROXY': 'yes'}),
        throwsA(isA<ConfigException>()),
      );
    });
  });

  test('the constructor applies the same admin token rule', () {
    expect(
      () => ServerConfig(adminToken: 'too-short'),
      throwsA(isA<ConfigException>()),
    );
  });
}

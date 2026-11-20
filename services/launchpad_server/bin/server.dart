import 'dart:async';
import 'dart:io';

import 'package:launchpad_server/launchpad_server.dart';

/// Starts the server from environment variables. See the README for the
/// full list.
Future<void> main() async {
  final ServerConfig config;
  try {
    config = ServerConfig.fromEnvironment(Platform.environment);
  } on ConfigException catch (error) {
    stderr.writeln('Cannot start: ${error.message}');
    exitCode = 64;
    return;
  }

  if (config.pbkdf2Iterations < PassphraseHasher.defaultIterations) {
    stderr.writeln(
      'Warning: PBKDF2_ITERATIONS is ${config.pbkdf2Iterations}, below the '
      'default of ${PassphraseHasher.defaultIterations}. New passphrase '
      'hashes will be weaker than recommended.',
    );
  }

  final ServerStore store;
  final dataFile = config.dataFile;
  if (dataFile == null) {
    stderr.writeln(
      'Warning: DATA_FILE is not set, so nothing is persisted. Every '
      'account, consent, profile and catalogue is lost when the server '
      'stops.',
    );
    store = InMemoryServerStore();
  } else {
    try {
      store = await FileServerStore.open(dataFile);
    } on StoreFormatException catch (error) {
      stderr.writeln('Cannot start: ${error.message}');
      exitCode = 65;
      return;
    } on FileSystemException catch (error) {
      stderr.writeln('Cannot start: ${error.message}');
      exitCode = 74;
      return;
    }
  }

  final handler = buildHandler(config, store, logSink: stdout.writeln);
  final server = await serveHandler(
    handler,
    address: InternetAddress.anyIPv4,
    port: config.port,
  );
  stdout.writeln(
    'Listening on port ${server.port}. Admin routes are '
    '${config.adminToken == null ? 'off' : 'on'}.',
  );

  // Expired sign-ins are also removed when they are next presented; this
  // sweep catches the ones that never come back.
  final sweep = Timer.periodic(const Duration(hours: 1), (_) {
    unawaited(
      store.deleteExpiredTokens(DateTime.now().toUtc()).then<void>(
        (_) {},
        onError: (Object error) {
          stderr.writeln('Expired sign-in sweep failed: ${error.runtimeType}');
        },
      ),
    );
  });

  final signals = <StreamSubscription<ProcessSignal>>[];
  var stopping = false;

  Future<void> stop() async {
    if (stopping) return;
    stopping = true;
    stdout.writeln('Stopping: finishing requests in progress.');
    sweep.cancel();
    // Stop accepting connections and let requests in progress finish, but
    // do not wait for ever on a connection that never completes.
    try {
      await server.close().timeout(const Duration(seconds: 10));
    } on TimeoutException {
      await server.close(force: true);
    }
    await store.close();
    for (final signal in signals) {
      await signal.cancel();
    }
    stdout.writeln('Stopped.');
  }

  signals
    ..add(ProcessSignal.sigint.watch().listen((_) => unawaited(stop())))
    ..add(ProcessSignal.sigterm.watch().listen((_) => unawaited(stop())));
}

import 'dart:async';

import 'package:launchpad_domain/launchpad_domain.dart';

/// Session state held in RAM for the lifetime of the process.
///
/// Deliberately not backed by shared_preferences or a database yet: nothing the
/// user types survives the app being closed until there is a consent flow and a
/// documented retention policy.
class InMemorySessionRepository implements SessionRepository {
  InMemorySessionRepository([Session initial = const Session()])
      : _session = initial,
        _controller = StreamController<Session>.broadcast() {
    _controller.onListen = () => _controller.add(_session);
  }

  Session _session;
  final StreamController<Session> _controller;

  @override
  Session current() => _session;

  @override
  Stream<Session> watch() => _controller.stream;

  @override
  Future<void> update(Session session) async {
    _session = session;
    _controller.add(session);
  }

  Future<void> dispose() => _controller.close();
}

import '../entities/session.dart';

/// Stores the current anonymous session.
///
/// Implementations must not persist [Session.freeTextPrompt] to any durable
/// store without explicit user consent.
abstract interface class SessionRepository {
  Stream<Session> watch();

  Session current();

  Future<void> update(Session session);
}

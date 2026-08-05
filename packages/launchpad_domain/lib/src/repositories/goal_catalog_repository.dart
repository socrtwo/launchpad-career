import '../entities/goal.dart';

/// Supplies the goal catalogue shown on the home screen.
///
/// Implemented in-memory today (`launchpad_data`); expected to be backed by a
/// content-management service later without changing this interface.
abstract interface class GoalCatalogRepository {
  Future<List<Goal>> primaryGoals();

  Future<Goal?> goalById(GoalId id);
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:launchpad_data/launchpad_data.dart';
import 'package:launchpad_domain/launchpad_domain.dart';

/// Repository wiring. Tests and future backends override these, nothing else.
final Provider<GoalCatalogRepository> goalCatalogRepositoryProvider =
    Provider<GoalCatalogRepository>(
  (ref) => const InMemoryGoalCatalogRepository(),
);

final Provider<SessionRepository> sessionRepositoryProvider =
    Provider<SessionRepository>((ref) => InMemorySessionRepository());

final FutureProvider<List<Goal>> goalsProvider = FutureProvider<List<Goal>>(
  (ref) => ref.watch(goalCatalogRepositoryProvider).primaryGoals(),
);

/// Which primary goal is currently selected, or null.
class SelectedGoalController extends Notifier<GoalId?> {
  @override
  GoalId? build() => null;

  /// Selecting the current selection clears it. The cards behave like a radio
  /// group that can be emptied, which is what "you can return to the other
  /// options anytime" implies.
  void toggle(GoalId id) {
    state = state == id ? null : id;
  }

  void select(GoalId? id) => state = id;

  void clear() => state = null;
}

final NotifierProvider<SelectedGoalController, GoalId?> selectedGoalProvider =
    NotifierProvider<SelectedGoalController, GoalId?>(
  SelectedGoalController.new,
);

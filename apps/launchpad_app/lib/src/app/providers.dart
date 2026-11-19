import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:launchpad_data/launchpad_data.dart';
import 'package:launchpad_domain/launchpad_domain.dart';

/// Repository wiring. Tests and future backends override these, nothing else.
final Provider<GoalCatalogRepository> goalCatalogRepositoryProvider =
    Provider<GoalCatalogRepository>(
  (ref) => const InMemoryGoalCatalogRepository(),
);

/// Where an opted-in session is kept.
///
/// In memory unless `main` supplies the device store, so a test or an
/// unsupported platform can never write anything durable by accident.
final Provider<KeyValueStore> keyValueStoreProvider = Provider<KeyValueStore>(
  (ref) => InMemoryKeyValueStore(),
);

/// False when the platform refused to open its store. The interface then says
/// so instead of offering a save that would silently do nothing.
final Provider<bool> durableStorageAvailableProvider =
    Provider<bool>((ref) => true);

final Provider<PersistentSessionRepository> _persistentSessionProvider =
    Provider<PersistentSessionRepository>((ref) {
  final repository =
      PersistentSessionRepository(ref.watch(keyValueStoreProvider));
  ref.onDispose(repository.dispose);
  return repository;
});

final Provider<SessionRepository> sessionRepositoryProvider =
    Provider<SessionRepository>((ref) => ref.watch(_persistentSessionProvider));

final Provider<LocalDataRepository> localDataRepositoryProvider =
    Provider<LocalDataRepository>(
  (ref) => ref.watch(_persistentSessionProvider),
);

final FutureProvider<List<Goal>> goalsProvider = FutureProvider<List<Goal>>(
  (ref) => ref.watch(goalCatalogRepositoryProvider).primaryGoals(),
);

final Provider<OccupationCatalogRepository>
    occupationCatalogRepositoryProvider = Provider<OccupationCatalogRepository>(
  (ref) => InMemoryOccupationCatalogRepository(),
);

final Provider<LaborMarketRepository> laborMarketRepositoryProvider =
    Provider<LaborMarketRepository>(
  (ref) => const BundledLaborMarketRepository(),
);

/// Today, for deciding whether a figure is stale. A provider so a test can
/// stand in a fixed date.
final Provider<DateTime Function()> clockProvider =
    Provider<DateTime Function()>((ref) => DateTime.now);

final FutureProvider<List<Occupation>> occupationsProvider =
    FutureProvider<List<Occupation>>(
  (ref) => ref.watch(occupationCatalogRepositoryProvider).all(),
);

/// The template steps of a plan, keyed by occupation id and route kind.
final planStepsProvider =
    FutureProvider.family<List<PlanStep>, (String, RouteKind)>(
        (ref, key) async {
  final repository = ref.watch(occupationCatalogRepositoryProvider);
  final occupation = await repository.byId(key.$1);
  if (occupation == null) return const <PlanStep>[];
  return repository.planSteps(occupation, key.$2);
});

/// The bundled labour-market figures, or null when none are loaded.
final FutureProvider<LaborMarketSnapshot?> laborMarketProvider =
    FutureProvider<LaborMarketSnapshot?>(
  (ref) => ref.watch(laborMarketRepositoryProvider).snapshot(),
);

/// Which primary goal is currently selected on the home screen, or null.
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

/// True after a write to the device store failed. The session in memory is
/// unaffected; the interface explains what happened and what to do.
class StorageProblemController extends Notifier<bool> {
  @override
  bool build() => false;

  void report() => state = true;

  void clear() => state = false;
}

final NotifierProvider<StorageProblemController, bool> storageProblemProvider =
    NotifierProvider<StorageProblemController, bool>(
  StorageProblemController.new,
);

/// The working session: the goal, the answers, and how far the person got.
///
/// Every change goes through here so that it reaches the repository, and
/// through it the device store when the person has opted in. Nothing in this
/// class logs; a failed write raises [storageProblemProvider] and nothing else.
class SessionController extends Notifier<Session> {
  @override
  Session build() => ref.watch(sessionRepositoryProvider).current();

  void chooseGoal(GoalId? id) => _commit(state.copyWith(selectedGoal: id));

  void updateProfile(Profile profile) =>
      _commit(state.copyWith(profile: profile));

  void setFreeText(String? text) {
    final trimmed = text?.trim();
    _commit(
      state.copyWith(
        freeTextPrompt: (trimmed == null || trimmed.isEmpty) ? null : trimmed,
      ),
    );
  }

  /// Records the question now on screen so the sequence can be resumed.
  void reachStep(OnboardingStep step) {
    if (state.onboardingStep == step &&
        state.onboardingStatus != OnboardingStatus.notStarted) {
      return;
    }
    _commit(
      state.copyWith(
        onboardingStep: step,
        onboardingStatus: state.onboardingStatus.isFinished
            ? state.onboardingStatus
            : OnboardingStatus.inProgress,
      ),
    );
  }

  void finishOnboarding() => _commit(
        state.copyWith(
          onboardingStatus: OnboardingStatus.completed,
          onboardingStep: OnboardingStep.review,
        ),
      );

  void skipOnboarding() {
    if (state.onboardingStatus == OnboardingStatus.completed) return;
    _commit(state.copyWith(onboardingStatus: OnboardingStatus.skipped));
  }

  void toggleSaved(String occupationId) => _commit(
        state.copyWith(workspace: state.workspace.toggleSaved(occupationId)),
      );

  void toggleDone(String key) =>
      _commit(state.copyWith(workspace: state.workspace.toggleDone(key)));

  /// Starts a plan, or changes the route an existing plan follows.
  void setPlanRoute(String occupationId, RouteKind route) {
    final plan = state.workspace.plans[occupationId] ??
        ActionPlan(occupationId: occupationId);
    _commit(
      state.copyWith(
        workspace: state.workspace.withPlan(plan.withRoute(route)),
      ),
    );
  }

  /// Adds a step the person wrote. Returns false if the plan is full or the
  /// text is blank, so the page can say why nothing happened.
  bool addCustomStep(String occupationId, String text) {
    final trimmed = text.trim();
    final plan = state.workspace.plans[occupationId];
    if (trimmed.isEmpty ||
        plan == null ||
        plan.customSteps.length >= ActionPlan.maxCustomSteps) {
      return false;
    }
    var number = plan.customSteps.length + 1;
    while (plan.customSteps.any((step) => step.id == 'c$number')) {
      number++;
    }
    final step = CustomStep(
      id: 'c$number',
      text: trimmed.length > CustomStep.maxLength
          ? trimmed.substring(0, CustomStep.maxLength)
          : trimmed,
    );
    _commit(
      state.copyWith(
        workspace: state.workspace.withPlan(
          plan.withCustomSteps(<CustomStep>[...plan.customSteps, step]),
        ),
      ),
    );
    return true;
  }

  void removeCustomStep(String occupationId, String stepId) {
    final plan = state.workspace.plans[occupationId];
    if (plan == null) return;
    final key = Workspace.customStepKey(occupationId, stepId);
    final workspace = state.workspace.withPlan(
      plan.withCustomSteps(
        plan.customSteps.where((step) => step.id != stepId).toList(),
      ),
    );
    _commit(
      state.copyWith(
        workspace:
            workspace.isDone(key) ? workspace.toggleDone(key) : workspace,
      ),
    );
  }

  void removePlan(String occupationId) => _commit(
        state.copyWith(workspace: state.workspace.withoutPlan(occupationId)),
      );

  void _commit(Session next) {
    if (next == state) return;
    state = next;
    unawaited(_persist(next));
  }

  Future<void> _persist(Session next) async {
    try {
      await ref.read(sessionRepositoryProvider).update(next);
    } on Object {
      // Deliberately not logged: the only detail worth logging would be the
      // person's own answers.
      ref.read(storageProblemProvider.notifier).report();
    }
  }
}

final NotifierProvider<SessionController, Session> sessionProvider =
    NotifierProvider<SessionController, Session>(SessionController.new);

/// Whether the person has opted in to keeping their answers on this device,
/// with the actions that change it.
class LocalDataController extends Notifier<bool> {
  @override
  bool build() => ref.watch(localDataRepositoryProvider).storageEnabled;

  Future<void> enable() async {
    final repository = ref.read(localDataRepositoryProvider);
    try {
      await repository.enableStorage();
      ref.read(storageProblemProvider.notifier).clear();
    } on Object {
      ref.read(storageProblemProvider.notifier).report();
    }
    state = repository.storageEnabled;
  }

  Future<void> disable() async {
    final repository = ref.read(localDataRepositoryProvider);
    await repository.disableStorage();
    ref.read(storageProblemProvider.notifier).clear();
    state = repository.storageEnabled;
  }

  Future<void> deleteEverything() async {
    final repository = ref.read(localDataRepositoryProvider);
    await repository.deleteEverything();
    ref.read(storageProblemProvider.notifier).clear();
    ref.read(selectedGoalProvider.notifier).clear();
    ref.invalidate(sessionProvider);
    state = repository.storageEnabled;
  }

  String exportData() => ref.read(localDataRepositoryProvider).exportData();
}

final NotifierProvider<LocalDataController, bool> storageEnabledProvider =
    NotifierProvider<LocalDataController, bool>(LocalDataController.new);

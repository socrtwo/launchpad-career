import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:launchpad_data/launchpad_data.dart';
import 'package:launchpad_domain/launchpad_domain.dart';

/// The address of the optional account service, from the build:
/// `--dart-define=LAUNCHPAD_API_URL=https://…`.
///
/// Null in a build made without it, and null for anything that is not HTTPS
/// (plain HTTP is accepted only for this machine). With no address there are
/// no accounts, nothing is fetched, and the app makes no network requests of
/// its own.
final Provider<Uri?> apiBaseUrlProvider = Provider<Uri?>((ref) {
  const raw = String.fromEnvironment('LAUNCHPAD_API_URL');
  if (raw.isEmpty) return null;
  final url = Uri.tryParse(raw);
  return url != null && HttpAccountRepository.isAcceptableBaseUrl(url)
      ? url
      : null;
});

final Provider<http.Client> httpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final Provider<CatalogClient?> _catalogClientProvider =
    Provider<CatalogClient?>((ref) {
  final url = ref.watch(apiBaseUrlProvider);
  return url == null
      ? null
      : CatalogClient(baseUrl: url, client: ref.watch(httpClientProvider));
});

/// Repository wiring. Tests and backends override these, nothing else.
///
/// With an account service configured, a catalogue published there is used
/// if it passes the same checks as the bundled one; otherwise, and on any
/// failure, the bundled catalogue is used.
final Provider<GoalCatalogRepository> goalCatalogRepositoryProvider =
    Provider<GoalCatalogRepository>((ref) {
  const bundled = InMemoryGoalCatalogRepository();
  final client = ref.watch(_catalogClientProvider);
  return client == null
      ? bundled
      : RemoteFirstGoalCatalogRepository(client: client, fallback: bundled);
});

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
    occupationCatalogRepositoryProvider =
    Provider<OccupationCatalogRepository>((ref) {
  final bundled = InMemoryOccupationCatalogRepository();
  final client = ref.watch(_catalogClientProvider);
  return client == null
      ? bundled
      : RemoteFirstOccupationCatalogRepository(
          client: client,
          fallback: bundled,
        );
});

/// The optional account, or null when this build has no account service.
final Provider<AccountRepository?> accountRepositoryProvider =
    Provider<AccountRepository?>((ref) {
  final url = ref.watch(apiBaseUrlProvider);
  if (url == null) return null;
  return HttpAccountRepository(
    baseUrl: url,
    client: ref.watch(httpClientProvider),
    store: ref.watch(keyValueStoreProvider),
    mayPersist: () => ref.read(localDataRepositoryProvider).storageEnabled,
  );
});

final Provider<LaborMarketRepository> laborMarketRepositoryProvider =
    Provider<LaborMarketRepository>(
  (ref) => const BundledLaborMarketRepository(),
);

final Provider<GuidanceRepository> guidanceRepositoryProvider =
    Provider<GuidanceRepository>((ref) => const InMemoryGuidanceRepository());

final FutureProvider<List<GuideItem>> resumeSectionsProvider =
    FutureProvider<List<GuideItem>>(
  (ref) => ref.watch(guidanceRepositoryProvider).resumeSections(),
);

final FutureProvider<List<GuideItem>> linkedInSectionsProvider =
    FutureProvider<List<GuideItem>>(
  (ref) => ref.watch(guidanceRepositoryProvider).linkedInSections(),
);

final FutureProvider<List<InterviewQuestion>> interviewQuestionsProvider =
    FutureProvider<List<InterviewQuestion>>(
  (ref) => ref.watch(guidanceRepositoryProvider).interviewQuestions(),
);

final searchWeekProvider = FutureProvider.family<List<SearchTask>, SearchHours>(
  (ref, hours) => ref.watch(guidanceRepositoryProvider).searchWeek(hours),
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

  /// Records a selection from a closed set; null clears it.
  void setChoice(String key, String? value) => _commit(
        state.copyWith(workspace: state.workspace.withChoice(key, value)),
      );

  /// Records free text the person typed; blank clears it.
  void setNote(String key, String? text) =>
      _commit(state.copyWith(workspace: state.workspace.withNote(key, text)));

  void closeSearchWeek() => _commit(
        state.copyWith(workspace: state.workspace.withSearchWeekClosed()),
      );

  /// Keeps a resume line. Returns false if the limit is reached or the line
  /// is blank.
  bool keepBullet(String text) {
    if (text.trim().isEmpty) return false;
    final workspace = state.workspace;
    for (var i = 0; i < Workspace.maxSavedBullets; i++) {
      final key = Workspace.resumeBulletKey(i);
      if (workspace.notes.containsKey(key)) continue;
      final next = workspace.withNote(key, text);
      if (identical(next, workspace)) return false;
      _commit(state.copyWith(workspace: next));
      return true;
    }
    return false;
  }

  /// Removes the kept line with this exact text.
  void removeBullet(String text) {
    for (var i = 0; i < Workspace.maxSavedBullets; i++) {
      final key = Workspace.resumeBulletKey(i);
      if (state.workspace.notes[key] == text) {
        setNote(key, null);
        return;
      }
    }
  }

  void removePlan(String occupationId) => _commit(
        state.copyWith(workspace: state.workspace.withoutPlan(occupationId)),
      );

  /// Replaces this device's copy with the one from the account. The
  /// "Something else" text is never synced, so the local one is kept.
  void replaceWith(Session remote) =>
      _commit(remote.copyWith(freeTextPrompt: state.freeTextPrompt));

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
      // A sign-in made before storage was on is kept from now on too.
      await ref.read(accountRepositoryProvider)?.persistIfAllowed();
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

/// The signed-in account, or null. Signing in is never required for anything.
class AccountController extends Notifier<AccountStatus?> {
  @override
  AccountStatus? build() => ref.watch(accountRepositoryProvider)?.current;

  AccountRepository get _repository {
    final repository = ref.read(accountRepositoryProvider);
    if (repository == null) {
      throw const AccountException(AccountFailure.notConfigured);
    }
    return repository;
  }

  /// Runs [action] and then reflects whatever sign-in the repository now
  /// holds, including after a failure that ended it.
  Future<T> _run<T>(
    Future<T> Function(AccountRepository repository) action,
  ) async {
    final repository = _repository;
    try {
      return await action(repository);
    } finally {
      state = repository.current;
    }
  }

  Future<void> createAccount(String handle, String passphrase) => _run(
        (repository) =>
            repository.createAccount(handle: handle, passphrase: passphrase),
      );

  Future<void> signIn(String handle, String passphrase) => _run(
        (repository) =>
            repository.signIn(handle: handle, passphrase: passphrase),
      );

  Future<void> signOut() => _run((repository) => repository.signOut());

  Future<bool> syncConsent() => _run((repository) => repository.syncConsent());

  Future<void> setSyncConsent({required bool granted}) =>
      _run((repository) => repository.setSyncConsent(granted: granted));

  Future<SyncResult> upload({int? baseRevision}) => _run(
        (repository) => repository.upload(
          ref.read(sessionProvider),
          baseRevision: baseRevision,
        ),
      );

  /// Takes the account's copy onto this device.
  Future<void> useRemote(RemoteProfile remote) => _run((repository) async {
        ref.read(sessionProvider.notifier).replaceWith(remote.session);
        // Records the revision this device has now seen.
        await repository.download();
      });

  Future<String> exportData() => _run((repository) => repository.exportData());

  Future<void> deleteAccount(String passphrase) => _run(
        (repository) => repository.deleteAccount(passphrase: passphrase),
      );
}

final NotifierProvider<AccountController, AccountStatus?> accountProvider =
    NotifierProvider<AccountController, AccountStatus?>(AccountController.new);

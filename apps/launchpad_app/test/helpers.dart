import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:launchpad_app/src/app/app.dart';
import 'package:launchpad_app/src/app/providers.dart';
import 'package:launchpad_app/src/routing/app_router.dart';
import 'package:launchpad_data/launchpad_data.dart';
import 'package:launchpad_domain/launchpad_domain.dart';
import 'package:launchpad_ui/launchpad_ui.dart';

/// Builds the real app - real router, real theme, real widgets - optionally
/// with a stand-in catalogue.
///
/// Environment is set on the test `PlatformDispatcher` rather than by wrapping
/// the tree in a `MediaQuery`: `WidgetsApp` rebuilds `MediaQuery.fromView`
/// internally, so an ancestor `MediaQuery` is discarded and a test that sets one
/// silently asserts nothing.
///
/// The overrides list is built here rather than passed in because Riverpod 3
/// does not export the `Override` type, so callers cannot name it.
Future<void> pumpApp(
  WidgetTester tester, {
  GoalCatalogRepository? goalCatalog,
  KeyValueStore? store,
  bool storageAvailable = true,
  LaborMarketSnapshot? laborMarket,
  DateTime? now,
  Size surfaceSize = const Size(1280, 900),
  Brightness platformBrightness = Brightness.light,
  double textScaleFactor = 1.0,
  bool disableAnimations = false,
}) async {
  // Size the test view rather than calling setSurfaceSize: the latter does not
  // feed through to MediaQuery, so layout tests would silently all run at the
  // default 800x600 and pass for the wrong reason.
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = surfaceSize;
  addTearDown(tester.view.reset);

  final dispatcher = tester.binding.platformDispatcher;

  dispatcher.platformBrightnessTestValue = platformBrightness;
  addTearDown(dispatcher.clearPlatformBrightnessTestValue);

  if (textScaleFactor != 1.0) {
    dispatcher.textScaleFactorTestValue = textScaleFactor;
    addTearDown(dispatcher.clearTextScaleFactorTestValue);
  }

  if (disableAnimations) {
    dispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
      disableAnimations: true,
      reduceMotion: true,
    );
    addTearDown(dispatcher.clearAccessibilityFeaturesTestValue);
  }

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        if (goalCatalog != null)
          goalCatalogRepositoryProvider.overrideWithValue(goalCatalog),
        if (store != null) keyValueStoreProvider.overrideWithValue(store),
        if (laborMarket != null)
          laborMarketRepositoryProvider.overrideWithValue(
            FixedLaborMarketRepository(laborMarket),
          ),
        if (now != null) clockProvider.overrideWithValue(() => now),
        if (!storageAvailable)
          durableStorageAvailableProvider.overrideWithValue(false),
      ],
      child: const LaunchpadApp(),
    ),
  );
  await tester.pumpAndSettle();
}

/// The [GoalCard] whose subtree currently owns focus, if any.
GoalCard? focusedGoalCard(WidgetTester tester) {
  final context = FocusManager.instance.primaryFocus?.context;
  if (context == null) return null;
  return context.findAncestorWidgetOfExactType<GoalCard>();
}

/// A catalogue that always fails, for exercising the error state.
class FailingGoalCatalogRepository implements GoalCatalogRepository {
  const FailingGoalCatalogRepository();

  @override
  Future<List<Goal>> primaryGoals() async => throw StateError('offline');

  @override
  Future<Goal?> goalById(GoalId id) async => throw StateError('offline');
}

/// Taps a control that may be below the fold, scrolling it into view first.
Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Chooses a goal on the home screen and presses Continue.
Future<void> chooseGoalAndContinue(
  WidgetTester tester, {
  String title = 'Help me find an internship or job',
}) async {
  await tapVisible(tester, find.text(title));
  await tapVisible(tester, find.widgetWithText(FilledButton, 'Continue'));
}

/// A store whose writes always fail, for exercising the storage error path.
class FailingKeyValueStore implements KeyValueStore {
  @override
  String? read(String key) => null;

  @override
  Future<void> write(String key, String value) async =>
      throw StateError('disk full');

  @override
  Future<void> delete(String key) async {}
}

/// The provider container of the running app.
ProviderContainer containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));

/// Navigates by URL, the way a deep link or a refresh would.
Future<void> goTo(WidgetTester tester, String location) async {
  containerOf(tester).read(routerProvider).go(location);
  await tester.pumpAndSettle();
}

/// Sets the answers a person would have given in onboarding.
Future<void> setProfile(WidgetTester tester, Profile profile) async {
  containerOf(tester).read(sessionProvider.notifier).updateProfile(profile);
  await tester.pumpAndSettle();
}

/// Runs the four guideline matchers this project holds every screen to.
Future<void> expectMeetsGuidelines(WidgetTester tester) async {
  await expectLater(tester, meetsGuideline(textContrastGuideline));
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
}

/// Labour-market figures for tests. The numbers are invented and attributed
/// to an invented publisher, so they can never be mistaken for real ones.
LaborMarketSnapshot testSnapshot({DateTime? asOf}) {
  final date = asOf ?? DateTime.utc(2024, 5);
  final evidence = Evidence(
    kind: EvidenceKind.laborMarketData,
    source: 'Test Statistics Office',
    asOf: date,
  );
  LaborStats stats(String soc, int median, int low, int high, int jobs) =>
      LaborStats(
        socCode: soc,
        medianAnnualWage: median,
        lowAnnualWage: low,
        highAnnualWage: high,
        employment: jobs,
        evidence: evidence,
      );
  return LaborMarketSnapshot(
    source: 'Test Statistics Office',
    sourceUrl: 'https://example.org/stats',
    referencePeriod: 'May ${date.year}',
    asOf: date,
    retrievedOn: date,
    allOccupationsMedianAnnualWage: 50000,
    statsBySoc: <String, LaborStats>{
      '47-2111': stats('47-2111', 61000, 39000, 104000, 712345),
      '47-2152': stats('47-2152', 60000, 40000, 70000, 456789),
      '15-1252': stats('15-1252', 130000, 79000, 208000, 1654321),
    },
  );
}

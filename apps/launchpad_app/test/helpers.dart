import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:launchpad_app/src/app/app.dart';
import 'package:launchpad_app/src/app/providers.dart';
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

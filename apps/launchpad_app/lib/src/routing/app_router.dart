import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:launchpad_domain/launchpad_domain.dart';

import '../features/goal/goal_page.dart';
import '../features/home/home_page.dart';
import '../features/info/info_pages.dart';
import '../features/onboarding/onboarding_page.dart';
import '../features/something_else/something_else_page.dart';
import '../features/your_data/your_data_page.dart';
import '../l10n/app_strings.dart';

abstract final class Routes {
  static const String home = '/';
  static const String goal = '/goal';
  static const String somethingElse = '/something-else';
  static const String onboardingBase = '/onboarding';
  static const String yourData = '/your-data';
  static const String about = '/about';
  static const String privacy = '/privacy';
  static const String accessibility = '/accessibility';

  /// Goal pages are deep-linkable by slug, e.g. `/goal?id=interview-preparation`.
  static String goalFor(GoalId id) => '$goal?id=${id.slug}';

  /// Onboarding questions are addressed by slug too, e.g. `/onboarding/plans`.
  static String onboarding(OnboardingStep step) =>
      '$onboardingBase/${step.slug}';

  /// Where "Continue where you left off" goes, or null if there is nothing to
  /// come back to.
  static String? resume(Session session) {
    final step = session.onboardingStep;
    if (session.onboardingStatus == OnboardingStatus.inProgress &&
        step != null) {
      return onboarding(step);
    }
    final goal = session.selectedGoal;
    if (goal != null) return goalFor(goal);
    if (!session.profile.isEmpty) return onboarding(OnboardingStep.review);
    return null;
  }

  /// Where a goal's flow continues once the questions are finished or skipped.
  static String afterOnboarding(Session session) {
    final goal = session.selectedGoal;
    return goal == null ? home : goalFor(goal);
  }
}

/// Router as a provider so tests can build a fresh one per case and so a later
/// auth guard has somewhere to read state from.
final Provider<GoRouter> routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: Routes.home,
    routes: <RouteBase>[
      GoRoute(
        path: Routes.home,
        name: 'home',
        builder: (context, state) => const HomePage(),
      ),
      GoRoute(
        path: Routes.goal,
        name: 'goal',
        builder: (context, state) => GoalPage(
          goalId: GoalId.fromSlug(state.uri.queryParameters['id']),
        ),
      ),
      GoRoute(
        path: Routes.somethingElse,
        name: 'something-else',
        builder: (context, state) => const SomethingElsePage(),
      ),
      GoRoute(
        path: Routes.onboardingBase,
        redirect: (context, state) => state.uri.path == Routes.onboardingBase
            ? Routes.onboarding(OnboardingStep.first)
            : null,
        routes: <RouteBase>[
          GoRoute(
            path: ':step',
            name: 'onboarding',
            redirect: (context, state) =>
                OnboardingStep.fromSlug(state.pathParameters['step']) == null
                    ? Routes.onboarding(OnboardingStep.first)
                    : null,
            builder: (context, state) {
              final step =
                  OnboardingStep.fromSlug(state.pathParameters['step']) ??
                      OnboardingStep.first;
              // go_router keeps one page for the whole `:step` pattern, so
              // without a key the State would be reused across questions and
              // the step reached would never be recorded after the first.
              return OnboardingPage(
                key: ValueKey<OnboardingStep>(step),
                step: step,
              );
            },
          ),
        ],
      ),
      GoRoute(
        path: Routes.yourData,
        name: 'your-data',
        builder: (context, state) => const YourDataPage(),
      ),
      GoRoute(
        path: Routes.about,
        name: 'about',
        builder: (context, state) => const AboutPage(),
      ),
      GoRoute(
        path: Routes.privacy,
        name: 'privacy',
        builder: (context, state) => const PrivacyPage(),
      ),
      GoRoute(
        path: Routes.accessibility,
        name: 'accessibility',
        builder: (context, state) => const AccessibilityPage(),
      ),
    ],
    errorBuilder: (context, state) => const _RouteNotFoundPage(),
  );
});

class _RouteNotFoundPage extends StatelessWidget {
  const _RouteNotFoundPage();

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(strings.pageNotFoundTitle)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(strings.pageNotFoundBody),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.go(Routes.home),
              child: Text(strings.goToStart),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:launchpad_domain/launchpad_domain.dart';

import '../features/explore/compare_page.dart';
import '../features/explore/explore_page.dart';
import '../features/explore/occupation_page.dart';
import '../features/explore/plan_page.dart';
import '../features/explore/saved_page.dart';
import '../features/explore/suggestions_page.dart';
import '../features/goal/goal_page.dart';
import '../features/home/home_page.dart';
import '../features/info/info_pages.dart';
import '../features/onboarding/onboarding_page.dart';
import '../features/something_else/something_else_page.dart';
import '../features/tools/guide_pages.dart';
import '../features/tools/interview_page.dart';
import '../features/tools/progress_page.dart';
import '../features/tools/search_plan_page.dart';
import '../features/tools/skills_page.dart';
import '../features/tools/tools_page.dart';
import '../features/your_data/your_data_page.dart';
import '../l10n/app_strings.dart';

abstract final class Routes {
  static const String home = '/';
  static const String goal = '/goal';
  static const String somethingElse = '/something-else';
  static const String onboardingBase = '/onboarding';
  static const String yourData = '/your-data';
  static const String explore = '/explore';
  static const String occupationBase = '/occupation';
  static const String compareBase = '/compare';
  static const String saved = '/saved';
  static const String suggestions = '/suggestions';
  static const String planBase = '/plan';
  static const String tools = '/tools';
  static const String searchPlan = '/tools/search-plan';
  static const String resumeGuide = '/tools/resume';
  static const String linkedIn = '/tools/linkedin';
  static const String interview = '/tools/interview';
  static const String skills = '/tools/skills';
  static const String progress = '/progress';

  /// Interview questions are addressed by slug, e.g.
  /// `/tools/interview?q=teamwork`.
  static String interviewQuestion(String id) =>
      '$interview?q=${Uri.encodeQueryComponent(id)}';

  static String skillsFor(String occupationId) =>
      '$skills?id=${Uri.encodeQueryComponent(occupationId)}';
  static const String about = '/about';
  static const String privacy = '/privacy';
  static const String accessibility = '/accessibility';

  /// Goal pages are deep-linkable by slug, e.g. `/goal?id=interview-preparation`.
  static String goalFor(GoalId id) => '$goal?id=${id.slug}';

  /// Onboarding questions are addressed by slug too, e.g. `/onboarding/plans`.
  static String onboarding(OnboardingStep step) =>
      '$onboardingBase/${step.slug}';

  /// Occupations are addressed by slug, e.g. `/occupation?id=electrician`.
  static String occupation(String id) =>
      '$occupationBase?id=${Uri.encodeQueryComponent(id)}';

  static String plan(String id) =>
      '$planBase?id=${Uri.encodeQueryComponent(id)}';

  /// The comparison is in the URL so it can be refreshed or shared, e.g.
  /// `/compare?ids=electrician,plumber`.
  static String compare(List<String> ids) => ids.isEmpty
      ? compareBase
      : '$compareBase?ids=${ids.map(Uri.encodeQueryComponent).join(',')}';

  static List<String> compareIds(Uri uri) {
    final seen = <String>{};
    return <String>[
      for (final id in (uri.queryParameters['ids'] ?? '').split(','))
        if (id.isNotEmpty && seen.add(id)) id,
    ].take(Workspace.maxCompared).toList();
  }

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
        path: Routes.explore,
        name: 'explore',
        builder: (context, state) => const ExplorePage(),
      ),
      GoRoute(
        path: Routes.occupationBase,
        name: 'occupation',
        builder: (context, state) => OccupationPage(
          key: ValueKey<String?>(state.uri.queryParameters['id']),
          occupationId: state.uri.queryParameters['id'],
        ),
      ),
      GoRoute(
        path: Routes.compareBase,
        name: 'compare',
        builder: (context, state) =>
            ComparePage(ids: Routes.compareIds(state.uri)),
      ),
      GoRoute(
        path: Routes.saved,
        name: 'saved',
        builder: (context, state) => const SavedPage(),
      ),
      GoRoute(
        path: Routes.suggestions,
        name: 'suggestions',
        builder: (context, state) => const SuggestionsPage(),
      ),
      GoRoute(
        path: Routes.planBase,
        name: 'plan',
        builder: (context, state) => PlanPage(
          key: ValueKey<String?>(state.uri.queryParameters['id']),
          occupationId: state.uri.queryParameters['id'],
        ),
      ),
      GoRoute(
        path: Routes.tools,
        name: 'tools',
        builder: (context, state) => const ToolsPage(),
        routes: <RouteBase>[
          GoRoute(
            path: 'search-plan',
            name: 'search-plan',
            builder: (context, state) => const SearchPlanPage(),
          ),
          GoRoute(
            path: 'resume',
            name: 'resume',
            builder: (context, state) => const ResumePage(),
          ),
          GoRoute(
            path: 'linkedin',
            name: 'linkedin',
            builder: (context, state) => const LinkedInPage(),
          ),
          GoRoute(
            path: 'interview',
            name: 'interview',
            builder: (context, state) => InterviewPage(
              key: ValueKey<String?>(state.uri.queryParameters['q']),
              questionId: state.uri.queryParameters['q'],
            ),
          ),
          GoRoute(
            path: 'skills',
            name: 'skills',
            builder: (context, state) => SkillsPage(
              key: ValueKey<String?>(state.uri.queryParameters['id']),
              occupationId: state.uri.queryParameters['id'],
            ),
          ),
        ],
      ),
      GoRoute(
        path: Routes.progress,
        name: 'progress',
        builder: (context, state) => const ProgressPage(),
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

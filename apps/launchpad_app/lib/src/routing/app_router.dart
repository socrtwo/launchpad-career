import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:launchpad_domain/launchpad_domain.dart';

import '../features/goal/goal_page.dart';
import '../features/home/home_page.dart';
import '../features/info/info_pages.dart';
import '../features/something_else/something_else_page.dart';

abstract final class Routes {
  static const String home = '/';
  static const String goal = '/goal';
  static const String somethingElse = '/something-else';
  static const String about = '/about';
  static const String privacy = '/privacy';
  static const String accessibility = '/accessibility';

  /// Goal pages are deep-linkable by slug, e.g. `/goal?id=interview-preparation`.
  static String goalFor(GoalId id) => '$goal?id=${id.slug}';
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
    return Scaffold(
      appBar: AppBar(title: const Text('Page not found')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text('That page does not exist.'),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.go(Routes.home),
              child: const Text('Go to the start'),
            ),
          ],
        ),
      ),
    );
  }
}

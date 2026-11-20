import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:launchpad_core/launchpad_core.dart';
import 'package:launchpad_domain/launchpad_domain.dart';
import 'package:launchpad_ui/launchpad_ui.dart';

import '../../app/app_page.dart';
import '../../app/providers.dart';
import '../../l10n/app_strings.dart';
import '../../routing/app_router.dart';
import 'goal_tools.dart';

/// Placeholder destination for a selected goal.
///
/// It reads the goal from the URL rather than from selection state so that a
/// shared or refreshed link still works - the same reason the route carries a
/// slug instead of an enum index.
class GoalPage extends ConsumerWidget {
  const GoalPage({super.key, required this.goalId});

  final GoalId? goalId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppStrings.of(context);
    final id = goalId;

    if (id == null) {
      return _GoalScaffold(
        title: 'Goal',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(strings.goalLinkUnknown),
            const SizedBox(height: Spacing.md),
            FilledButton(
              onPressed: () => context.go(Routes.home),
              child: Text(strings.backToStart),
            ),
          ],
        ),
      );
    }

    final goals = ref.watch(goalsProvider);
    return goals.when(
      loading: () => const _GoalScaffold(
        title: 'Goal',
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => _GoalScaffold(
        title: 'Goal',
        child: Text(strings.goalsUnavailable),
      ),
      data: (data) {
        final goal = data.where((item) => item.id == id).firstOrNull;
        if (goal == null) {
          return _GoalScaffold(
            title: 'Goal',
            child: Text(strings.goalsUnavailable),
          );
        }
        final tools = toolsFor(goal.id, strings);
        return _GoalScaffold(
          title: goal.title,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Semantics(
                header: true,
                child: Text(
                  goal.title,
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
              ),
              const SizedBox(height: Spacing.sm),
              Text(
                goal.description,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: Spacing.lg),
              Semantics(
                header: true,
                child: Text(
                  strings.goalToolsHeading,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              const SizedBox(height: Spacing.sm),
              for (final tool in tools)
                Padding(
                  padding: const EdgeInsets.only(bottom: Spacing.sm),
                  child: SecondaryChoiceTile(
                    title: tool.title,
                    description: tool.description,
                    icon: tool.icon,
                    onPressed: () => context.go(tool.location),
                  ),
                ),
              const SizedBox(height: Spacing.xl),
              Wrap(
                spacing: Spacing.sm,
                runSpacing: Spacing.xs,
                children: <Widget>[
                  OutlinedButton.icon(
                    onPressed: () => context.go(Routes.home),
                    icon: const Icon(Icons.arrow_back),
                    label: Text(strings.backToStart),
                  ),
                  OutlinedButton(
                    onPressed: () =>
                        context.go(Routes.onboarding(OnboardingStep.review)),
                    child: Text(strings.yourAnswers),
                  ),
                  OutlinedButton(
                    onPressed: () => context.go(Routes.tools),
                    child: Text(strings.toolsTitle),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _GoalScaffold extends StatelessWidget {
  const _GoalScaffold({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      AppPage(maxWidth: Breakpoints.maxContentWidth, child: child);
}

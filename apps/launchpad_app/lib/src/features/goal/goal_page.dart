import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:launchpad_core/launchpad_core.dart';
import 'package:launchpad_domain/launchpad_domain.dart';
import 'package:launchpad_ui/launchpad_ui.dart';

import '../../app/providers.dart';
import '../../l10n/app_strings.dart';
import '../../routing/app_router.dart';

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
            const Text('That goal link is not one we recognise.'),
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
              _NoticeCard(text: strings.phaseOneNotice),
              const SizedBox(height: Spacing.lg),
              Semantics(
                header: true,
                child: Text(
                  strings.whatHappensNext,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              const SizedBox(height: Spacing.xs),
              Text(
                goal.nextStep,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: Spacing.xl),
              OutlinedButton.icon(
                onPressed: () => context.go(Routes.home),
                icon: const Icon(Icons.arrow_back),
                label: Text(strings.backToStart),
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.of(context).appName),
        leading: IconButton(
          onPressed: () => context.go(Routes.home),
          icon: const Icon(Icons.arrow_back),
          tooltip: AppStrings.of(context).backToStart,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(child: ContentColumn(child: child)),
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.info_outline, size: 20, color: scheme.onSurfaceVariant),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

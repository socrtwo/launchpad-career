import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:launchpad_core/launchpad_core.dart';
import 'package:launchpad_domain/launchpad_domain.dart';
import 'package:launchpad_ui/launchpad_ui.dart';

import '../../app/providers.dart';
import '../../l10n/app_strings.dart';
import '../../routing/app_router.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppStrings.of(context);
    final goals = ref.watch(goalsProvider);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: ContentColumn(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const _Masthead(),
                const SizedBox(height: Spacing.xl),
                Semantics(
                  header: true,
                  child: Text(
                    strings.mainQuestion,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                const SizedBox(height: Spacing.xxs),
                Text(
                  strings.instruction,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: Spacing.md),
                goals.when(
                  loading: () => _LoadingGoals(label: strings.loading),
                  error: (error, stack) => _GoalsError(
                    message: strings.goalsUnavailable,
                    retryLabel: strings.retry,
                    onRetry: () => ref.invalidate(goalsProvider),
                  ),
                  data: (data) => _GoalSection(goals: data),
                ),
                const SizedBox(height: Spacing.lg),
                SecondaryChoiceTile(
                  title: strings.somethingElseTitle,
                  description: strings.somethingElseDescription,
                  icon: Icons.chat_bubble_outline,
                  onPressed: () => context.go(Routes.somethingElse),
                ),
                const SizedBox(height: Spacing.lg),
                const _Legal(),
                const SizedBox(height: Spacing.xl),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Masthead extends StatelessWidget {
  const _Masthead();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = AppStrings.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(Radii.control),
              ),
              child: Icon(
                Icons.rocket_launch_outlined,
                color: theme.colorScheme.onPrimary,
                size: 24,
              ),
            ),
            const SizedBox(width: Spacing.sm),
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  strings.appName,
                  style: theme.textTheme.headlineLarge,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: Spacing.sm),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Text(strings.tagline, style: theme.textTheme.bodyLarge),
        ),
      ],
    );
  }
}

class _GoalSection extends ConsumerWidget {
  const _GoalSection({required this.goals});

  final List<Goal> goals;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppStrings.of(context);
    final selectedId = ref.watch(selectedGoalProvider);
    final selectedGoal = selectedId == null
        ? null
        : goals.where((goal) => goal.id == selectedId).firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        GoalGrid(
          goals: goals,
          selected: selectedId,
          onSelected: (id) =>
              ref.read(selectedGoalProvider.notifier).toggle(id),
        ),
        StatusLine(
          message: selectedGoal == null
              ? null
              : strings.selectionAnnouncement(selectedGoal.title),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: Tooltip(
            message: selectedId == null ? strings.continueHintDisabled : '',
            child: FilledButton.icon(
              onPressed: selectedId == null
                  ? null
                  : () => context.go(Routes.goalFor(selectedId)),
              icon: const Icon(Icons.arrow_forward),
              iconAlignment: IconAlignment.end,
              label: Text(strings.continueLabel),
            ),
          ),
        ),
      ],
    );
  }
}

class _LoadingGoals extends StatelessWidget {
  const _LoadingGoals({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: label,
      child: const Padding(
        padding: EdgeInsets.symmetric(vertical: Spacing.xl),
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _GoalsError extends StatelessWidget {
  const _GoalsError({
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });

  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(message, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: Spacing.sm),
          OutlinedButton(onPressed: onRetry, child: Text(retryLabel)),
        ],
      ),
    );
  }
}

class _Legal extends StatelessWidget {
  const _Legal();

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(strings.noGuarantee, style: theme.textTheme.bodyMedium),
        const SizedBox(height: Spacing.xs),
        Wrap(
          spacing: Spacing.md,
          children: <Widget>[
            TextButton(
              onPressed: () => context.go(Routes.about),
              child: const Text('About'),
            ),
            TextButton(
              onPressed: () => context.go(Routes.privacy),
              child: const Text('Privacy'),
            ),
            TextButton(
              onPressed: () => context.go(Routes.accessibility),
              child: const Text('Accessibility'),
            ),
          ],
        ),
      ],
    );
  }
}

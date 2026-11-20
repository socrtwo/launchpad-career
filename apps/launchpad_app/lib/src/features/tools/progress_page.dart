import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:launchpad_core/launchpad_core.dart';
import 'package:launchpad_domain/launchpad_domain.dart';

import '../../app/app_page.dart';
import '../../app/providers.dart';
import '../../l10n/app_strings.dart';
import '../../routing/app_router.dart';

/// What a person has done so far, in one place.
///
/// A record for the person's own use. There are deliberately no scores, no
/// streaks and no time-on-screen figures: the product's principles name time
/// on screen as explicitly not a success signal.
class ProgressPage extends ConsumerWidget {
  const ProgressPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppStrings.of(context);
    final theme = Theme.of(context);
    final session = ref.watch(sessionProvider);
    final workspace = session.workspace;
    final occupations =
        ref.watch(occupationsProvider).value ?? const <Occupation>[];
    final resume = ref.watch(resumeSectionsProvider).value?.length ?? 0;
    final linkedIn = ref.watch(linkedInSectionsProvider).value?.length ?? 0;
    final questions = ref.watch(interviewQuestionsProvider).value?.length ?? 0;
    final hours = workspace.searchHours;
    final week = hours == null
        ? const <SearchTask>[]
        : ref.watch(searchWeekProvider(hours)).value ?? const <SearchTask>[];
    final skillsRated =
        workspace.choices.keys.where((key) => key.startsWith('skill/')).length;

    final rows = <_Row>[
      _Row(
        title: strings.progressQuestions,
        value: strings.progressQuestionsValue(session.profile.answeredCount, 5),
        done: session.profile.answeredCount,
        total: 5,
        location: Routes.onboarding(OnboardingStep.review),
      ),
      _Row(
        title: strings.savedTitle,
        value: strings.progressSaved(workspace.savedOccupations.length),
        location: Routes.saved,
      ),
      for (final occupation in occupations)
        if (workspace.plans[occupation.id]?.route != null)
          _planRow(ref, strings, workspace, occupation),
      _Row(
        title: strings.searchPlanTitle,
        value: hours == null
            ? strings.searchWeeks(workspace.searchWeeksCompleted)
            : '${strings.searchWeeks(workspace.searchWeeksCompleted)} '
                '${strings.searchThisWeek}: '
                '${strings.doneCount(workspace.doneUnder('search/week/'), week.length)}',
        done: hours == null ? null : workspace.doneUnder('search/week/'),
        total: hours == null ? null : week.length,
        location: Routes.searchPlan,
      ),
      _Row(
        title: strings.resumeTitle,
        value: strings.doneCount(workspace.doneUnder('resume/'), resume),
        done: workspace.doneUnder('resume/'),
        total: resume,
        location: Routes.resumeGuide,
      ),
      _Row(
        title: strings.linkedInTitle,
        value: strings.doneCount(workspace.doneUnder('linkedin/'), linkedIn),
        done: workspace.doneUnder('linkedin/'),
        total: linkedIn,
        location: Routes.linkedIn,
      ),
      _Row(
        title: strings.interviewTitle,
        value: strings.practisedCount(
          workspace.doneUnder('interview/'),
          questions,
        ),
        done: workspace.doneUnder('interview/'),
        total: questions,
        location: Routes.interview,
      ),
      _Row(
        title: strings.skillsTitle,
        value: strings.skillsRated(skillsRated, skillsRated),
        location: Routes.skills,
      ),
    ];

    return AppPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          PageHeading(strings.progressTitle),
          const SizedBox(height: Spacing.sm),
          Text(strings.progressIntro, style: theme.textTheme.bodyLarge),
          const SizedBox(height: Spacing.md),
          if (!session.hasProgress) ...<Widget>[
            Text(strings.progressEmpty, style: theme.textTheme.bodyLarge),
            const SizedBox(height: Spacing.md),
          ],
          for (final row in rows) _RowView(row: row),
          const SizedBox(height: Spacing.md),
          OutlinedButton(
            onPressed: () => context.go(Routes.tools),
            child: Text(strings.toolsTitle),
          ),
        ],
      ),
    );
  }

  static _Row _planRow(
    WidgetRef ref,
    AppStrings strings,
    Workspace workspace,
    Occupation occupation,
  ) {
    final plan = workspace.plans[occupation.id]!;
    final route = plan.route!;
    final template =
        ref.watch(planStepsProvider((occupation.id, route))).value ??
            const <PlanStep>[];
    final done = workspace.doneUnder('plan/${occupation.id}/${route.slug}/') +
        workspace.doneUnder('plan/${occupation.id}/custom/');
    final total = template.length + plan.customSteps.length;
    return _Row(
      title: strings.progressPlan(occupation.title),
      value: strings.planProgress(done, total),
      done: done,
      total: total,
      location: Routes.plan(occupation.id),
    );
  }
}

@immutable
class _Row {
  const _Row({
    required this.title,
    required this.value,
    required this.location,
    this.done,
    this.total,
  });

  final String title;
  final String value;
  final String location;
  final int? done;
  final int? total;
}

class _RowView extends StatelessWidget {
  const _RowView({required this.row});

  final _Row row;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final theme = Theme.of(context);
    final total = row.total;
    final done = row.done;
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.sm),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(Spacing.md),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Radii.control),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Semantics(
              header: true,
              child: Text(row.title, style: theme.textTheme.titleMedium),
            ),
            const SizedBox(height: Spacing.xxs),
            Text(row.value, style: theme.textTheme.bodyLarge),
            if (total != null && done != null && total > 0) ...<Widget>[
              const SizedBox(height: Spacing.xs),
              // The words above carry the progress; the bar repeats it.
              ExcludeSemantics(
                child: LinearProgressIndicator(
                  value: (done / total).clamp(0, 1).toDouble(),
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(Radii.chip),
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                ),
              ),
            ],
            Align(
              alignment: Alignment.centerLeft,
              child: Semantics(
                container: true,
                button: true,
                label: strings.openTool(row.title),
                onTap: () => context.go(row.location),
                excludeSemantics: true,
                child: TextButton(
                  onPressed: () => context.go(row.location),
                  child: Text(strings.open),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

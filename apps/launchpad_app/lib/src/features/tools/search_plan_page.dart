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
import '../explore/occupation_widgets.dart';
import 'tool_widgets.dart';

/// A repeatable week of job-search tasks sized to the time a person has.
///
/// The counts divide time. They are not targets drawn from any statistic, and
/// the page says so before it shows one.
class SearchPlanPage extends ConsumerStatefulWidget {
  const SearchPlanPage({super.key});

  @override
  ConsumerState<SearchPlanPage> createState() => _SearchPlanPageState();
}

class _SearchPlanPageState extends ConsumerState<SearchPlanPage> {
  String? _status;
  int _week = 0;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final theme = Theme.of(context);
    final workspace = ref.watch(
      sessionProvider.select((session) => session.workspace),
    );
    final controller = ref.read(sessionProvider.notifier);
    final hours = workspace.searchHours;
    final occupations =
        ref.watch(occupationsProvider).value ?? const <Occupation>[];
    final targets = <String>[
      for (final occupation in occupations)
        if (workspace.isSaved(occupation.id)) occupation.title,
    ];

    return AppPage(
      backLocation: Routes.tools,
      backLabel: strings.toolsTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          PageHeading(strings.searchPlanTitle),
          const SizedBox(height: Spacing.sm),
          Text(strings.searchPlanIntro, style: theme.textTheme.bodyLarge),
          const SizedBox(height: Spacing.lg),
          PageHeading(strings.searchRolesHeading, large: false),
          const SizedBox(height: Spacing.xs),
          if (targets.isEmpty) ...<Widget>[
            Text(strings.searchRolesEmpty, style: theme.textTheme.bodyLarge),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => context.go(Routes.explore),
                child: Text(strings.exploreTitle),
              ),
            ),
          ] else
            BulletList(items: targets),
          const SizedBox(height: Spacing.lg),
          PageHeading(strings.searchHoursQuestion, large: false),
          const SizedBox(height: Spacing.xs),
          for (final option in SearchHours.values)
            Padding(
              padding: const EdgeInsets.only(bottom: Spacing.xs),
              child: OptionTile(
                label: strings.searchHours(option),
                selected: hours == option,
                onPressed: () => controller.setChoice(
                  Workspace.searchHoursKey,
                  option.slug,
                ),
              ),
            ),
          if (hours != null) ...<Widget>[
            const SizedBox(height: Spacing.lg),
            PageHeading(strings.searchThisWeek, large: false),
            Loaded<List<SearchTask>>(
              value: ref.watch(searchWeekProvider(hours)),
              onRetry: () => ref.invalidate(searchWeekProvider(hours)),
              builder: (context, tasks) {
                final done = tasks
                    .where(
                      (task) =>
                          workspace.isDone(Workspace.searchTaskKey(task.id)),
                    )
                    .length;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    StatusLine(
                      message: _status ?? strings.doneCount(done, tasks.length),
                    ),
                    for (final task in tasks)
                      Padding(
                        padding: const EdgeInsets.only(bottom: Spacing.xs),
                        child: OptionTile(
                          label: strings.searchTaskTitle(
                            task.title,
                            task.count,
                          ),
                          description: task.detail,
                          multiSelect: true,
                          selected: workspace.isDone(
                            Workspace.searchTaskKey(task.id),
                          ),
                          onPressed: () {
                            controller.toggleDone(
                              Workspace.searchTaskKey(task.id),
                            );
                            setState(() => _status = null);
                          },
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: Spacing.sm),
            // Keyed by week so the field empties when a week is finished.
            NoteField(
              key: ValueKey<int>(_week),
              noteKey: Workspace.searchNoteKey,
              label: strings.searchNoteLabel,
            ),
            Text(strings.notesStorageNote, style: theme.textTheme.bodyMedium),
            const SizedBox(height: Spacing.sm),
            FilledButton.tonal(
              onPressed: () {
                controller.closeSearchWeek();
                setState(() {
                  _week++;
                  _status = strings.searchWeekClosed;
                });
              },
              child: Text(strings.searchCloseWeek),
            ),
            const SizedBox(height: Spacing.xs),
            Text(
              strings.searchWeeks(workspace.searchWeeksCompleted),
              style: theme.textTheme.bodyMedium,
            ),
          ],
          const GuidanceFooter(),
        ],
      ),
    );
  }
}

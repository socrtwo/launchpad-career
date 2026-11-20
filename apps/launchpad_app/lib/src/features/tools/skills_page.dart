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

/// A person's own estimate of where they are with the skills an occupation
/// commonly asks for, and what to work on first.
///
/// It is a self-assessment and stays one: nothing is scored, nothing is
/// compared with other people, and the page says nobody else sees it.
class SkillsPage extends ConsumerWidget {
  const SkillsPage({super.key, this.occupationId});

  final String? occupationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppStrings.of(context);
    final theme = Theme.of(context);
    final workspace = ref.watch(
      sessionProvider.select((session) => session.workspace),
    );

    return AppPage(
      backLocation: Routes.tools,
      backLabel: strings.toolsTitle,
      child: OccupationsLoader(
        builder: (context, all) {
          final occupation =
              all.where((item) => item.id == occupationId).firstOrNull;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              PageHeading(strings.skillsTitle),
              const SizedBox(height: Spacing.sm),
              Text(strings.skillsIntro, style: theme.textTheme.bodyLarge),
              const SizedBox(height: Spacing.lg),
              if (occupation == null) ...<Widget>[
                PageHeading(strings.skillsChooseOccupation, large: false),
                const SizedBox(height: Spacing.xs),
                // Saved options first: they are the likeliest targets.
                for (final item in <Occupation>[
                  ...all.where((item) => workspace.isSaved(item.id)),
                  ...all.where((item) => !workspace.isSaved(item.id)),
                ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: Spacing.xs),
                    child: OptionTile(
                      label: item.title,
                      selected: false,
                      onPressed: () => context.go(Routes.skillsFor(item.id)),
                    ),
                  ),
              ] else
                _Ratings(occupation: occupation),
              const GuidanceFooter(),
            ],
          );
        },
      ),
    );
  }
}

class _Ratings extends ConsumerWidget {
  const _Ratings({required this.occupation});

  final Occupation occupation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppStrings.of(context);
    final theme = Theme.of(context);
    final workspace = ref.watch(
      sessionProvider.select((session) => session.workspace),
    );
    final controller = ref.read(sessionProvider.notifier);
    final levels = <SkillLevel?>[
      for (var i = 0; i < occupation.skills.length; i++)
        workspace.skillLevel(occupation.id, i),
    ];
    final rated = levels.whereType<SkillLevel>().length;
    final focus = <String>[
      for (final level in <SkillLevel>[SkillLevel.building, SkillLevel.notYet])
        for (var i = 0; i < occupation.skills.length; i++)
          if (levels[i] == level) occupation.skills[i],
    ].take(2).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        PageHeading(strings.skillsFor(occupation.title), large: false),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => context.go(Routes.skills),
            child: Text(strings.skillsChange),
          ),
        ),
        StatusLine(
          message: strings.skillsRated(rated, occupation.skills.length),
        ),
        for (final (index, skill) in occupation.skills.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: Spacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(skill, style: theme.textTheme.titleMedium),
                const SizedBox(height: Spacing.xxs),
                Wrap(
                  spacing: Spacing.xs,
                  runSpacing: Spacing.xxs,
                  children: <Widget>[
                    for (final level in SkillLevel.values)
                      Semantics(
                        container: true,
                        button: true,
                        inMutuallyExclusiveGroup: true,
                        checked: levels[index] == level,
                        label: strings.skillLevelFor(level, skill),
                        onTap: () => controller.setChoice(
                          Workspace.skillKey(occupation.id, index),
                          levels[index] == level ? null : level.slug,
                        ),
                        excludeSemantics: true,
                        child: ChoiceChip(
                          label: Text(strings.skillLevel(level)),
                          selected: levels[index] == level,
                          onSelected: (_) => controller.setChoice(
                            Workspace.skillKey(occupation.id, index),
                            levels[index] == level ? null : level.slug,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        const SizedBox(height: Spacing.sm),
        PageHeading(strings.skillsFocusHeading, large: false),
        const SizedBox(height: Spacing.xs),
        if (rated == 0)
          Text(strings.skillsFocusNone, style: theme.textTheme.bodyLarge)
        else if (focus.isEmpty)
          Text(strings.skillsFocusAll, style: theme.textTheme.bodyLarge)
        else ...<Widget>[
          BulletList(items: focus.map(strings.skillsFocusLine).toList()),
          const SizedBox(height: Spacing.sm),
          NoteField(
            noteKey: Workspace.skillProjectKey(occupation.id),
            label: strings.skillsProjectLabel,
          ),
          Text(strings.notesStorageNote, style: theme.textTheme.bodyMedium),
        ],
      ],
    );
  }
}

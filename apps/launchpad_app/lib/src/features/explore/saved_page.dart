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
import 'occupation_widgets.dart';

/// The occupations a person saved, and the plans attached to them.
class SavedPage extends ConsumerStatefulWidget {
  const SavedPage({super.key});

  @override
  ConsumerState<SavedPage> createState() => _SavedPageState();
}

class _SavedPageState extends ConsumerState<SavedPage> {
  String? _status;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final theme = Theme.of(context);
    final workspace = ref.watch(
      sessionProvider.select((session) => session.workspace),
    );

    return AppPage(
      maxWidth: Breakpoints.maxContentWidth,
      child: OccupationsLoader(
        builder: (context, all) {
          final saved = <Occupation>[
            for (final occupation in all)
              if (workspace.isSaved(occupation.id)) occupation,
          ];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              PageHeading(strings.savedTitle),
              const SizedBox(height: Spacing.sm),
              if (saved.isEmpty) ...<Widget>[
                Text(strings.savedEmpty, style: theme.textTheme.bodyLarge),
                const SizedBox(height: Spacing.md),
                FilledButton(
                  onPressed: () => context.go(Routes.explore),
                  child: Text(strings.exploreTitle),
                ),
              ] else ...<Widget>[
                Wrap(
                  spacing: Spacing.sm,
                  runSpacing: Spacing.xs,
                  children: <Widget>[
                    if (saved.length >= 2)
                      FilledButton.tonal(
                        onPressed: () => context.go(
                          Routes.compare(
                            saved
                                .take(Workspace.maxCompared)
                                .map((item) => item.id)
                                .toList(),
                          ),
                        ),
                        child: Text(strings.compareSaved),
                      ),
                    OutlinedButton(
                      onPressed: () => context.go(Routes.explore),
                      child: Text(strings.exploreTitle),
                    ),
                  ],
                ),
                StatusLine(message: _status),
                for (final occupation in saved)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Spacing.sm),
                    child: OccupationCard(
                      occupation: occupation,
                      onChanged: (message) => setState(() => _status = message),
                      footer: _PlanSummary(occupation: occupation),
                    ),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _PlanSummary extends ConsumerWidget {
  const _PlanSummary({required this.occupation});

  final Occupation occupation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppStrings.of(context);
    final workspace = ref.watch(
      sessionProvider.select((session) => session.workspace),
    );
    final plan = workspace.plans[occupation.id];
    final route = plan?.route;
    if (plan == null || route == null) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
          onPressed: () => context.go(Routes.plan(occupation.id)),
          child: Text(strings.startPlan),
        ),
      );
    }
    final prefix = 'plan/${occupation.id}/';
    final done = workspace.completed
        .where(
          (key) =>
              key.startsWith('$prefix${route.slug}/') ||
              key.startsWith('${prefix}custom/'),
        )
        .length;
    final template =
        ref.watch(planStepsProvider((occupation.id, route))).value ??
            const <PlanStep>[];
    final total = template.length + plan.customSteps.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        FactLabel(
          icon: Icons.checklist,
          text: strings.planSummary(done, total),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => context.go(Routes.plan(occupation.id)),
            child: Text(strings.openPlan),
          ),
        ),
      ],
    );
  }
}

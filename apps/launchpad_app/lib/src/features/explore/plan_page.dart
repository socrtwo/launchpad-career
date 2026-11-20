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

/// A checklist towards one occupation by one route.
///
/// The steps are things to find out and do. Ticking them commits a person to
/// nothing, and no step or summary on this page says what the result will be.
class PlanPage extends ConsumerStatefulWidget {
  const PlanPage({super.key, required this.occupationId});

  final String? occupationId;

  @override
  ConsumerState<PlanPage> createState() => _PlanPageState();
}

class _PlanPageState extends ConsumerState<PlanPage> {
  final TextEditingController _step = TextEditingController();
  String? _status;

  @override
  void dispose() {
    _step.dispose();
    super.dispose();
  }

  void _add(String occupationId) {
    final strings = AppStrings.of(context);
    final controller = ref.read(sessionProvider.notifier);
    final plan = ref.read(sessionProvider).workspace.plans[occupationId];
    if (plan != null && plan.customSteps.length >= ActionPlan.maxCustomSteps) {
      setState(() => _status = strings.planFull);
      return;
    }
    if (controller.addCustomStep(occupationId, _step.text)) {
      _step.clear();
      setState(() => _status = strings.planAddedStatus);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final theme = Theme.of(context);
    final id = widget.occupationId;

    return AppPage(
      backLocation: id == null ? Routes.explore : Routes.occupation(id),
      backLabel: strings.backToOccupations,
      child: OccupationsLoader(
        builder: (context, all) {
          final occupation = all.where((item) => item.id == id).firstOrNull;
          if (occupation == null) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  strings.unknownOccupation,
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: Spacing.md),
                FilledButton(
                  onPressed: () => context.go(Routes.explore),
                  child: Text(strings.exploreTitle),
                ),
              ],
            );
          }

          final workspace = ref.watch(
            sessionProvider.select((session) => session.workspace),
          );
          final controller = ref.read(sessionProvider.notifier);
          final plan = workspace.plans[occupation.id];
          final route = plan?.route;
          final steps = route == null
              ? const <PlanStep>[]
              : ref.watch(planStepsProvider((occupation.id, route))).value ??
                  const <PlanStep>[];
          final custom = plan?.customSteps ?? const <CustomStep>[];
          final keys = <String>[
            if (route != null)
              for (final step in steps)
                Workspace.planStepKey(occupation.id, route, step.id),
            for (final step in custom)
              Workspace.customStepKey(occupation.id, step.id),
          ];
          final done = keys.where(workspace.isDone).length;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              PageHeading(strings.planTitle(occupation.title)),
              const SizedBox(height: Spacing.sm),
              Text(strings.planIntro, style: theme.textTheme.bodyLarge),
              const SizedBox(height: Spacing.lg),
              PageHeading(strings.planChooseRoute, large: false),
              const SizedBox(height: Spacing.xs),
              for (final option in occupation.routes)
                Padding(
                  padding: const EdgeInsets.only(bottom: Spacing.xs),
                  child: OptionTile(
                    label:
                        '${option.title} (${strings.routeKind(option.kind)})',
                    description: option.description,
                    selected: route == option.kind,
                    onPressed: () =>
                        controller.setPlanRoute(occupation.id, option.kind),
                  ),
                ),
              if (route != null) ...<Widget>[
                const SizedBox(height: Spacing.lg),
                PageHeading(strings.planStepsHeading, large: false),
                StatusLine(
                  message: _status ?? strings.planProgress(done, keys.length),
                ),
                for (final step in steps)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Spacing.xs),
                    child: OptionTile(
                      label: step.title,
                      description: step.detail,
                      multiSelect: true,
                      selected: workspace.isDone(
                        Workspace.planStepKey(occupation.id, route, step.id),
                      ),
                      onPressed: () {
                        controller.toggleDone(
                          Workspace.planStepKey(occupation.id, route, step.id),
                        );
                        setState(() => _status = null);
                      },
                    ),
                  ),
                if (custom.isNotEmpty) ...<Widget>[
                  const SizedBox(height: Spacing.md),
                  PageHeading(strings.planYourSteps, large: false),
                  const SizedBox(height: Spacing.xs),
                ],
                for (final step in custom)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Spacing.xs),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: OptionTile(
                            label: step.text,
                            multiSelect: true,
                            selected: workspace.isDone(
                              Workspace.customStepKey(occupation.id, step.id),
                            ),
                            onPressed: () {
                              controller.toggleDone(
                                Workspace.customStepKey(
                                  occupation.id,
                                  step.id,
                                ),
                              );
                              setState(() => _status = null);
                            },
                          ),
                        ),
                        IconButton(
                          onPressed: () => controller.removeCustomStep(
                            occupation.id,
                            step.id,
                          ),
                          icon: const Icon(Icons.close),
                          tooltip: strings.removeStep(step.text),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: Spacing.lg),
                PageHeading(strings.planAddHeading, large: false),
                const SizedBox(height: Spacing.xs),
                TextField(
                  controller: _step,
                  maxLength: CustomStep.maxLength,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _add(occupation.id),
                  decoration: InputDecoration(labelText: strings.planAddLabel),
                ),
                Text(
                  strings.planStorageNote,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: Spacing.sm),
                Wrap(
                  spacing: Spacing.sm,
                  runSpacing: Spacing.xs,
                  children: <Widget>[
                    FilledButton.tonal(
                      onPressed: () => _add(occupation.id),
                      child: Text(strings.planAdd),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        controller.removePlan(occupation.id);
                        setState(() => _status = null);
                      },
                      icon: const Icon(Icons.delete_outline),
                      label: Text(strings.planRemove),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: Spacing.lg),
              const Divider(),
              const SizedBox(height: Spacing.sm),
              OccupationProvenance(occupation: occupation),
              const SizedBox(height: Spacing.xs),
              Text(strings.noGuarantee, style: theme.textTheme.bodyMedium),
              const SizedBox(height: Spacing.lg),
              OutlinedButton.icon(
                onPressed: () => context.go(Routes.occupation(occupation.id)),
                icon: const Icon(Icons.arrow_back),
                label: Text(occupation.title),
              ),
            ],
          );
        },
      ),
    );
  }
}

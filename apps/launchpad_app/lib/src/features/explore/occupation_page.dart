import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:launchpad_core/launchpad_core.dart';
import 'package:launchpad_ui/launchpad_ui.dart';

import '../../app/app_page.dart';
import '../../app/providers.dart';
import '../../l10n/app_strings.dart';
import '../../routing/app_router.dart';
import 'occupation_widgets.dart';

/// Everything known about one occupation, addressed by slug so a shared or
/// refreshed link works.
class OccupationPage extends ConsumerStatefulWidget {
  const OccupationPage({super.key, required this.occupationId});

  final String? occupationId;

  @override
  ConsumerState<OccupationPage> createState() => _OccupationPageState();
}

class _OccupationPageState extends ConsumerState<OccupationPage> {
  String? _status;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final theme = Theme.of(context);

    return AppPage(
      backLocation: Routes.explore,
      backLabel: strings.backToOccupations,
      child: OccupationsLoader(
        builder: (context, all) {
          final occupation =
              all.where((item) => item.id == widget.occupationId).firstOrNull;
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
          final hasPlan = ref.watch(
            sessionProvider.select(
              (session) => session.workspace.plans.containsKey(occupation.id),
            ),
          );

          Widget section(String heading, Widget body) => Padding(
                padding: const EdgeInsets.only(top: Spacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    PageHeading(heading, large: false),
                    const SizedBox(height: Spacing.xs),
                    body,
                  ],
                ),
              );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              PageHeading(occupation.title),
              const SizedBox(height: Spacing.sm),
              Text(occupation.summary, style: theme.textTheme.bodyLarge),
              const SizedBox(height: Spacing.md),
              Wrap(
                spacing: Spacing.sm,
                runSpacing: Spacing.xs,
                children: <Widget>[
                  SaveButton(
                    occupation: occupation,
                    onChanged: (message) => setState(() => _status = message),
                  ),
                  FilledButton.tonal(
                    onPressed: () => context.go(Routes.plan(occupation.id)),
                    child: Text(hasPlan ? strings.openPlan : strings.startPlan),
                  ),
                  OutlinedButton(
                    onPressed: () => context.go(
                      Routes.compare(<String>[occupation.id]),
                    ),
                    child: Text(strings.compareWithOthers),
                  ),
                ],
              ),
              StatusLine(message: _status),
              section(
                strings.workInvolvesHeading,
                BulletList(items: occupation.tasks),
              ),
              section(
                strings.routesHeading,
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      strings.routesIntro,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: Spacing.sm),
                    RouteList(occupation: occupation),
                  ],
                ),
              ),
              section(
                strings.skillsHeading,
                BulletList(items: occupation.skills),
              ),
              section(strings.payHeading, PayBlock(occupation: occupation)),
              if (occupation.changeNote != null)
                section(
                  strings.changeHeading,
                  Text(
                    occupation.changeNote!,
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
              const SizedBox(height: Spacing.lg),
              const Divider(),
              const SizedBox(height: Spacing.sm),
              OccupationProvenance(occupation: occupation),
              const SizedBox(height: Spacing.xs),
              Text(
                strings.occupationCodeLine(
                  occupation.socCode,
                  occupation.socTitle,
                ),
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: Spacing.xs),
              Text(strings.noGuarantee, style: theme.textTheme.bodyMedium),
              const SizedBox(height: Spacing.lg),
              OutlinedButton.icon(
                onPressed: () => context.go(Routes.explore),
                icon: const Icon(Icons.arrow_back),
                label: Text(strings.backToOccupations),
              ),
            ],
          );
        },
      ),
    );
  }
}

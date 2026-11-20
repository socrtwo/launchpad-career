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

/// Two or three occupations, the same facts about each in the same order.
///
/// The selection lives in the URL (`/compare?ids=a,b`), so a comparison can be
/// refreshed, bookmarked and shared. Columns follow the window size class:
/// side by side where there is room, stacked under each row heading on a
/// phone, where each cell repeats the occupation name so it still reads as a
/// comparison.
class ComparePage extends ConsumerStatefulWidget {
  const ComparePage({super.key, required this.ids});

  final List<String> ids;

  @override
  ConsumerState<ComparePage> createState() => _ComparePageState();
}

class _ComparePageState extends ConsumerState<ComparePage> {
  String? _status;
  late bool _choosing = widget.ids.length < 2;

  void _toggle(String id) {
    final strings = AppStrings.of(context);
    final next = <String>[...widget.ids];
    if (next.remove(id)) {
      setState(() => _status = strings.compareSelected(next.length));
    } else if (next.length >= Workspace.maxCompared) {
      setState(() => _status = strings.compareLimit);
      return;
    } else {
      next.add(id);
      setState(() => _status = strings.compareSelected(next.length));
    }
    context.go(Routes.compare(next));
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final theme = Theme.of(context);
    final workspace = ref.watch(
      sessionProvider.select((session) => session.workspace),
    );
    final snapshot = ref.watch(laborMarketProvider).value;

    return AppPage(
      maxWidth: Breakpoints.maxContentWidth,
      backLocation: Routes.explore,
      backLabel: strings.backToOccupations,
      child: OccupationsLoader(
        builder: (context, all) {
          final chosen = <Occupation>[
            for (final id in widget.ids) ...all.where((item) => item.id == id),
          ];
          // Saved options first: they are the likeliest to be compared.
          final choices = <Occupation>[
            ...all.where((item) => workspace.isSaved(item.id)),
            ...all.where((item) => !workspace.isSaved(item.id)),
          ];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              PageHeading(strings.compareTitle),
              const SizedBox(height: Spacing.sm),
              Text(strings.compareIntro, style: theme.textTheme.bodyLarge),
              const SizedBox(height: Spacing.sm),
              OutlinedButton.icon(
                onPressed: () => setState(() => _choosing = !_choosing),
                icon: Icon(_choosing ? Icons.expand_less : Icons.expand_more),
                label: Text(strings.compareChoose),
              ),
              StatusLine(message: _status),
              if (_choosing) ...<Widget>[
                for (final occupation in choices)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Spacing.xs),
                    child: OptionTile(
                      label: occupation.title,
                      selected: widget.ids.contains(occupation.id),
                      multiSelect: true,
                      onPressed: () => _toggle(occupation.id),
                    ),
                  ),
                const SizedBox(height: Spacing.md),
              ],
              if (chosen.length < 2)
                NoticeCard(text: strings.compareNeedMore)
              else
                _Table(occupations: chosen, snapshot: snapshot),
            ],
          );
        },
      ),
    );
  }
}

class _Table extends ConsumerWidget {
  const _Table({required this.occupations, required this.snapshot});

  final List<Occupation> occupations;
  final LaborMarketSnapshot? snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppStrings.of(context);
    final theme = Theme.of(context);
    final stacked = Breakpoints.of(context) == WindowSize.compact;
    final hasPay = snapshot != null && !snapshot!.isEmpty;

    Widget pay(Occupation occupation) {
      final stats = snapshot?.statsBySoc[occupation.socCode];
      final median = stats?.medianAnnualWage;
      return Text(
        median == null
            ? strings.payNotAvailableForOccupation
            : strings.payCompareLine(
                strings.dollars(median),
                snapshot!.referencePeriod,
              ),
        style: theme.textTheme.bodyLarge,
      );
    }

    final rows = <(String, Widget Function(Occupation))>[
      (
        strings.compareSummaryRow,
        (item) => Text(item.summary, style: theme.textTheme.bodyLarge),
      ),
      (strings.workInvolvesHeading, (item) => BulletList(items: item.tasks)),
      (
        strings.routesHeading,
        (item) => BulletList(
              items: <String>[
                for (final route in item.routes)
                  '${route.title} (${strings.routeKind(route.kind)})',
              ],
            ),
      ),
      (strings.skillsHeading, (item) => BulletList(items: item.skills)),
      if (hasPay) (strings.payHeading, pay),
      if (occupations.any((item) => item.changeNote != null))
        (
          strings.changeHeading,
          (item) => Text(
                item.changeNote ?? '—',
                style: theme.textTheme.bodyLarge,
              ),
        ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = Spacing.md;
        final columns = stacked ? 1 : occupations.length;
        final width = columns == 1
            ? constraints.maxWidth
            : (constraints.maxWidth - gap * (columns - 1)) / columns;

        Widget cells(Widget Function(Occupation) cell, {bool header = false}) =>
            Wrap(
              spacing: gap,
              runSpacing: Spacing.sm,
              children: <Widget>[
                for (final occupation in occupations)
                  SizedBox(
                    width: width,
                    child: header
                        ? cell(occupation)
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              // Repeated in every cell so a stacked layout,
                              // and a screen reader, always know whose fact
                              // this is.
                              Text(
                                occupation.title,
                                style: theme.textTheme.bodyMedium,
                              ),
                              const SizedBox(height: Spacing.xxs),
                              cell(occupation),
                            ],
                          ),
                  ),
              ],
            );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            cells(
              header: true,
              (occupation) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Semantics(
                    header: true,
                    child: Text(
                      occupation.title,
                      style: theme.textTheme.headlineSmall,
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Semantics(
                      container: true,
                      button: true,
                      label: strings.viewOccupation(occupation.title),
                      onTap: () => context.go(Routes.occupation(occupation.id)),
                      excludeSemantics: true,
                      child: TextButton(
                        onPressed: () =>
                            context.go(Routes.occupation(occupation.id)),
                        child: Text(strings.viewDetails),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            for (final (heading, cell) in rows) ...<Widget>[
              const SizedBox(height: Spacing.md),
              const Divider(),
              const SizedBox(height: Spacing.sm),
              PageHeading(heading, large: false),
              const SizedBox(height: Spacing.xs),
              cells(cell),
            ],
            const SizedBox(height: Spacing.lg),
            if (hasPay) ...<Widget>[
              Text(strings.payCaveat, style: theme.textTheme.bodyMedium),
              const SizedBox(height: Spacing.xs),
              EvidenceNote(
                evidence: snapshot!.statsBySoc.values.first.evidence,
                labels: evidenceLabels(strings),
                now: ref.watch(clockProvider)(),
                period: snapshot!.referencePeriod,
              ),
            ] else
              NoticeCard(text: strings.payNotLoaded, icon: Icons.bar_chart),
            const SizedBox(height: Spacing.sm),
            OccupationProvenance(occupation: occupations.first),
          ],
        );
      },
    );
  }
}

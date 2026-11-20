import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:launchpad_core/launchpad_core.dart';
import 'package:launchpad_domain/launchpad_domain.dart';
import 'package:launchpad_ui/launchpad_ui.dart';

import '../../app/providers.dart';
import '../../l10n/app_strings.dart';
import '../../routing/app_router.dart';

/// The evidence wording, taken from the string table.
EvidenceLabels evidenceLabels(AppStrings strings) => EvidenceLabels(
      laborMarketData: strings.sourceLine,
      editorial: strings.editorialLine,
      generatedGuidance: strings.generatedLine,
      userProvided: strings.userProvidedLine,
      stale: strings.staleLine,
    );

/// Says where an occupation's description came from.
class OccupationProvenance extends ConsumerWidget {
  const OccupationProvenance({super.key, required this.occupation});

  final Occupation occupation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppStrings.of(context);
    final asOf = occupation.evidence.asOf;
    return EvidenceNote(
      evidence: occupation.evidence,
      labels: evidenceLabels(strings),
      now: ref.watch(clockProvider)(),
      dateText: asOf == null ? null : strings.monthYear(asOf),
    );
  }
}

/// A small icon-and-text label. The icon is decoration; the words carry it.
class FactLabel extends StatelessWidget {
  const FactLabel({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ExcludeSemantics(
          child: Icon(
            icon,
            size: 18,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: Spacing.xs),
        Flexible(child: Text(text, style: theme.textTheme.bodyMedium)),
      ],
    );
  }
}

/// Saves or removes an occupation, and announces which happened.
class SaveButton extends ConsumerWidget {
  const SaveButton({super.key, required this.occupation, this.onChanged});

  final Occupation occupation;

  /// Called with a sentence describing what just happened, for a live region.
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppStrings.of(context);
    final saved = ref.watch(
      sessionProvider.select(
        (session) => session.workspace.isSaved(occupation.id),
      ),
    );
    void toggle() {
      ref.read(sessionProvider.notifier).toggleSaved(occupation.id);
      onChanged?.call(
        saved
            ? strings.removedStatus(occupation.title)
            : strings.savedStatus(occupation.title),
      );
    }

    return Semantics(
      container: true,
      button: true,
      toggled: saved,
      label: saved
          ? strings.removeSaved(occupation.title)
          : strings.saveOccupation(occupation.title),
      onTap: toggle,
      excludeSemantics: true,
      child: OutlinedButton.icon(
        onPressed: toggle,
        icon: Icon(saved ? Icons.bookmark : Icons.bookmark_border),
        label: Text(saved ? strings.saved : strings.save),
      ),
    );
  }
}

/// An occupation in a list: what it is, what stands out about the ways in,
/// and the two things a person can do with it.
class OccupationCard extends StatelessWidget {
  const OccupationCard({
    super.key,
    required this.occupation,
    this.onChanged,
    this.footer,
  });

  final Occupation occupation;
  final ValueChanged<String>? onChanged;

  /// Extra content under the summary, such as the reasons for a suggestion.
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Semantics(
            header: true,
            child: Text(occupation.title, style: theme.textTheme.titleMedium),
          ),
          const SizedBox(height: Spacing.xxs),
          Text(occupation.summary, style: theme.textTheme.bodyLarge),
          if (occupation.hasNonDegreeRoute) ...<Widget>[
            const SizedBox(height: Spacing.xs),
            FactLabel(icon: Icons.alt_route, text: strings.nonDegreeLabel),
          ],
          if (occupation.hasPaidTrainingRoute) ...<Widget>[
            const SizedBox(height: Spacing.xxs),
            FactLabel(
              icon: Icons.payments_outlined,
              text: strings.paidTrainingLabel,
            ),
          ],
          if (footer != null) ...<Widget>[
            const SizedBox(height: Spacing.sm),
            footer!,
          ],
          const SizedBox(height: Spacing.sm),
          Wrap(
            spacing: Spacing.sm,
            runSpacing: Spacing.xs,
            children: <Widget>[
              Semantics(
                container: true,
                button: true,
                label: strings.viewOccupation(occupation.title),
                onTap: () => context.go(Routes.occupation(occupation.id)),
                excludeSemantics: true,
                child: FilledButton.tonal(
                  onPressed: () => context.go(Routes.occupation(occupation.id)),
                  child: Text(strings.viewDetails),
                ),
              ),
              SaveButton(occupation: occupation, onChanged: onChanged),
            ],
          ),
        ],
      ),
    );
  }
}

/// Published pay figures for one occupation, each with its source and period,
/// or a plain statement that none are loaded.
class PayBlock extends ConsumerWidget {
  const PayBlock({super.key, required this.occupation});

  final Occupation occupation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppStrings.of(context);
    final theme = Theme.of(context);
    final snapshot = ref.watch(laborMarketProvider).value;

    if (snapshot == null || snapshot.isEmpty) {
      return NoticeCard(text: strings.payNotLoaded, icon: Icons.bar_chart);
    }
    final stats = snapshot.statsBySoc[occupation.socCode];
    if (stats == null) {
      return Text(
        strings.payNotAvailableForOccupation,
        style: theme.textTheme.bodyLarge,
      );
    }

    final period = snapshot.referencePeriod;
    final median = stats.medianAnnualWage;
    final low = stats.lowAnnualWage;
    final high = stats.highAnnualWage;
    final employment = stats.employment;
    final lines = <String>[
      if (median != null)
        strings.payMedian(strings.dollars(median), period)
      else if (stats.medianIsTopCoded)
        strings.payMedianTopCoded(period)
      else
        strings.payNotAvailableForOccupation,
      if (low != null && high != null)
        strings.paySpread(strings.dollars(low), strings.dollars(high)),
      if (stats.hasWideSpread) strings.payWideSpread,
      if (employment != null)
        strings.payEmployment(strings.wholeNumber(employment), period),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final line in lines) ...<Widget>[
          Text(line, style: theme.textTheme.bodyLarge),
          const SizedBox(height: Spacing.xs),
        ],
        Text(strings.payCaveat, style: theme.textTheme.bodyMedium),
        const SizedBox(height: Spacing.xs),
        EvidenceNote(
          evidence: stats.evidence,
          labels: evidenceLabels(strings),
          now: ref.watch(clockProvider)(),
          period: period,
        ),
      ],
    );
  }
}

/// The ways into an occupation, each labelled with the kind of route it is.
class RouteList extends StatelessWidget {
  const RouteList({super.key, required this.occupation});

  final Occupation occupation;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final route in occupation.routes)
          Padding(
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
                  Text(
                    strings.routeKind(route.kind),
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: Spacing.xxs),
                  Text(route.title, style: theme.textTheme.titleMedium),
                  const SizedBox(height: Spacing.xxs),
                  Text(route.description, style: theme.textTheme.bodyLarge),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// A plain bulleted list. Bullets are decoration; each item is its own line
/// in the semantics tree.
class BulletList extends StatelessWidget {
  const BulletList({super.key, required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: Spacing.xxs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                ExcludeSemantics(
                  child: Text('•  ', style: theme.textTheme.bodyLarge),
                ),
                Expanded(child: Text(item, style: theme.textTheme.bodyLarge)),
              ],
            ),
          ),
      ],
    );
  }
}

/// Loads the catalogue and hands it to [builder], with the shared loading and
/// error states.
class OccupationsLoader extends ConsumerWidget {
  const OccupationsLoader({super.key, required this.builder});

  final Widget Function(BuildContext context, List<Occupation> occupations)
      builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppStrings.of(context);
    return ref.watch(occupationsProvider).when(
          loading: () => Semantics(
            liveRegion: true,
            label: strings.loading,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: Spacing.xl),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
          error: (error, stack) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                strings.occupationsUnavailable,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: Spacing.sm),
              OutlinedButton(
                onPressed: () => ref.invalidate(occupationsProvider),
                child: Text(strings.retry),
              ),
            ],
          ),
          data: (occupations) => builder(context, occupations),
        );
  }
}

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

/// Occupations matched to a person's answers, each with its reasons.
///
/// The principles this page is built against
/// (`docs/product/career-recommendation-principles.md`): every suggestion
/// says why it is there in terms of what the person told us; confidence is in
/// words; more than one path is offered; the answers behind it are one press
/// away from being changed; and nothing reads as a prediction.
class SuggestionsPage extends ConsumerStatefulWidget {
  const SuggestionsPage({super.key});

  @override
  ConsumerState<SuggestionsPage> createState() => _SuggestionsPageState();
}

class _SuggestionsPageState extends ConsumerState<SuggestionsPage> {
  String? _status;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final theme = Theme.of(context);
    final profile = ref.watch(
      sessionProvider.select((session) => session.profile),
    );
    final snapshot = ref.watch(laborMarketProvider).value;

    return AppPage(
      maxWidth: Breakpoints.maxContentWidth,
      child: OccupationsLoader(
        builder: (context, all) {
          final result = Recommender.recommend(
            profile: profile,
            occupations: all,
            laborMarket: snapshot,
          );
          final needsInterests =
              result.notes.contains(RecommendationNote.needsInterests);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              PageHeading(strings.suggestionsTitle),
              const SizedBox(height: Spacing.sm),
              if (needsInterests) ...<Widget>[
                Text(
                  strings.suggestionsNeedInterests,
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: Spacing.md),
                Wrap(
                  spacing: Spacing.sm,
                  runSpacing: Spacing.xs,
                  children: <Widget>[
                    FilledButton(
                      onPressed: () => context.go(
                        Routes.onboarding(OnboardingStep.interests),
                      ),
                      child: Text(strings.answerInterests),
                    ),
                    OutlinedButton(
                      onPressed: () => context.go(Routes.explore),
                      child: Text(strings.browseAll),
                    ),
                  ],
                ),
              ] else ...<Widget>[
                Text(
                  strings.suggestionsIntro,
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: Spacing.sm),
                Wrap(
                  spacing: Spacing.sm,
                  runSpacing: Spacing.xs,
                  children: <Widget>[
                    OutlinedButton(
                      onPressed: () => context.go(
                        Routes.onboarding(OnboardingStep.review),
                      ),
                      child: Text(strings.changeAnswers),
                    ),
                    OutlinedButton(
                      onPressed: () => context.go(Routes.explore),
                      child: Text(strings.browseAll),
                    ),
                  ],
                ),
                StatusLine(message: _status),
                if (result.items.isEmpty)
                  Text(
                    strings.suggestionsNoMatches,
                    style: theme.textTheme.bodyLarge,
                  ),
                for (final item in result.items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Spacing.sm),
                    child: OccupationCard(
                      occupation: item.occupation,
                      onChanged: (message) => setState(() => _status = message),
                      footer: _Reasons(item: item, snapshot: snapshot),
                    ),
                  ),
                const SizedBox(height: Spacing.sm),
                for (final note in _notes(strings, result)) ...<Widget>[
                  NoticeCard(text: note),
                  const SizedBox(height: Spacing.xs),
                ],
                if (result.items.isNotEmpty) ...<Widget>[
                  const SizedBox(height: Spacing.xs),
                  OccupationProvenance(
                    occupation: result.items.first.occupation,
                  ),
                  const SizedBox(height: Spacing.xs),
                  Text(strings.noGuarantee, style: theme.textTheme.bodyMedium),
                ],
              ],
            ],
          );
        },
      ),
    );
  }

  static List<String> _notes(AppStrings strings, RecommendationSet result) {
    final unsupported = result.unusedPriorities
        .where((priority) => priority != Priority.earnings)
        .map(strings.priority)
        .toList();
    return <String>[
      if (result.notes.contains(RecommendationNote.fewAnswers))
        strings.noteFewAnswers,
      if (result.notes.contains(RecommendationNote.includedNonDegreeRoute))
        strings.noteNonDegree,
      if (result.notes.contains(RecommendationNote.payNotAvailable))
        strings.notePayUnavailable,
      if (unsupported.isNotEmpty) strings.noteUnused(unsupported.join(', ')),
    ];
  }
}

class _Reasons extends StatelessWidget {
  const _Reasons({required this.item, required this.snapshot});

  final Recommendation item;
  final LaborMarketSnapshot? snapshot;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final theme = Theme.of(context);
    final route = item.suggestedRoute;

    String word(RecommendationReason reason) => switch (reason) {
          InterestReason(:final interest) => strings.reasonInterest(interest),
          RouteOpenNowReason(:final route, :final level) =>
            strings.reasonOpenNow(level, route.title),
          RouteOpenWithPlanReason(:final route, :final plan) =>
            strings.reasonOpenWithPlan(plan, route.title),
          PriorityReason(:final priority, :final stats)
              when priority == Priority.earnings &&
                  stats?.medianAnnualWage != null &&
                  snapshot?.allOccupationsMedianAnnualWage != null =>
            '${strings.reasonEarnings(
              strings.dollars(stats!.medianAnnualWage!),
              snapshot!.referencePeriod,
              strings.dollars(snapshot!.allOccupationsMedianAnnualWage!),
            )} ${strings.sourceLine(snapshot!.source, null)}',
          PriorityReason(:final priority, :final route) =>
            strings.reasonPriority(priority, route: route?.title),
        };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        FactLabel(
          icon: Icons.tune,
          text: strings.confidence(item.confidence),
        ),
        const SizedBox(height: Spacing.xs),
        Text(strings.whyHeading, style: theme.textTheme.titleMedium),
        const SizedBox(height: Spacing.xxs),
        BulletList(items: item.reasons.map(word).toList()),
        if (route != null) ...<Widget>[
          const SizedBox(height: Spacing.xxs),
          FactLabel(
            icon: Icons.alt_route,
            text: strings.suggestedRoute(
              '${route.title} (${strings.routeKind(route.kind)})',
            ),
          ),
        ],
      ],
    );
  }
}

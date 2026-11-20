import 'package:meta/meta.dart';

import '../entities/evidence.dart';
import '../entities/occupation.dart';
import '../entities/profile.dart';

/// Why an occupation was suggested, in terms of what the person told us.
///
/// Reasons are data, not sentences: the interface words them, and each one
/// points back at an answer the person can change.
@immutable
sealed class RecommendationReason {
  const RecommendationReason();
}

/// The occupation involves a kind of work the person said interests them.
class InterestReason extends RecommendationReason {
  const InterestReason(this.interest);
  final InterestArea interest;
}

/// A route in is open with the education the person already has.
class RouteOpenNowReason extends RecommendationReason {
  const RouteOpenNowReason(this.route, this.level);
  final EntryRoute route;
  final EducationLevel level;
}

/// A route in would be open after the study the person is planning.
class RouteOpenWithPlanReason extends RecommendationReason {
  const RouteOpenWithPlanReason(this.route, this.plan);
  final EntryRoute route;
  final PlannedEducation plan;
}

/// The occupation fits a priority the person chose.
class PriorityReason extends RecommendationReason {
  const PriorityReason(this.priority, {this.route, this.stats});
  final Priority priority;

  /// The route that makes the priority fit, where a route is the reason.
  final EntryRoute? route;

  /// The published figures that make the priority fit, where data is the
  /// reason. Shown with their source and date.
  final LaborStats? stats;
}

/// Something the person should know about how the list was put together.
enum RecommendationNote {
  /// Too little was answered to suggest anything.
  needsInterests,

  /// Only one or two things were answered, so the list is a rough start.
  fewAnswers,

  /// A suggestion was added so the list includes a route without a degree.
  includedNonDegreeRoute,

  /// "Higher pay" was chosen but no pay figures are loaded, so it had no effect.
  payNotAvailable,

  /// A chosen priority has no dependable data behind it, so it had no effect.
  priorityNotUsed,
}

@immutable
class Recommendation {
  const Recommendation({
    required this.occupation,
    required this.reasons,
    required this.confidence,
    this.suggestedRoute,
  });

  final Occupation occupation;

  /// Never empty: a suggestion with no visible reasoning is not shown.
  final List<RecommendationReason> reasons;

  /// How well the occupation matches what was answered, in words.
  final ConfidenceBand confidence;

  /// The route that best fits the person's education and plans.
  final EntryRoute? suggestedRoute;
}

@immutable
class RecommendationSet {
  const RecommendationSet({
    this.items = const <Recommendation>[],
    this.notes = const <RecommendationNote>{},
    this.unusedPriorities = const <Priority>{},
  });

  final List<Recommendation> items;
  final Set<RecommendationNote> notes;

  /// Chosen priorities that could not influence the order.
  final Set<Priority> unusedPriorities;
}

/// Matches a person's answers against the occupation catalogue by fixed rules.
///
/// What this deliberately is not: a model, a prediction, or a ranking of what
/// is "best". It reads three things and only three - stated interests,
/// education, and priorities. It takes no name, age, gender, location,
/// institution or any other characteristic, so it cannot condition on one or
/// on a proxy for one. See `docs/product/career-recommendation-principles.md`.
abstract final class Recommender {
  static const int defaultLimit = 5;

  /// Priorities with nothing dependable to match them against.
  static const Set<Priority> _unsupported = <Priority>{
    Priority.stability,
    Priority.advancement,
  };

  static RecommendationSet recommend({
    required Profile profile,
    required List<Occupation> occupations,
    LaborMarketSnapshot? laborMarket,
    int limit = defaultLimit,
  }) {
    if (profile.interests.isEmpty) {
      return const RecommendationSet(
        notes: <RecommendationNote>{RecommendationNote.needsInterests},
      );
    }

    final notes = <RecommendationNote>{};
    final unused = <Priority>{
      ...profile.priorities.where(_unsupported.contains),
    };
    final wantsPay = profile.priorities.contains(Priority.earnings);
    final baseline = laborMarket?.allOccupationsMedianAnnualWage;
    if (wantsPay &&
        (laborMarket == null || laborMarket.isEmpty || baseline == null)) {
      unused.add(Priority.earnings);
      notes.add(RecommendationNote.payNotAvailable);
    }
    if (unused.any(_unsupported.contains)) {
      notes.add(RecommendationNote.priorityNotUsed);
    }
    final answersBesidesName =
        profile.answeredCount - (profile.preferredName == null ? 0 : 1);
    if (answersBesidesName <= 1) {
      notes.add(RecommendationNote.fewAnswers);
    }

    final scored = <_Scored>[];
    for (final occupation in occupations) {
      final candidate = _score(profile, occupation, laborMarket);
      if (candidate != null) scored.add(candidate);
    }
    scored.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      return byScore != 0
          ? byScore
          : a.recommendation.occupation.title
              .compareTo(b.recommendation.occupation.title);
    });

    final chosen = scored.take(limit).toList();

    // Offer more than one kind of path: if nothing in the list has a route
    // without a four-year degree and the catalogue has a match that does, the
    // last place goes to it.
    if (chosen.isNotEmpty &&
        !chosen
            .any((item) => item.recommendation.occupation.hasNonDegreeRoute)) {
      final alternative = scored
          .skip(chosen.length)
          .where((item) => item.recommendation.occupation.hasNonDegreeRoute)
          .firstOrNull;
      if (alternative != null) {
        chosen[chosen.length - 1] = alternative;
        notes.add(RecommendationNote.includedNonDegreeRoute);
      }
    }

    return RecommendationSet(
      items: <Recommendation>[for (final item in chosen) item.recommendation],
      notes: notes,
      unusedPriorities: unused,
    );
  }

  static _Scored? _score(
    Profile profile,
    Occupation occupation,
    LaborMarketSnapshot? laborMarket,
  ) {
    final reasons = <RecommendationReason>[];
    var score = 0;

    final shared = InterestArea.values
        .where(profile.interests.contains)
        .where(occupation.interests.contains)
        .toList();
    if (shared.isEmpty) return null;
    for (final interest in shared) {
      reasons.add(InterestReason(interest));
      score += 3;
    }

    final level = profile.educationLevel;
    final plan = profile.plannedEducation;
    final openNow = level == null ? null : _bestRouteAt(occupation, level);
    final planLevel = plan?.targetLevel;
    final openWithPlan =
        planLevel == null ? null : _bestRouteAt(occupation, planLevel);

    EntryRoute? suggested;
    if (openNow != null && level != null) {
      reasons.add(RouteOpenNowReason(openNow, level));
      suggested = openNow;
      score += 2;
    } else if (openWithPlan != null && plan != null) {
      reasons.add(RouteOpenWithPlanReason(openWithPlan, plan));
      suggested = openWithPlan;
      score += 1;
    }

    for (final priority in Priority.values.where(profile.priorities.contains)) {
      switch (priority) {
        case Priority.shortTraining:
          final route = occupation.routes
              .where((route) => route.kind.isShort)
              .firstOrNull;
          if (route != null) {
            reasons.add(PriorityReason(priority, route: route));
            suggested ??= route;
            score += 1;
          }
        case Priority.lowCost:
          final route = occupation.routes
              .where((route) => route.kind.paidWhileTraining)
              .firstOrNull;
          if (route != null) {
            reasons.add(PriorityReason(priority, route: route));
            suggested ??= route;
            score += 1;
          }
        case Priority.handsOn:
          if (occupation.handsOn) {
            reasons.add(PriorityReason(priority));
            score += 1;
          }
        case Priority.flexibility:
          if (occupation.flexibleArrangementsCommon) {
            reasons.add(PriorityReason(priority));
            score += 1;
          }
        case Priority.helpingPeople:
          if (occupation.helpsPeopleDirectly) {
            reasons.add(PriorityReason(priority));
            score += 1;
          }
        case Priority.earnings:
          final stats = laborMarket?.statsBySoc[occupation.socCode];
          final median = stats?.medianAnnualWage;
          final baseline = laborMarket?.allOccupationsMedianAnnualWage;
          if (stats != null &&
              median != null &&
              baseline != null &&
              median > baseline) {
            reasons.add(PriorityReason(priority, stats: stats));
            score += 1;
          }
        case Priority.stability || Priority.advancement:
          // No dependable data: reported to the person as unused, never
          // quietly guessed at.
          break;
      }
    }

    final confidence = switch ((shared.length, openNow != null)) {
      (>= 2, true) => ConfidenceBand.high,
      (>= 2, false) || (1, true) => ConfidenceBand.moderate,
      _ => ConfidenceBand.low,
    };

    return _Scored(
      score,
      Recommendation(
        occupation: occupation,
        reasons: List<RecommendationReason>.unmodifiable(reasons),
        confidence: confidence,
        suggestedRoute: suggested ?? occupation.routes.firstOrNull,
      ),
    );
  }

  /// The route that sits closest to [level] without needing more than it.
  ///
  /// A route that ends in a credential is open to someone who holds or is
  /// working on a credential at least that high. Apprenticeships, employer
  /// training and self-directed routes ask for no credential and are open to
  /// everyone, but a credentialed route at the person's level is preferred
  /// because it uses what they already have.
  static EntryRoute? _bestRouteAt(Occupation occupation, EducationLevel level) {
    EntryRoute? best;
    var bestRank = -2;
    for (final route in occupation.routes) {
      final needed = route.kind.completionLevel?.rank ?? -1;
      if (needed > level.rank) continue;
      if (needed > bestRank) {
        best = route;
        bestRank = needed;
      }
    }
    return best;
  }
}

class _Scored {
  const _Scored(this.score, this.recommendation);
  final int score;
  final Recommendation recommendation;
}

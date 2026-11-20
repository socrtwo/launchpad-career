import 'package:meta/meta.dart';

import 'evidence.dart';
import 'profile.dart';

/// A way into an occupation.
enum RouteKind {
  bachelorsDegree('bachelors-degree'),
  graduateDegree('graduate-degree'),
  associateDegree('associate-degree'),
  certificate('certificate'),
  apprenticeship('apprenticeship'),
  employerTraining('employer-training'),
  selfDirected('self-directed');

  const RouteKind(this.slug);

  final String slug;

  /// Whether this route needs a four-year or graduate degree.
  bool get requiresDegree =>
      this == RouteKind.bachelorsDegree || this == RouteKind.graduateDegree;

  /// Whether a person is normally paid while on this route.
  bool get paidWhileTraining =>
      this == RouteKind.apprenticeship || this == RouteKind.employerTraining;

  /// Whether this route usually takes about two years or less of training.
  bool get isShort => !requiresDegree;

  /// The education a person has normally finished once this route is done.
  /// Routes that are not formal education return null.
  EducationLevel? get completionLevel => switch (this) {
        RouteKind.bachelorsDegree => EducationLevel.bachelors,
        RouteKind.graduateDegree => EducationLevel.masters,
        RouteKind.associateDegree => EducationLevel.associate,
        RouteKind.certificate => EducationLevel.certificate,
        RouteKind.apprenticeship ||
        RouteKind.employerTraining ||
        RouteKind.selfDirected =>
          null,
      };

  static RouteKind? fromSlug(String? slug) {
    if (slug == null) return null;
    for (final kind in RouteKind.values) {
      if (kind.slug == slug) return kind;
    }
    return null;
  }
}

/// One described way into an occupation.
@immutable
class EntryRoute {
  const EntryRoute({
    required this.kind,
    required this.title,
    required this.description,
  });

  final RouteKind kind;

  /// Short label, e.g. "Registered apprenticeship".
  final String title;

  /// One or two sentences on what the route involves.
  final String description;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EntryRoute &&
          other.kind == kind &&
          other.title == title &&
          other.description == description);

  @override
  int get hashCode => Object.hash(kind, title, description);
}

/// An occupation a person can read about, save, compare and plan towards.
///
/// The text fields are content, not statistics. Anything numeric about pay or
/// employment lives in [LaborStats] and arrives with its own source and date.
@immutable
class Occupation {
  const Occupation({
    required this.id,
    required this.socCode,
    required this.socTitle,
    required this.title,
    required this.summary,
    required this.tasks,
    required this.interests,
    required this.skills,
    required this.routes,
    required this.evidence,
    this.handsOn = false,
    this.flexibleArrangementsCommon = false,
    this.changeNote,
  });

  /// URL- and storage-safe identifier.
  final String id;

  /// 2018 Standard Occupational Classification code, e.g. `15-1252`. This is
  /// the key labour-market figures are joined on.
  final String socCode;

  /// The official SOC title for [socCode], kept verbatim so an importer can
  /// check that the code still means what the catalogue thinks it means.
  final String socTitle;

  /// Plain display title.
  final String title;

  final String summary;

  /// What the work involves day to day.
  final List<String> tasks;

  /// The kinds of work this occupation involves, matched against a person's
  /// stated interests.
  final Set<InterestArea> interests;

  /// Skills commonly asked for, in plain words.
  final List<String> skills;

  /// Ways in. More than one wherever more than one genuinely exists.
  final List<EntryRoute> routes;

  /// Where the text above came from.
  final Evidence evidence;

  /// Whether most of the work is practical and physical rather than desk work.
  final bool handsOn;

  /// Whether flexible hours or remote work are commonly available.
  final bool flexibleArrangementsCommon;

  /// A plain statement of how the field is changing, where it visibly is.
  final String? changeNote;

  bool get hasNonDegreeRoute =>
      routes.any((route) => !route.kind.requiresDegree);

  bool get hasPaidTrainingRoute =>
      routes.any((route) => route.kind.paidWhileTraining);

  bool get helpsPeopleDirectly =>
      interests.contains(InterestArea.caring) ||
      interests.contains(InterestArea.teaching) ||
      interests.contains(InterestArea.advocacy);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Occupation && other.id == id);

  @override
  int get hashCode => id.hashCode;
}

/// Published pay and employment figures for one occupation.
///
/// Figures describe everyone employed in the occupation in the reference
/// period. They are a distribution, not a forecast for any one person.
@immutable
class LaborStats {
  LaborStats({
    required this.socCode,
    required this.evidence,
    this.medianAnnualWage,
    this.lowAnnualWage,
    this.highAnnualWage,
    this.employment,
    this.medianIsTopCoded = false,
  }) : assert(
          evidence.kind == EvidenceKind.laborMarketData,
          'Labour-market figures must carry labour-market evidence.',
        );

  final String socCode;

  /// Annual median wage in whole US dollars.
  final int? medianAnnualWage;

  /// Annual 10th-percentile wage: one worker in ten earned less than this.
  final int? lowAnnualWage;

  /// Annual 90th-percentile wage: one worker in ten earned more than this.
  final int? highAnnualWage;

  /// Number of jobs counted in the occupation.
  final int? employment;

  /// True when the publisher reports the median only as "at least" a ceiling.
  final bool medianIsTopCoded;

  final Evidence evidence;

  /// Whether the top tenth earned at least twice what the bottom tenth did.
  /// When true the median alone hides a lot, and the interface says so.
  bool get hasWideSpread {
    final low = lowAnnualWage;
    final high = highAnnualWage;
    if (low == null || high == null || low <= 0) return false;
    return high >= low * 2;
  }
}

/// A dated set of labour-market figures from one publisher.
@immutable
class LaborMarketSnapshot {
  const LaborMarketSnapshot({
    required this.source,
    required this.sourceUrl,
    required this.referencePeriod,
    required this.asOf,
    required this.retrievedOn,
    required this.statsBySoc,
    this.allOccupationsMedianAnnualWage,
  });

  /// Publisher and programme, e.g. "U.S. Bureau of Labor Statistics,
  /// Occupational Employment and Wage Statistics".
  final String source;

  final String sourceUrl;

  /// The period the figures describe, in the publisher's words, e.g. "May 2024".
  final String referencePeriod;

  /// The date the figures describe, used for staleness.
  final DateTime asOf;

  /// When this copy was taken from the publisher.
  final DateTime retrievedOn;

  final Map<String, LaborStats> statsBySoc;

  /// The median across every occupation, for "above" and "below" comparisons.
  final int? allOccupationsMedianAnnualWage;

  bool get isEmpty => statsBySoc.isEmpty;
}

/// One step in a plan towards an occupation.
@immutable
class PlanStep {
  const PlanStep({required this.id, required this.title, required this.detail});

  /// Stable within a route kind, e.g. `find-programmes`.
  final String id;
  final String title;
  final String detail;
}

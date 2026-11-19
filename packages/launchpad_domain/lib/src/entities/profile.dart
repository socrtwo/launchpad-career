import 'package:meta/meta.dart';

import '../util/equality.dart';

/// The highest level of education a person has finished or is working on.
///
/// Stored and routed by [slug], never by index, for the same reason as
/// `GoalId`: reordering the enum must not repoint saved answers.
enum EducationLevel {
  highSchool('high-school'),
  certificate('certificate'),
  someCollege('some-college'),
  associate('associate'),
  bachelors('bachelors'),
  masters('masters'),
  doctoral('doctoral');

  const EducationLevel(this.slug);

  final String slug;

  /// Position on the ladder of credentials. A certificate and some college
  /// share a rung: neither is a degree and neither contains the other.
  int get rank => switch (this) {
        EducationLevel.highSchool => 0,
        EducationLevel.certificate || EducationLevel.someCollege => 1,
        EducationLevel.associate => 2,
        EducationLevel.bachelors => 3,
        EducationLevel.masters => 4,
        EducationLevel.doctoral => 5,
      };

  static EducationLevel? fromSlug(String? slug) {
    if (slug == null) return null;
    for (final level in EducationLevel.values) {
      if (level.slug == slug) return level;
    }
    return null;
  }
}

/// What further study, if any, a person is planning.
enum PlannedEducation {
  none('no-further-study'),
  certificate('certificate'),
  associate('associate'),
  bachelors('bachelors'),
  masters('masters'),
  doctoral('doctoral'),
  undecided('undecided');

  const PlannedEducation(this.slug);

  final String slug;

  static PlannedEducation? fromSlug(String? slug) {
    if (slug == null) return null;
    for (final plan in PlannedEducation.values) {
      if (plan.slug == slug) return plan;
    }
    return null;
  }

  /// The level this plan would reach, where it names one.
  EducationLevel? get targetLevel => switch (this) {
        PlannedEducation.certificate => EducationLevel.certificate,
        PlannedEducation.associate => EducationLevel.associate,
        PlannedEducation.bachelors => EducationLevel.bachelors,
        PlannedEducation.masters => EducationLevel.masters,
        PlannedEducation.doctoral => EducationLevel.doctoral,
        PlannedEducation.none || PlannedEducation.undecided => null,
      };
}

/// Broad kinds of work a person can say they are drawn to.
///
/// These describe work, not people. They are matched against what an
/// occupation involves day to day; nothing is inferred about the person beyond
/// what they chose.
enum InterestArea {
  technology('technology'),
  data('data'),
  building('building-and-fixing'),
  caring('caring-for-people'),
  teaching('teaching'),
  creative('creative'),
  organising('organising'),
  science('science'),
  outdoors('outdoors'),
  advocacy('advocacy');

  const InterestArea(this.slug);

  final String slug;

  static InterestArea? fromSlug(String? slug) {
    if (slug == null) return null;
    for (final area in InterestArea.values) {
      if (area.slug == slug) return area;
    }
    return null;
  }
}

/// What a person says matters most to them in work right now.
///
/// Priorities reorder suggestions. They never remove an option from view.
enum Priority {
  earnings('earnings'),
  stability('stability'),
  shortTraining('short-training'),
  lowCost('low-cost'),
  flexibility('flexibility'),
  helpingPeople('helping-people'),
  advancement('advancement'),
  handsOn('hands-on');

  const Priority(this.slug);

  final String slug;

  /// The most that can be chosen at once. A ranking of everything is homework,
  /// not a priority.
  static const int maxChoices = 3;

  static Priority? fromSlug(String? slug) {
    if (slug == null) return null;
    for (final priority in Priority.values) {
      if (priority.slug == slug) return priority;
    }
    return null;
  }
}

const Object _unset = Object();

/// What a person has told us about themselves.
///
/// Every field is optional and every field is something the person typed or
/// chose. There are no inferred fields, no identifiers, and no protected
/// characteristics. See `docs/privacy/privacy-design.md`.
@immutable
class Profile {
  const Profile({
    this.preferredName,
    this.educationLevel,
    this.plannedEducation,
    this.interests = const <InterestArea>{},
    this.priorities = const <Priority>{},
  });

  /// Used only to address the person on their own device.
  final String? preferredName;
  final EducationLevel? educationLevel;
  final PlannedEducation? plannedEducation;
  final Set<InterestArea> interests;
  final Set<Priority> priorities;

  static const int maxNameLength = 40;

  bool get isEmpty =>
      preferredName == null &&
      educationLevel == null &&
      plannedEducation == null &&
      interests.isEmpty &&
      priorities.isEmpty;

  /// How many of the five questions have an answer.
  int get answeredCount =>
      (preferredName == null ? 0 : 1) +
      (educationLevel == null ? 0 : 1) +
      (plannedEducation == null ? 0 : 1) +
      (interests.isEmpty ? 0 : 1) +
      (priorities.isEmpty ? 0 : 1);

  /// Pass `null` explicitly to clear a nullable field; omit it to keep it.
  Profile copyWith({
    Object? preferredName = _unset,
    Object? educationLevel = _unset,
    Object? plannedEducation = _unset,
    Set<InterestArea>? interests,
    Set<Priority>? priorities,
  }) {
    return Profile(
      preferredName: identical(preferredName, _unset)
          ? this.preferredName
          : _cleanName(preferredName as String?),
      educationLevel: identical(educationLevel, _unset)
          ? this.educationLevel
          : educationLevel as EducationLevel?,
      plannedEducation: identical(plannedEducation, _unset)
          ? this.plannedEducation
          : plannedEducation as PlannedEducation?,
      interests: interests == null
          ? this.interests
          : Set<InterestArea>.unmodifiable(interests),
      priorities: priorities == null
          ? this.priorities
          : Set<Priority>.unmodifiable(priorities),
    );
  }

  static String? _cleanName(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    return trimmed.length > maxNameLength
        ? trimmed.substring(0, maxNameLength)
        : trimmed;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Profile &&
          other.preferredName == preferredName &&
          other.educationLevel == educationLevel &&
          other.plannedEducation == plannedEducation &&
          setEquals(other.interests, interests) &&
          setEquals(other.priorities, priorities));

  @override
  int get hashCode => Object.hash(
        preferredName,
        educationLevel,
        plannedEducation,
        setHash(interests),
        setHash(priorities),
      );
}

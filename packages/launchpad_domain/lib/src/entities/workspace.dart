import 'package:meta/meta.dart';

import '../util/equality.dart';
import 'occupation.dart';
import 'tools.dart';

/// A step a person wrote for themselves.
@immutable
class CustomStep {
  const CustomStep({required this.id, required this.text});

  final String id;

  /// Free text the person typed. Treated like every other free-text field:
  /// never logged, and stored only after the person has opted in.
  final String text;

  static const int maxLength = 200;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CustomStep && other.id == id && other.text == text);

  @override
  int get hashCode => Object.hash(id, text);
}

/// A person's plan towards one occupation: the route they picked and any
/// steps they added. Which steps are done lives in [Workspace.completed].
@immutable
class ActionPlan {
  const ActionPlan({
    required this.occupationId,
    this.route,
    this.customSteps = const <CustomStep>[],
  });

  final String occupationId;

  /// The route the plan follows, once the person has picked one.
  final RouteKind? route;

  final List<CustomStep> customSteps;

  static const int maxCustomSteps = 12;

  ActionPlan withRoute(RouteKind? route) => ActionPlan(
        occupationId: occupationId,
        route: route,
        customSteps: customSteps,
      );

  ActionPlan withCustomSteps(List<CustomStep> steps) => ActionPlan(
        occupationId: occupationId,
        route: route,
        customSteps: List<CustomStep>.unmodifiable(steps),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ActionPlan &&
          other.occupationId == occupationId &&
          other.route == route &&
          listEquals(other.customSteps, customSteps));

  @override
  int get hashCode =>
      Object.hash(occupationId, route, Object.hashAll(customSteps));
}

/// Everything a person has collected or ticked off while using the tools.
///
/// Completion is one flat set of namespaced identifiers rather than a field
/// per tool, so a new tool does not need a new stored shape. Identifiers are
/// built by the static helpers below and nowhere else.
@immutable
class Workspace {
  const Workspace({
    this.savedOccupations = const <String>{},
    this.plans = const <String, ActionPlan>{},
    this.completed = const <String>{},
    this.choices = const <String, String>{},
    this.notes = const <String, String>{},
  });

  /// Occupation ids the person saved.
  final Set<String> savedOccupations;

  /// Plans keyed by occupation id.
  final Map<String, ActionPlan> plans;

  /// Identifiers of everything marked done.
  final Set<String> completed;

  /// Selections from a closed set, by key: a slug or a small whole number.
  /// Never free text.
  final Map<String, String> choices;

  /// Free text the person typed, by key. Treated like every other free-text
  /// field: never logged, and stored only after the person has opted in.
  final Map<String, String> notes;

  static const int maxNoteLength = 600;
  static const int maxNotes = 200;
  static const int maxSavedBullets = 20;

  /// The most that can be compared side by side.
  static const int maxCompared = 3;

  static String planStepKey(
          String occupationId, RouteKind route, String stepId) =>
      'plan/$occupationId/${route.slug}/$stepId';

  static String customStepKey(String occupationId, String stepId) =>
      'plan/$occupationId/custom/$stepId';

  // Keys for the employment tools. Built here and nowhere else.

  static String resumeKey(String sectionId) => 'resume/$sectionId';

  static String linkedInKey(String sectionId) => 'linkedin/$sectionId';

  static String interviewKey(String questionId) => 'interview/$questionId';

  static String interviewNoteKey(String questionId, ExamplePart part) =>
      'interview/$questionId/${part.slug}';

  static String searchTaskKey(String taskId) => 'search/week/$taskId';

  static const String searchHoursKey = 'search/hours';
  static const String searchWeeksKey = 'search/weeks';
  static const String searchNoteKey = 'search/note';
  static const String skillsOccupationKey = 'skills/occupation';

  static String skillKey(String occupationId, int index) =>
      'skill/$occupationId/$index';

  static String skillProjectKey(String occupationId) =>
      'skill/$occupationId/project';

  static String resumeBulletKey(int index) => 'resume/bullet/$index';

  bool get isEmpty =>
      savedOccupations.isEmpty &&
      plans.isEmpty &&
      completed.isEmpty &&
      choices.isEmpty &&
      notes.isEmpty;

  SearchHours? get searchHours => SearchHours.fromSlug(choices[searchHoursKey]);

  /// How many weeks of the job-search plan have been closed off.
  int get searchWeeksCompleted =>
      int.tryParse(choices[searchWeeksKey] ?? '') ?? 0;

  SkillLevel? skillLevel(String occupationId, int index) =>
      SkillLevel.fromSlug(choices[skillKey(occupationId, index)]);

  /// Resume bullets the person chose to keep, oldest first.
  List<String> get savedBullets => <String>[
        for (var i = 0; i < maxSavedBullets; i++)
          if (notes[resumeBulletKey(i)] != null) notes[resumeBulletKey(i)]!,
      ];

  /// How many identifiers under [prefix] are marked done.
  int doneUnder(String prefix) =>
      completed.where((key) => key.startsWith(prefix)).length;

  /// Sets a choice, or clears it when [value] is null.
  Workspace withChoice(String key, String? value) {
    final next = <String, String>{...choices};
    if (value == null) {
      next.remove(key);
    } else {
      next[key] = value;
    }
    return copyWith(choices: next);
  }

  /// Sets a note, or clears it when [text] is null or blank. Text is trimmed
  /// and cut to [maxNoteLength]. A new note beyond [maxNotes] is refused.
  Workspace withNote(String key, String? text) {
    final next = <String, String>{...notes};
    final trimmed = text?.trim() ?? '';
    if (trimmed.isEmpty) {
      next.remove(key);
    } else {
      if (!next.containsKey(key) && next.length >= maxNotes) return this;
      next[key] = trimmed.length > maxNoteLength
          ? trimmed.substring(0, maxNoteLength)
          : trimmed;
    }
    return copyWith(notes: next);
  }

  /// Closes off the current job-search week: clears this week's ticks and
  /// note, and counts the week.
  Workspace withSearchWeekClosed() {
    const prefix = 'search/week/';
    return copyWith(
      completed: completed.where((key) => !key.startsWith(prefix)).toSet(),
      choices: <String, String>{
        ...choices,
        searchWeeksKey: '${searchWeeksCompleted + 1}',
      },
      notes: <String, String>{...notes}..remove(searchNoteKey),
    );
  }

  bool isSaved(String occupationId) => savedOccupations.contains(occupationId);

  bool isDone(String key) => completed.contains(key);

  Workspace toggleSaved(String occupationId) {
    final next = <String>{...savedOccupations};
    if (!next.remove(occupationId)) next.add(occupationId);
    return copyWith(savedOccupations: next);
  }

  Workspace toggleDone(String key) {
    final next = <String>{...completed};
    if (!next.remove(key)) next.add(key);
    return copyWith(completed: next);
  }

  Workspace withPlan(ActionPlan plan) => copyWith(
        plans: <String, ActionPlan>{...plans, plan.occupationId: plan},
      );

  /// Removes a plan and every completion mark that belonged to it.
  Workspace withoutPlan(String occupationId) {
    final prefix = 'plan/$occupationId/';
    return copyWith(
      plans: <String, ActionPlan>{...plans}..remove(occupationId),
      completed: completed.where((key) => !key.startsWith(prefix)).toSet(),
    );
  }

  Workspace copyWith({
    Set<String>? savedOccupations,
    Map<String, ActionPlan>? plans,
    Set<String>? completed,
    Map<String, String>? choices,
    Map<String, String>? notes,
  }) {
    return Workspace(
      savedOccupations: savedOccupations == null
          ? this.savedOccupations
          : Set<String>.unmodifiable(savedOccupations),
      plans: plans == null
          ? this.plans
          : Map<String, ActionPlan>.unmodifiable(plans),
      completed: completed == null
          ? this.completed
          : Set<String>.unmodifiable(completed),
      choices: choices == null
          ? this.choices
          : Map<String, String>.unmodifiable(choices),
      notes:
          notes == null ? this.notes : Map<String, String>.unmodifiable(notes),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Workspace &&
          setEquals(other.savedOccupations, savedOccupations) &&
          mapEquals(other.plans, plans) &&
          setEquals(other.completed, completed) &&
          mapEquals(other.choices, choices) &&
          mapEquals(other.notes, notes));

  @override
  int get hashCode => Object.hash(
        setHash(savedOccupations),
        mapHash(plans),
        setHash(completed),
        mapHash(choices),
        mapHash(notes),
      );
}

import 'package:meta/meta.dart';

import '../util/equality.dart';
import 'occupation.dart';

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
  });

  /// Occupation ids the person saved.
  final Set<String> savedOccupations;

  /// Plans keyed by occupation id.
  final Map<String, ActionPlan> plans;

  /// Identifiers of everything marked done.
  final Set<String> completed;

  /// The most that can be compared side by side.
  static const int maxCompared = 3;

  static String planStepKey(
          String occupationId, RouteKind route, String stepId) =>
      'plan/$occupationId/${route.slug}/$stepId';

  static String customStepKey(String occupationId, String stepId) =>
      'plan/$occupationId/custom/$stepId';

  bool get isEmpty =>
      savedOccupations.isEmpty && plans.isEmpty && completed.isEmpty;

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
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Workspace &&
          setEquals(other.savedOccupations, savedOccupations) &&
          mapEquals(other.plans, plans) &&
          setEquals(other.completed, completed));

  @override
  int get hashCode => Object.hash(
      setHash(savedOccupations), mapHash(plans), setHash(completed));
}

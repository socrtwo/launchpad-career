import 'package:launchpad_domain/launchpad_domain.dart';

/// Converts a [Session] to and from plain JSON-compatible maps.
///
/// Everything is written by slug. Decoding is tolerant by design: an unknown
/// slug (a value removed in a later version, or a hand-edited file) is dropped
/// rather than failing the whole session.
abstract final class SessionCodec {
  static const int schemaVersion = 1;

  /// [includeFreeText] is false for anything written to durable storage. The
  /// "Something else" text is the highest-risk field in the product and is
  /// only ever included in an export the person asked for.
  static Map<String, Object?> encode(
    Session session, {
    bool includeFreeText = false,
  }) {
    final profile = session.profile;
    return <String, Object?>{
      'schemaVersion': schemaVersion,
      if (session.selectedGoal != null) 'goal': session.selectedGoal!.slug,
      'onboarding': <String, Object?>{
        'status': session.onboardingStatus.slug,
        if (session.onboardingStep != null)
          'step': session.onboardingStep!.slug,
      },
      'profile': <String, Object?>{
        if (profile.preferredName != null)
          'preferredName': profile.preferredName,
        if (profile.educationLevel != null)
          'educationLevel': profile.educationLevel!.slug,
        if (profile.plannedEducation != null)
          'plannedEducation': profile.plannedEducation!.slug,
        'interests': _sorted(profile.interests.map((area) => area.slug)),
        'priorities': _sorted(profile.priorities.map((item) => item.slug)),
      },
      if (!session.workspace.isEmpty)
        'workspace': _workspace(session.workspace),
      if (includeFreeText && session.freeTextPrompt != null)
        'somethingElseText': session.freeTextPrompt,
    };
  }

  static Session decode(Map<String, Object?> json) {
    final profile = _map(json['profile']);
    final onboarding = _map(json['onboarding']);
    return Session(
      selectedGoal: GoalId.fromSlug(_string(json['goal'])),
      freeTextPrompt: _string(json['somethingElseText']),
      onboardingStatus:
          OnboardingStatus.fromSlug(_string(onboarding['status'])) ??
              OnboardingStatus.notStarted,
      onboardingStep: OnboardingStep.fromSlug(_string(onboarding['step'])),
      profile: const Profile().copyWith(
        preferredName: _string(profile['preferredName']),
        educationLevel: EducationLevel.fromSlug(
          _string(profile['educationLevel']),
        ),
        plannedEducation: PlannedEducation.fromSlug(
          _string(profile['plannedEducation']),
        ),
        interests: _strings(profile['interests'])
            .map(InterestArea.fromSlug)
            .whereType<InterestArea>()
            .toSet(),
        priorities: _strings(profile['priorities'])
            .map(Priority.fromSlug)
            .whereType<Priority>()
            .take(Priority.maxChoices)
            .toSet(),
      ),
      workspace: _decodeWorkspace(_map(json['workspace'])),
    );
  }

  static Map<String, Object?> _workspace(Workspace workspace) {
    final planIds = workspace.plans.keys.toList()..sort();
    return <String, Object?>{
      'saved': _sorted(workspace.savedOccupations),
      'completed': _sorted(workspace.completed),
      'plans': <Object?>[
        for (final id in planIds)
          <String, Object?>{
            'occupation': id,
            if (workspace.plans[id]!.route != null)
              'route': workspace.plans[id]!.route!.slug,
            'customSteps': <Object?>[
              for (final step in workspace.plans[id]!.customSteps)
                <String, Object?>{'id': step.id, 'text': step.text},
            ],
          },
      ],
    };
  }

  static Workspace _decodeWorkspace(Map<String, Object?> json) {
    final plans = <String, ActionPlan>{};
    final rawPlans = json['plans'];
    if (rawPlans is List) {
      for (final raw in rawPlans) {
        final plan = _map(raw);
        final occupation = _string(plan['occupation']);
        if (occupation == null || occupation.isEmpty) continue;
        final steps = <CustomStep>[];
        final rawSteps = plan['customSteps'];
        if (rawSteps is List) {
          for (final rawStep in rawSteps.take(ActionPlan.maxCustomSteps)) {
            final step = _map(rawStep);
            final id = _string(step['id']);
            final text = _string(step['text']);
            if (id == null || text == null || text.trim().isEmpty) continue;
            steps.add(
              CustomStep(
                id: id,
                text: text.length > CustomStep.maxLength
                    ? text.substring(0, CustomStep.maxLength)
                    : text,
              ),
            );
          }
        }
        plans[occupation] = ActionPlan(
          occupationId: occupation,
          route: RouteKind.fromSlug(_string(plan['route'])),
          customSteps: List<CustomStep>.unmodifiable(steps),
        );
      }
    }
    return const Workspace().copyWith(
      savedOccupations: _strings(json['saved']).toSet(),
      completed: _strings(json['completed']).toSet(),
      plans: plans,
    );
  }

  static List<String> _sorted(Iterable<String> values) =>
      values.toList()..sort();

  static String? _string(Object? value) => value is String ? value : null;

  static Map<String, Object?> _map(Object? value) => value is Map
      ? value.map((key, item) => MapEntry(key.toString(), item as Object?))
      : const <String, Object?>{};

  static List<String> _strings(Object? value) =>
      value is List ? value.whereType<String>().toList() : const <String>[];
}

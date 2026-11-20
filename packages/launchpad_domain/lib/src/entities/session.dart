import 'package:meta/meta.dart';

import 'goal.dart';
import 'onboarding.dart';
import 'profile.dart';
import 'workspace.dart';

const Object _unset = Object();

/// An anonymous working session.
///
/// Data minimisation is a design constraint, not a later feature: there is no
/// email, no account, no identifier tied to a person. Everything here is
/// something the person chose or typed, and all of it is optional.
@immutable
class Session {
  const Session({
    this.selectedGoal,
    this.freeTextPrompt,
    this.profile = const Profile(),
    this.onboardingStatus = OnboardingStatus.notStarted,
    this.onboardingStep,
    this.workspace = const Workspace(),
  });

  /// The primary goal carried forward from the home screen.
  final GoalId? selectedGoal;

  /// Whatever the user typed into the "Something else" field. Treated as
  /// sensitive free text: never logged, never sent to analytics, and never
  /// written to durable storage.
  final String? freeTextPrompt;

  final Profile profile;

  final OnboardingStatus onboardingStatus;

  /// The last onboarding question shown, so the sequence can be resumed.
  final OnboardingStep? onboardingStep;

  /// Saved occupations, plans, and everything marked done.
  final Workspace workspace;

  String? get preferredName => profile.preferredName;

  bool get isAnonymous => profile.preferredName == null;

  /// Whether there is anything to come back to.
  bool get hasProgress =>
      selectedGoal != null ||
      !profile.isEmpty ||
      !workspace.isEmpty ||
      onboardingStatus != OnboardingStatus.notStarted;

  /// Whether the session holds nothing at all.
  bool get isEmpty => !hasProgress && freeTextPrompt == null;

  /// Pass `null` explicitly to clear a nullable field; omit it to keep it.
  Session copyWith({
    Object? selectedGoal = _unset,
    Object? freeTextPrompt = _unset,
    Profile? profile,
    OnboardingStatus? onboardingStatus,
    Object? onboardingStep = _unset,
    Workspace? workspace,
  }) {
    return Session(
      selectedGoal: identical(selectedGoal, _unset)
          ? this.selectedGoal
          : selectedGoal as GoalId?,
      freeTextPrompt: identical(freeTextPrompt, _unset)
          ? this.freeTextPrompt
          : freeTextPrompt as String?,
      profile: profile ?? this.profile,
      onboardingStatus: onboardingStatus ?? this.onboardingStatus,
      onboardingStep: identical(onboardingStep, _unset)
          ? this.onboardingStep
          : onboardingStep as OnboardingStep?,
      workspace: workspace ?? this.workspace,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Session &&
          other.selectedGoal == selectedGoal &&
          other.freeTextPrompt == freeTextPrompt &&
          other.profile == profile &&
          other.onboardingStatus == onboardingStatus &&
          other.onboardingStep == onboardingStep &&
          other.workspace == workspace);

  @override
  int get hashCode => Object.hash(
        selectedGoal,
        freeTextPrompt,
        profile,
        onboardingStatus,
        onboardingStep,
        workspace,
      );
}

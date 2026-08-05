import 'package:meta/meta.dart';

import 'goal.dart';

/// An anonymous working session.
///
/// Data minimisation is a design constraint, not a later feature: there is no
/// name, no email, no identifier tied to a person. [preferredName] exists only
/// so a later onboarding step can address the user, is optional, and is never
/// required to use the product.
@immutable
class Session {
  const Session({
    this.selectedGoal,
    this.preferredName,
    this.freeTextPrompt,
  });

  final GoalId? selectedGoal;
  final String? preferredName;

  /// Whatever the user typed into the "Something else" field. Treated as
  /// sensitive free text: never logged, never sent to analytics.
  final String? freeTextPrompt;

  bool get isAnonymous => preferredName == null;

  Session copyWith({
    GoalId? selectedGoal,
    String? preferredName,
    String? freeTextPrompt,
    bool clearSelectedGoal = false,
  }) {
    return Session(
      selectedGoal:
          clearSelectedGoal ? null : (selectedGoal ?? this.selectedGoal),
      preferredName: preferredName ?? this.preferredName,
      freeTextPrompt: freeTextPrompt ?? this.freeTextPrompt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Session &&
          other.selectedGoal == selectedGoal &&
          other.preferredName == preferredName &&
          other.freeTextPrompt == freeTextPrompt);

  @override
  int get hashCode => Object.hash(selectedGoal, preferredName, freeTextPrompt);
}

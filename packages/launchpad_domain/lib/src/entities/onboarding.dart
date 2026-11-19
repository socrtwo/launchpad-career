/// The questions asked before a goal's tools open, in order.
///
/// Every step can be skipped and the whole sequence can be skipped: onboarding
/// tailors the guidance, it is never a gate on it.
enum OnboardingStep {
  name('name'),
  education('education'),
  plans('plans'),
  interests('interests'),
  priorities('priorities'),
  review('review');

  const OnboardingStep(this.slug);

  final String slug;

  static OnboardingStep get first => OnboardingStep.values.first;

  static OnboardingStep? fromSlug(String? slug) {
    if (slug == null) return null;
    for (final step in OnboardingStep.values) {
      if (step.slug == slug) return step;
    }
    return null;
  }

  /// 1-based position, for "Step 2 of 6".
  int get position => index + 1;

  static int get total => OnboardingStep.values.length;

  OnboardingStep? get next => index + 1 < OnboardingStep.values.length
      ? OnboardingStep.values[index + 1]
      : null;

  OnboardingStep? get previous =>
      index == 0 ? null : OnboardingStep.values[index - 1];
}

/// Where a person is in the onboarding questions.
enum OnboardingStatus {
  /// No question has been shown yet.
  notStarted('not-started'),

  /// At least one question has been shown and the sequence is not finished.
  inProgress('in-progress'),

  /// The person reached the end and confirmed their answers.
  completed('completed'),

  /// The person chose to skip the questions. Treated as finished: they are not
  /// asked again unless they open the questions themselves.
  skipped('skipped');

  const OnboardingStatus(this.slug);

  final String slug;

  bool get isFinished =>
      this == OnboardingStatus.completed || this == OnboardingStatus.skipped;

  static OnboardingStatus? fromSlug(String? slug) {
    if (slug == null) return null;
    for (final status in OnboardingStatus.values) {
      if (status.slug == slug) return status;
    }
    return null;
  }
}

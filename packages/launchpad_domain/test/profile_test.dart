import 'package:launchpad_domain/launchpad_domain.dart';
import 'package:test/test.dart';

void main() {
  test('every enum that is stored has unique, stable slugs', () {
    void check(Iterable<String> slugs) {
      final list = slugs.toList();
      expect(list.toSet(), hasLength(list.length));
      for (final slug in list) {
        expect(slug, matches(RegExp(r'^[a-z]+(-[a-z]+)*$')));
      }
    }

    check(EducationLevel.values.map((value) => value.slug));
    check(PlannedEducation.values.map((value) => value.slug));
    check(InterestArea.values.map((value) => value.slug));
    check(Priority.values.map((value) => value.slug));
    check(OnboardingStep.values.map((value) => value.slug));
    check(OnboardingStatus.values.map((value) => value.slug));
  });

  test('slug lookups round-trip and reject unknown values', () {
    for (final level in EducationLevel.values) {
      expect(EducationLevel.fromSlug(level.slug), level);
    }
    for (final area in InterestArea.values) {
      expect(InterestArea.fromSlug(area.slug), area);
    }
    expect(EducationLevel.fromSlug('kindergarten'), isNull);
    expect(Priority.fromSlug(null), isNull);
  });

  test('a preferred name is trimmed, capped, and blank means none', () {
    const profile = Profile();
    expect(profile.copyWith(preferredName: '  Sam  ').preferredName, 'Sam');
    expect(profile.copyWith(preferredName: '   ').preferredName, isNull);
    expect(
      profile.copyWith(preferredName: 'x' * 90).preferredName,
      hasLength(Profile.maxNameLength),
    );
  });

  test('copyWith keeps what is omitted and clears what is passed as null', () {
    final profile = const Profile().copyWith(
      preferredName: 'Sam',
      educationLevel: EducationLevel.associate,
    );
    expect(profile.copyWith().educationLevel, EducationLevel.associate);
    expect(profile.copyWith(educationLevel: null).educationLevel, isNull);
    expect(profile.copyWith(educationLevel: null).preferredName, 'Sam');
  });

  test('profiles compare by value, including their sets', () {
    final a = const Profile().copyWith(
      interests: <InterestArea>{InterestArea.data, InterestArea.science},
    );
    final b = const Profile().copyWith(
      interests: <InterestArea>{InterestArea.science, InterestArea.data},
    );
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a.answeredCount, 1);
    expect(const Profile().isEmpty, isTrue);
  });

  test('onboarding steps know their neighbours and position', () {
    expect(OnboardingStep.first, OnboardingStep.name);
    expect(OnboardingStep.name.previous, isNull);
    expect(OnboardingStep.name.next, OnboardingStep.education);
    expect(OnboardingStep.review.next, isNull);
    expect(OnboardingStep.review.position, OnboardingStep.total);
    expect(OnboardingStatus.skipped.isFinished, isTrue);
    expect(OnboardingStatus.inProgress.isFinished, isFalse);
  });

  test('a session reports whether there is anything to come back to', () {
    expect(const Session().hasProgress, isFalse);
    expect(const Session().isEmpty, isTrue);
    expect(const Session(selectedGoal: GoalId.direction).hasProgress, isTrue);
    expect(const Session(freeTextPrompt: 'note').hasProgress, isFalse);
    expect(const Session(freeTextPrompt: 'note').isEmpty, isFalse);
    expect(
      const Session(selectedGoal: GoalId.direction)
          .copyWith(selectedGoal: null)
          .selectedGoal,
      isNull,
    );
  });
}

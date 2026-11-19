import 'package:launchpad_domain/launchpad_domain.dart';

/// Copy for the onboarding questions and the answers they offer.
///
/// Reviewed as a block against `docs/product/tone-and-language.md`: every
/// question says why it is asked, none of them labels the reader, and none is
/// required.
mixin OnboardingStrings {
  String stepOf(int position, int total) => 'Step $position of $total';

  String get back => 'Back';

  String get skipQuestion => 'Skip this question';

  String get skipAllQuestions => 'Skip the questions';

  String get skipAllHint =>
      'The questions tailor what you see. Nothing is locked if you skip them.';

  String get finish => 'Finish';

  String get change => 'Change';

  String get noAnswer => 'No answer';

  String onboardingTitle(OnboardingStep step) => switch (step) {
        OnboardingStep.name => 'What should we call you?',
        OnboardingStep.education =>
          'What is the highest level of education you have finished or are '
              'working on?',
        OnboardingStep.plans => 'Are you planning more education?',
        OnboardingStep.interests => 'What kinds of work interest you?',
        OnboardingStep.priorities =>
          'What matters most to you in a job right now?',
        OnboardingStep.review => 'Check your answers',
      };

  /// Shown next to the question, not in a policy page nobody opens.
  String onboardingReason(OnboardingStep step) => switch (step) {
        OnboardingStep.name =>
          'Optional. We only use it to address you on this device. Leave it '
              'blank and nothing changes.',
        OnboardingStep.education =>
          'This sets which routes we show first. Some occupations need a '
              'degree; many do not.',
        OnboardingStep.plans =>
          'This separates options you could start on now from ones that need '
              'more study first.',
        OnboardingStep.interests =>
          'Choose any that fit. We match them against what each occupation '
              'involves day to day.',
        OnboardingStep.priorities =>
          'Choose up to three. Priorities change the order of suggestions, '
              'never which ones you can see.',
        OnboardingStep.review =>
          'These are the only things we know about you, and you can change any '
              'of them at any time.',
      };

  /// Short label for the review list and for "Change …" buttons.
  String onboardingShortLabel(OnboardingStep step) => switch (step) {
        OnboardingStep.name => 'Preferred name',
        OnboardingStep.education => 'Education so far',
        OnboardingStep.plans => 'Planned education',
        OnboardingStep.interests => 'Interests',
        OnboardingStep.priorities => 'Priorities',
        OnboardingStep.review => 'Review',
      };

  String changeAnswer(String label) => 'Change ${_lowerFirst(label)}';

  String get nameFieldLabel => 'Preferred name (optional)';

  String get priorityLimitReached =>
      'You can choose up to three. Remove one to add another.';

  String selectedCount(int count) =>
      count == 1 ? '1 selected' : '$count selected';

  String get reviewGoalLabel => 'Your goal';

  String get reviewNoGoal => 'No goal chosen yet';

  String get changeGoal => 'Change goal';

  String get chooseGoal => 'Choose a goal';

  String educationLevel(EducationLevel level) => switch (level) {
        EducationLevel.highSchool => 'High school diploma or equivalent',
        EducationLevel.certificate => 'Trade or technical certificate',
        EducationLevel.someCollege => 'Some college, no degree yet',
        EducationLevel.associate => 'Associate degree',
        EducationLevel.bachelors => "Bachelor's degree",
        EducationLevel.masters => "Master's degree",
        EducationLevel.doctoral => 'Doctoral or professional degree',
      };

  String plannedEducation(PlannedEducation plan) => switch (plan) {
        PlannedEducation.none => 'No further study planned',
        PlannedEducation.certificate => 'A trade or technical certificate',
        PlannedEducation.associate => 'An associate degree',
        PlannedEducation.bachelors => "A bachelor's degree",
        PlannedEducation.masters => "A master's degree",
        PlannedEducation.doctoral => 'A doctoral or professional degree',
        PlannedEducation.undecided => 'Not sure yet',
      };

  String interestArea(InterestArea area) => switch (area) {
        InterestArea.technology => 'Software and technology',
        InterestArea.data => 'Numbers, data, and analysis',
        InterestArea.building => 'Building, repairing, and making things',
        InterestArea.caring => 'Health and caring for people',
        InterestArea.teaching => 'Teaching and explaining',
        InterestArea.creative => 'Design, writing, and creative work',
        InterestArea.organising => 'Organising, planning, and leading',
        InterestArea.science => 'Science and research',
        InterestArea.outdoors => 'Outdoor and physical work',
        InterestArea.advocacy => 'Advising, persuading, and advocating',
      };

  String priority(Priority value) => switch (value) {
        Priority.earnings => 'Higher pay over time',
        Priority.stability => 'Steady, predictable work',
        Priority.shortTraining => 'A short route into work',
        Priority.lowCost => 'Low cost of training',
        Priority.flexibility => 'Flexible hours or location',
        Priority.helpingPeople => 'Helping people directly',
        Priority.advancement => 'Room to move up',
        Priority.handsOn => 'Practical, hands-on work',
      };

  String _lowerFirst(String text) =>
      text.isEmpty ? text : text[0].toLowerCase() + text.substring(1);
}

import 'package:launchpad_domain/launchpad_domain.dart';

/// Copy for exploring, comparing, saving and planning.
///
/// Two rules dominate here. A figure never appears without its source and the
/// period it describes, and nothing reads as a promise: figures describe
/// everyone in an occupation, not what will happen to the reader.
mixin ExploreStrings {
  String interestArea(InterestArea area);
  String educationLevel(EducationLevel level);
  String plannedEducation(PlannedEducation plan);
  String priority(Priority value);

  static const List<String> _months = <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  String monthYear(DateTime date) => '${_months[date.month - 1]} ${date.year}';

  /// Whole numbers with thousands separators: 1534790 becomes 1,534,790.
  String wholeNumber(int value) {
    final digits = value.abs().toString();
    final buffer = StringBuffer(value < 0 ? '-' : '');
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }

  String dollars(int value) => '\$${wholeNumber(value)}';

  // Navigation and tools.

  String get exploreTitle => 'Browse occupations';

  String get exploreIntro =>
      'Search by what the work involves, or narrow by the kinds of work that '
      'interest you. Save the ones worth a closer look.';

  String get exploreDescription =>
      'Search and read about occupations, the work involved and the ways in.';

  String get searchLabel => 'Search occupations';

  String get searchHint => 'For example: nurse, design, wiring';

  String get clearSearch => 'Clear search';

  String get filterHeading => 'Kinds of work';

  String get clearFilters => 'Clear search and filters';

  String resultCount(int count) => switch (count) {
        0 => 'No occupations match.',
        1 => '1 occupation',
        _ => '$count occupations',
      };

  String get noResultsHint =>
      'Try fewer words, or remove a filter. The catalogue is small in this '
      'build, so some occupations are not here yet.';

  String get occupationsUnavailable =>
      'We could not load the occupations just now. Try again.';

  String get backToOccupations => 'Back to occupations';

  String get savedTitle => 'Saved options';

  String get savedDescription => 'The occupations you saved, with their plans.';

  String get savedEmpty =>
      'Nothing saved yet. Browse the occupations and save the ones worth a '
      'closer look.';

  String get suggestionsTitle => 'Suggestions from your answers';

  String get suggestionsDescription =>
      'A short list matched to your answers, with the reason for each.';

  String get compareTitle => 'Compare side by side';

  String get compareDescription =>
      'Put two or three occupations next to each other.';

  // Occupation cards and detail.

  String get viewDetails => 'View details';

  String viewOccupation(String title) => 'View details: $title';

  String get save => 'Save';

  String get saved => 'Saved';

  String saveOccupation(String title) => 'Save $title';

  String removeSaved(String title) => 'Remove $title from saved options';

  String savedStatus(String title) => 'Saved: $title';

  String removedStatus(String title) => 'Removed from saved options: $title';

  String get nonDegreeLabel => 'Has a route without a four-year degree';

  String get paidTrainingLabel => 'Has a route that pays while you train';

  String get workInvolvesHeading => 'What the work involves';

  String get skillsHeading => 'Skills commonly asked for';

  String get routesHeading => 'Ways in';

  String get routesIntro =>
      'Where more than one route exists, more than one is listed. None of '
      'them is the single correct one.';

  String routeKind(RouteKind kind) => switch (kind) {
        RouteKind.bachelorsDegree => 'Four-year degree',
        RouteKind.graduateDegree => 'Graduate degree',
        RouteKind.associateDegree => 'Two-year degree',
        RouteKind.certificate => 'Certificate',
        RouteKind.apprenticeship => 'Paid apprenticeship',
        RouteKind.employerTraining => 'Training from an employer',
        RouteKind.selfDirected => 'Self-directed',
      };

  String get changeHeading => 'How this work is changing';

  String get occupationCode => 'Standard Occupational Classification code';

  String occupationCodeLine(String code, String title) =>
      'Standard Occupational Classification 2018: $code, $title.';

  String get unknownOccupation =>
      'That occupation link is not one we recognise.';

  String get startPlan => 'Start a plan';

  String get openPlan => 'Open your plan';

  String get compareWithOthers => 'Compare with others';

  // Pay.

  String get payHeading => 'Pay';

  String get payNotLoaded =>
      'Pay figures are not loaded in this build. When they are, each one will '
      'show its source and the period it describes. Until then this page '
      'shows no numbers rather than unsourced ones.';

  String payMedian(String amount, String period) =>
      'Reported median annual pay for this occupation in the United States '
      'was $amount in $period. Half of the people in it earned more and half '
      'earned less.';

  String payMedianTopCoded(String period) =>
      'Reported median annual pay for this occupation in the United States '
      'was above the highest figure the publisher releases in $period.';

  String paySpread(String low, String high) =>
      'One in ten earned less than $low and one in ten earned more than $high.';

  String get payWideSpread =>
      'That is a wide spread, so the median says little about any one job.';

  String payEmployment(String jobs, String period) =>
      'About $jobs jobs were counted in $period.';

  String get payNotAvailableForOccupation =>
      'The publisher did not release a pay figure for this occupation.';

  String get payCaveat =>
      'These figures cover the whole country and every level of experience. '
      'They describe the people already in the occupation and are not a '
      'prediction of what you would be paid.';

  String payCompareLine(String amount, String period) =>
      'Median $amount a year ($period)';

  // Provenance.

  String sourceLine(String source, String? period) =>
      period == null ? 'Source: $source.' : 'Source: $source, $period.';

  String editorialLine(String? reviewed) => reviewed == null
      ? 'Written and reviewed by a careers editor.'
      : 'Written and reviewed by a careers editor, $reviewed.';

  String generatedLine(String? drafted) => drafted == null
      ? 'This description was drafted with AI assistance and has not yet been '
          'reviewed by a careers adviser.'
      : 'This description was drafted with AI assistance in $drafted and has '
          'not yet been reviewed by a careers adviser.';

  String get userProvidedLine => 'From your answers. You can change them.';

  String get staleLine =>
      'These figures are more than 18 months old. Conditions may have '
      'changed since.';

  // Suggestions.

  String get suggestionsIntro =>
      'These are matched to your answers by fixed rules, which are shown '
      'under each one. They are a place to start reading, not a prediction '
      'and not a ranking of what is best for you.';

  String get suggestionsNeedInterests =>
      'To suggest anything we need to know what kinds of work interest you. '
      'It is one question and you can change the answer at any time.';

  String get answerInterests => 'Answer the interests question';

  String get suggestionsNoMatches =>
      'Nothing in the catalogue matches those interests yet. The catalogue is '
      'small in this build.';

  String get whyHeading => 'Why this is here';

  String confidence(ConfidenceBand band) => switch (band) {
        ConfidenceBand.high => 'Close match to your answers',
        ConfidenceBand.moderate => 'Partial match to your answers',
        ConfidenceBand.low => 'Loose match, based on little information',
      };

  String suggestedRoute(String route) => 'A way in to look at first: $route';

  String reasonInterest(InterestArea area) =>
      'You said you are interested in ${_lowerFirst(interestArea(area))}.';

  String reasonOpenNow(EducationLevel level, String route) =>
      'Your education so far (${_lowerFirst(educationLevel(level))}) is at '
      'the level this route starts from: $route.';

  String reasonOpenWithPlan(PlannedEducation plan, String route) =>
      'The study you are planning (${_lowerFirst(plannedEducation(plan))}) '
      'would reach the level this route needs: $route.';

  String reasonPriority(Priority value, {String? route}) => switch (value) {
        Priority.shortTraining =>
          'You want a short route into work: ${route ?? 'one route'} does '
              'not need a four-year degree.',
        Priority.lowCost =>
          'You want low-cost training: ${route ?? 'one route'} is normally '
              'paid.',
        Priority.handsOn =>
          'You want practical, hands-on work, and most of this work is.',
        Priority.flexibility =>
          'You want flexible hours or location, which are common in this '
              'work.',
        Priority.helpingPeople =>
          'You want to help people directly, which is central to this work.',
        Priority.earnings ||
        Priority.stability ||
        Priority.advancement =>
          'You chose ${_lowerFirst(priority(value))}.',
      };

  String reasonEarnings(String amount, String period, String baseline) =>
      'You want higher pay over time: reported median pay was $amount in '
      '$period, above the median for all occupations ($baseline).';

  String get noteFewAnswers =>
      'You have answered only a little so far, so treat this list as a rough '
      'start. More answers make the matching more specific.';

  String get noteNonDegree =>
      'One suggestion was added so the list includes a route that does not '
      'need a four-year degree.';

  String get notePayUnavailable =>
      'You chose higher pay over time, but pay figures are not loaded in this '
      'build, so that priority did not change the order.';

  String noteUnused(String priorities) =>
      'Not used: $priorities. We have no dependable data for these yet, so '
      'they did not change the order.';

  String get changeAnswers => 'Change your answers';

  String get browseAll => 'Browse all occupations';

  // Compare.

  String get compareIntro =>
      'Choose two or three occupations. Each row puts the same information '
      'side by side.';

  String get compareNeedMore => 'Choose at least two occupations to compare.';

  String get compareLimit =>
      'You can compare up to three at a time. Remove one to add another.';

  String get compareChoose => 'Choose occupations to compare';

  String get compareSummaryRow => 'In one sentence';

  String compareSelected(int count) => '$count selected';

  String get compareSaved => 'Compare saved options';

  // Plans.

  String planTitle(String occupation) => 'Your plan: $occupation';

  String get planIntro =>
      'Pick the way in you want to plan for, then work through the steps in '
      'any order. A plan is a list of things to find out and do. It does not '
      'commit you to anything.';

  String get planChooseRoute => 'Which way in is this plan for?';

  String get planStepsHeading => 'Steps';

  String planProgress(int done, int total) => '$done of $total steps done';

  String get planAddHeading => 'Add a step of your own';

  String get planAddLabel => 'Your step';

  String get planAdd => 'Add step';

  String get planAddedStatus => 'Step added.';

  String get planFull =>
      'A plan holds up to 12 steps of your own. Remove one to add another.';

  String removeStep(String text) => 'Remove step: $text';

  String get planRemove => 'Remove this plan';

  String get planRemoved => 'Plan removed.';

  String get planYourSteps => 'Your own steps';

  String get planStorageNote =>
      'Steps you write are kept like your other answers: on this device, and '
      'saved only if you turned saving on.';

  String planSummary(int done, int total) => 'Plan: $done of $total steps done';

  String _lowerFirst(String text) =>
      text.isEmpty ? text : text[0].toLowerCase() + text.substring(1);
}

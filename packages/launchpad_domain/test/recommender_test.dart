import 'package:launchpad_domain/launchpad_domain.dart';
import 'package:test/test.dart';

const _draft = Evidence(kind: EvidenceKind.generatedGuidance);

Occupation occupation(
  String id, {
  required Set<InterestArea> interests,
  required List<RouteKind> routes,
  String soc = '00-0000',
  bool handsOn = false,
  bool flexible = false,
}) =>
    Occupation(
      id: id,
      socCode: soc,
      socTitle: id,
      title: id,
      summary: 'Summary of $id.',
      tasks: const <String>['A task'],
      interests: interests,
      skills: const <String>['A skill'],
      routes: <EntryRoute>[
        for (final kind in routes)
          EntryRoute(kind: kind, title: kind.slug, description: 'How.'),
      ],
      evidence: _draft,
      handsOn: handsOn,
      flexibleArrangementsCommon: flexible,
    );

final _catalogue = <Occupation>[
  occupation(
    'analyst',
    soc: '11-1111',
    interests: <InterestArea>{InterestArea.data, InterestArea.technology},
    routes: <RouteKind>[RouteKind.bachelorsDegree],
    flexible: true,
  ),
  occupation(
    'researcher',
    soc: '22-2222',
    interests: <InterestArea>{InterestArea.data, InterestArea.science},
    routes: <RouteKind>[RouteKind.graduateDegree],
  ),
  occupation(
    'support',
    soc: '33-3333',
    interests: <InterestArea>{InterestArea.technology},
    routes: <RouteKind>[RouteKind.certificate, RouteKind.employerTraining],
  ),
  occupation(
    'electrician',
    soc: '44-4444',
    interests: <InterestArea>{InterestArea.building},
    routes: <RouteKind>[RouteKind.apprenticeship],
    handsOn: true,
  ),
  occupation(
    'nurse',
    soc: '55-5555',
    interests: <InterestArea>{InterestArea.caring, InterestArea.science},
    routes: <RouteKind>[RouteKind.associateDegree, RouteKind.bachelorsDegree],
  ),
];

LaborMarketSnapshot snapshot(Map<String, int> medians, {int? baseline}) {
  final evidence = Evidence(
    kind: EvidenceKind.laborMarketData,
    source: 'Test statistics office',
    asOf: DateTime.utc(2024, 5),
  );
  return LaborMarketSnapshot(
    source: 'Test statistics office',
    sourceUrl: 'https://example.org',
    referencePeriod: 'May 2024',
    asOf: DateTime.utc(2024, 5),
    retrievedOn: DateTime.utc(2025, 4),
    allOccupationsMedianAnnualWage: baseline,
    statsBySoc: <String, LaborStats>{
      for (final entry in medians.entries)
        entry.key: LaborStats(
          socCode: entry.key,
          medianAnnualWage: entry.value,
          evidence: evidence,
        ),
    },
  );
}

Profile profile({
  Set<InterestArea> interests = const <InterestArea>{},
  EducationLevel? level,
  PlannedEducation? plan,
  Set<Priority> priorities = const <Priority>{},
  String? name,
}) =>
    const Profile().copyWith(
      preferredName: name,
      interests: interests,
      educationLevel: level,
      plannedEducation: plan,
      priorities: priorities,
    );

List<String> ids(RecommendationSet set) =>
    set.items.map((item) => item.occupation.id).toList();

void main() {
  test('suggests nothing, and says why, until an interest is given', () {
    final result = Recommender.recommend(
      profile: profile(level: EducationLevel.bachelors),
      occupations: _catalogue,
    );
    expect(result.items, isEmpty);
    expect(result.notes, contains(RecommendationNote.needsInterests));
  });

  test('only suggests occupations that share a stated interest', () {
    final result = Recommender.recommend(
      profile: profile(interests: <InterestArea>{InterestArea.building}),
      occupations: _catalogue,
    );
    expect(ids(result), <String>['electrician']);
  });

  test('every suggestion carries at least one reason', () {
    final result = Recommender.recommend(
      profile: profile(
        interests: <InterestArea>{InterestArea.data, InterestArea.technology},
      ),
      occupations: _catalogue,
    );
    expect(result.items, isNotEmpty);
    for (final item in result.items) {
      expect(item.reasons, isNotEmpty);
      expect(item.reasons.first, isA<InterestReason>());
    }
  });

  test('more shared interests rank higher', () {
    final result = Recommender.recommend(
      profile: profile(
        interests: <InterestArea>{InterestArea.data, InterestArea.technology},
      ),
      occupations: _catalogue,
    );
    expect(ids(result).first, 'analyst');
  });

  test('education changes the order but never removes a match', () {
    final interests = <InterestArea>{InterestArea.technology};
    final withDiploma = Recommender.recommend(
      profile: profile(interests: interests, level: EducationLevel.highSchool),
      occupations: _catalogue,
    );
    final withDegree = Recommender.recommend(
      profile: profile(interests: interests, level: EducationLevel.bachelors),
      occupations: _catalogue,
    );

    expect(ids(withDiploma).first, 'support');
    expect(ids(withDiploma), contains('analyst'));
    expect(ids(withDegree), containsAll(<String>['analyst', 'support']));

    final support = withDiploma.items.first;
    expect(support.reasons.whereType<RouteOpenNowReason>(), hasLength(1));
    expect(support.suggestedRoute?.kind, RouteKind.employerTraining);

    final analyst =
        withDiploma.items.firstWhere((item) => item.occupation.id == 'analyst');
    expect(analyst.reasons.whereType<RouteOpenNowReason>(), isEmpty);
  });

  test('a credentialed route at the person\'s level is preferred', () {
    final result = Recommender.recommend(
      profile: profile(
        interests: <InterestArea>{InterestArea.caring},
        level: EducationLevel.bachelors,
      ),
      occupations: _catalogue,
    );
    expect(result.items.single.suggestedRoute?.kind, RouteKind.bachelorsDegree);

    final atAssociate = Recommender.recommend(
      profile: profile(
        interests: <InterestArea>{InterestArea.caring},
        level: EducationLevel.someCollege,
        plan: PlannedEducation.associate,
      ),
      occupations: _catalogue,
    );
    final nurse = atAssociate.items.single;
    expect(nurse.suggestedRoute?.kind, RouteKind.associateDegree);
    expect(nurse.reasons.whereType<RouteOpenWithPlanReason>(), hasLength(1));
  });

  test('planned study opens routes the current level does not', () {
    final result = Recommender.recommend(
      profile: profile(
        interests: <InterestArea>{InterestArea.science},
        level: EducationLevel.bachelors,
        plan: PlannedEducation.masters,
      ),
      occupations: _catalogue,
    );
    final researcher =
        result.items.firstWhere((item) => item.occupation.id == 'researcher');
    expect(
      researcher.reasons.whereType<RouteOpenWithPlanReason>().single.plan,
      PlannedEducation.masters,
    );
  });

  test('priorities add reasons that point at the route that satisfies them',
      () {
    final result = Recommender.recommend(
      profile: profile(
        interests: <InterestArea>{InterestArea.technology},
        priorities: <Priority>{Priority.shortTraining, Priority.lowCost},
      ),
      occupations: _catalogue,
    );
    final support = result.items.first;
    expect(support.occupation.id, 'support');
    final reasons = support.reasons.whereType<PriorityReason>().toList();
    expect(
      reasons.map((reason) => reason.priority),
      <Priority>[Priority.shortTraining, Priority.lowCost],
    );
    expect(reasons.first.route?.kind, RouteKind.certificate);
    expect(reasons.last.route?.kind, RouteKind.employerTraining);
  });

  test('hands-on, flexibility and helping people use the occupation flags', () {
    Recommendation only(Set<InterestArea> interests, Priority priority) =>
        Recommender.recommend(
          profile: profile(interests: interests, priorities: {priority}),
          occupations: _catalogue,
        ).items.first;

    expect(
      only({InterestArea.building}, Priority.handsOn)
          .reasons
          .whereType<PriorityReason>(),
      hasLength(1),
    );
    expect(
      only({InterestArea.caring}, Priority.helpingPeople)
          .reasons
          .whereType<PriorityReason>(),
      hasLength(1),
    );
    final flexible = Recommender.recommend(
      profile: profile(
        interests: {InterestArea.technology},
        priorities: {Priority.flexibility},
      ),
      occupations: _catalogue,
    );
    expect(ids(flexible).first, 'analyst');
  });

  test('pay is used only when figures are loaded, and carries them', () {
    final interests = <InterestArea>{InterestArea.technology};
    final priorities = <Priority>{Priority.earnings};

    final without = Recommender.recommend(
      profile: profile(interests: interests, priorities: priorities),
      occupations: _catalogue,
    );
    expect(without.notes, contains(RecommendationNote.payNotAvailable));
    expect(without.unusedPriorities, contains(Priority.earnings));
    for (final item in without.items) {
      expect(item.reasons.whereType<PriorityReason>(), isEmpty);
    }

    final withFigures = Recommender.recommend(
      profile: profile(interests: interests, priorities: priorities),
      occupations: _catalogue,
      laborMarket: snapshot(
        <String, int>{'11-1111': 90000, '33-3333': 40000},
        baseline: 50000,
      ),
    );
    expect(
        withFigures.notes, isNot(contains(RecommendationNote.payNotAvailable)));
    final analyst =
        withFigures.items.firstWhere((item) => item.occupation.id == 'analyst');
    final reason = analyst.reasons.whereType<PriorityReason>().single;
    expect(reason.stats?.medianAnnualWage, 90000);
    expect(reason.stats?.evidence.source, isNotNull);
    final support =
        withFigures.items.firstWhere((item) => item.occupation.id == 'support');
    expect(support.reasons.whereType<PriorityReason>(), isEmpty);
  });

  test('priorities with no data behind them are reported, not guessed', () {
    final result = Recommender.recommend(
      profile: profile(
        interests: <InterestArea>{InterestArea.data},
        priorities: <Priority>{Priority.stability, Priority.advancement},
      ),
      occupations: _catalogue,
    );
    expect(result.notes, contains(RecommendationNote.priorityNotUsed));
    expect(
      result.unusedPriorities,
      <Priority>{Priority.stability, Priority.advancement},
    );
    for (final item in result.items) {
      expect(item.reasons.whereType<PriorityReason>(), isEmpty);
    }
  });

  test('swaps in a route without a degree when the list has none', () {
    final catalogue = <Occupation>[
      for (var i = 0; i < 3; i++)
        occupation(
          'degree-$i',
          interests: <InterestArea>{InterestArea.data, InterestArea.science},
          routes: <RouteKind>[RouteKind.bachelorsDegree],
        ),
      occupation(
        'clerk',
        interests: <InterestArea>{InterestArea.data},
        routes: <RouteKind>[RouteKind.employerTraining],
      ),
    ];
    final result = Recommender.recommend(
      profile: profile(
        interests: <InterestArea>{InterestArea.data, InterestArea.science},
      ),
      occupations: catalogue,
      limit: 3,
    );
    expect(ids(result), hasLength(3));
    expect(ids(result).last, 'clerk');
    expect(result.notes, contains(RecommendationNote.includedNonDegreeRoute));
  });

  test('confidence is a band in words and falls with thinner evidence', () {
    final strong = Recommender.recommend(
      profile: profile(
        interests: <InterestArea>{InterestArea.data, InterestArea.technology},
        level: EducationLevel.bachelors,
      ),
      occupations: _catalogue,
    );
    expect(strong.items.first.confidence, ConfidenceBand.high);

    final thin = Recommender.recommend(
      profile: profile(interests: <InterestArea>{InterestArea.science}),
      occupations: _catalogue,
    );
    expect(
      thin.items.map((item) => item.confidence).toSet(),
      <ConfidenceBand>{ConfidenceBand.low},
    );
    expect(thin.notes, contains(RecommendationNote.fewAnswers));
  });

  test('the result is deterministic and respects the limit', () {
    final input = profile(
      interests: InterestArea.values.toSet(),
      level: EducationLevel.associate,
    );
    final first = Recommender.recommend(
      profile: input,
      occupations: _catalogue,
      limit: 3,
    );
    final second = Recommender.recommend(
      profile: input,
      occupations: _catalogue.reversed.toList(),
      limit: 3,
    );
    expect(ids(first), hasLength(3));
    expect(ids(first), ids(second));
  });

  test('a name never changes what is suggested', () {
    // The recommender has no input for any protected characteristic. A name is
    // the one field in the profile that could stand in for one, so this pins
    // that it is ignored.
    RecommendationSet run(String? name) => Recommender.recommend(
          profile: profile(
            name: name,
            interests: <InterestArea>{InterestArea.data, InterestArea.caring},
            level: EducationLevel.someCollege,
            priorities: <Priority>{Priority.shortTraining},
          ),
          occupations: _catalogue,
        );

    final baseline = run(null);
    for (final name in <String>['Aisha', 'Connor', 'Mei', 'José', 'Olu']) {
      final result = run(name);
      expect(ids(result), ids(baseline));
      expect(
        result.items.map((item) => item.confidence),
        baseline.items.map((item) => item.confidence),
      );
      expect(result.notes, baseline.notes);
    }
  });
}

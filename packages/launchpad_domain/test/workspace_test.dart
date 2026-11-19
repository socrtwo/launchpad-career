import 'package:launchpad_domain/launchpad_domain.dart';
import 'package:test/test.dart';

void main() {
  test('saving an occupation twice removes it again', () {
    const workspace = Workspace();
    final saved = workspace.toggleSaved('nurse');
    expect(saved.isSaved('nurse'), isTrue);
    expect(saved.toggleSaved('nurse').isSaved('nurse'), isFalse);
    expect(workspace.isEmpty, isTrue);
    expect(saved.isEmpty, isFalse);
  });

  test('completion keys are namespaced by plan, route and step', () {
    final key = Workspace.planStepKey(
      'nurse',
      RouteKind.associateDegree,
      'find-programmes',
    );
    expect(key, 'plan/nurse/associate-degree/find-programmes');
    expect(Workspace.customStepKey('nurse', 'c1'), 'plan/nurse/custom/c1');

    final done = const Workspace().toggleDone(key);
    expect(done.isDone(key), isTrue);
    expect(done.toggleDone(key).isDone(key), isFalse);
  });

  test('removing a plan removes its completion marks and no others', () {
    final nurseKey =
        Workspace.planStepKey('nurse', RouteKind.associateDegree, 'a');
    final otherKey =
        Workspace.planStepKey('electrician', RouteKind.apprenticeship, 'a');
    final workspace = const Workspace()
        .withPlan(const ActionPlan(occupationId: 'nurse'))
        .withPlan(const ActionPlan(occupationId: 'electrician'))
        .toggleDone(nurseKey)
        .toggleDone(otherKey);

    final after = workspace.withoutPlan('nurse');

    expect(after.plans.keys, <String>['electrician']);
    expect(after.isDone(nurseKey), isFalse);
    expect(after.isDone(otherKey), isTrue);
  });

  test('workspaces and plans compare by value', () {
    const step = CustomStep(id: 'c1', text: 'Email the programme office');
    final a = const Workspace().withPlan(
      const ActionPlan(occupationId: 'nurse')
          .withRoute(RouteKind.associateDegree)
          .withCustomSteps(const <CustomStep>[step]),
    );
    final b = const Workspace().withPlan(
      const ActionPlan(
        occupationId: 'nurse',
        route: RouteKind.associateDegree,
        customSteps: <CustomStep>[step],
      ),
    );
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(
      const Session().copyWith(workspace: a),
      const Session().copyWith(workspace: b),
    );
    expect(const Session().copyWith(workspace: a).hasProgress, isTrue);
  });

  test('route kinds know which need a degree and which pay while training', () {
    expect(RouteKind.bachelorsDegree.requiresDegree, isTrue);
    expect(RouteKind.associateDegree.requiresDegree, isFalse);
    expect(RouteKind.apprenticeship.paidWhileTraining, isTrue);
    expect(RouteKind.certificate.paidWhileTraining, isFalse);
    expect(RouteKind.fromSlug('apprenticeship'), RouteKind.apprenticeship);
    final slugs = RouteKind.values.map((kind) => kind.slug).toSet();
    expect(slugs, hasLength(RouteKind.values.length));
  });

  test('labour statistics must carry labour-market evidence', () {
    expect(
      () => LaborStats(
        socCode: '15-1252',
        evidence: const Evidence(kind: EvidenceKind.editorial),
      ),
      throwsA(isA<AssertionError>()),
    );
  });

  test('a wide spread is flagged when the top tenth earns twice the bottom',
      () {
    final evidence = Evidence(
      kind: EvidenceKind.laborMarketData,
      source: 'Test',
      asOf: DateTime.utc(2024, 5),
    );
    expect(
      LaborStats(
        socCode: 'x',
        evidence: evidence,
        lowAnnualWage: 40000,
        highAnnualWage: 85000,
      ).hasWideSpread,
      isTrue,
    );
    expect(
      LaborStats(
        socCode: 'x',
        evidence: evidence,
        lowAnnualWage: 40000,
        highAnnualWage: 60000,
      ).hasWideSpread,
      isFalse,
    );
    expect(LaborStats(socCode: 'x', evidence: evidence).hasWideSpread, isFalse);
  });

  test('evidence older than about eighteen months is stale', () {
    final evidence = Evidence(
      kind: EvidenceKind.laborMarketData,
      source: 'Test',
      asOf: DateTime.utc(2024, 5),
    );
    expect(evidence.isStaleAt(DateTime.utc(2025, 5)), isFalse);
    expect(evidence.isStaleAt(DateTime.utc(2026, 5)), isTrue);
    expect(
      const Evidence(kind: EvidenceKind.editorial)
          .isStaleAt(DateTime.utc(2030)),
      isFalse,
    );
  });
}

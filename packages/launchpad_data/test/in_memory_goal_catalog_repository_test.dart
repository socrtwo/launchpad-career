import 'package:launchpad_data/launchpad_data.dart';
import 'package:launchpad_domain/launchpad_domain.dart';
import 'package:test/test.dart';

void main() {
  const repository = InMemoryGoalCatalogRepository();

  test('exposes exactly one goal per GoalId, in declaration order', () async {
    final goals = await repository.primaryGoals();
    expect(goals.map((goal) => goal.id), GoalId.values);
  });

  test('every goal has a description and a described next step', () async {
    for (final goal in await repository.primaryGoals()) {
      expect(goal.title, isNotEmpty);
      expect(goal.description, isNotEmpty);
      expect(goal.nextStep, isNotEmpty);
    }
  });

  test('no goal copy promises an outcome', () async {
    final banned = RegExp(
      r'\b(guarantee[ds]?|guaranteed|ensures? you get|will land you)\b',
      caseSensitive: false,
    );
    for (final goal in await repository.primaryGoals()) {
      expect(
          banned.hasMatch('${goal.title} ${goal.description} ${goal.nextStep}'),
          isFalse,
          reason: 'outcome promise in ${goal.id.slug}');
    }
  });

  test('lookup by id works and misses return null', () async {
    final goal = await repository.goalById(GoalId.interviewPreparation);
    expect(goal?.title, 'Prepare for interviews');
  });

  test('session repository broadcasts updates', () async {
    final sessions = InMemorySessionRepository();
    expect(sessions.current().selectedGoal, isNull);
    final future = sessions.watch().firstWhere(
          (session) => session.selectedGoal == GoalId.direction,
        );
    await sessions.update(const Session(selectedGoal: GoalId.direction));
    expect((await future).selectedGoal, GoalId.direction);
    await sessions.dispose();
  });
}

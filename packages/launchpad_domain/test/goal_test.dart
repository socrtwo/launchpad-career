import 'package:launchpad_domain/launchpad_domain.dart';
import 'package:test/test.dart';

void main() {
  group('GoalId', () {
    test('slugs are unique and URL-safe', () {
      final slugs = GoalId.values.map((id) => id.slug).toList();
      expect(slugs.toSet(), hasLength(slugs.length));
      for (final slug in slugs) {
        expect(slug, matches(RegExp(r'^[a-z0-9-]+$')));
      }
    });

    test('round-trips through fromSlug', () {
      for (final id in GoalId.values) {
        expect(GoalId.fromSlug(id.slug), id);
      }
      expect(GoalId.fromSlug(null), isNull);
      expect(GoalId.fromSlug('not-a-goal'), isNull);
    });
  });

  group('Evidence', () {
    test('labour-market claims must carry a source and a date', () {
      expect(
        () => Evidence(kind: EvidenceKind.laborMarketData),
        throwsA(isA<AssertionError>()),
      );
      expect(
        Evidence(
          kind: EvidenceKind.laborMarketData,
          source: 'BLS OEWS',
          asOf: DateTime(2025, 5),
        ).isGenerated,
        isFalse,
      );
    });

    test('generated guidance is flagged', () {
      const evidence = Evidence(kind: EvidenceKind.generatedGuidance);
      expect(evidence.isGenerated, isTrue);
    });
  });

  group('Session', () {
    test('is anonymous until a preferred name is given', () {
      const session = Session();
      expect(session.isAnonymous, isTrue);
      expect(session.copyWith(preferredName: 'Sam').isAnonymous, isFalse);
    });

    test('can clear the selected goal', () {
      const session = Session(selectedGoal: GoalId.direction);
      expect(session.copyWith(clearSelectedGoal: true).selectedGoal, isNull);
    });
  });
}

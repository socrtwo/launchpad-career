import 'dart:convert';

import 'package:launchpad_data/launchpad_data.dart';
import 'package:launchpad_domain/launchpad_domain.dart';
import 'package:test/test.dart';

void main() {
  final filled = Session(
    selectedGoal: GoalId.internshipOrJob,
    freeTextPrompt: 'I have two offers and cannot choose.',
    onboardingStatus: OnboardingStatus.inProgress,
    onboardingStep: OnboardingStep.interests,
    profile: const Profile().copyWith(
      preferredName: 'Sam',
      educationLevel: EducationLevel.someCollege,
      plannedEducation: PlannedEducation.bachelors,
      interests: <InterestArea>{InterestArea.data, InterestArea.teaching},
      priorities: <Priority>{Priority.stability},
    ),
  );

  group('SessionCodec', () {
    test('round-trips everything except the free text', () {
      final decoded = SessionCodec.decode(SessionCodec.encode(filled));
      expect(decoded, filled.copyWith(freeTextPrompt: null));
    });

    test('includes the free text only when asked to', () {
      expect(
        jsonEncode(SessionCodec.encode(filled)),
        isNot(contains('two offers')),
      );
      expect(
        jsonEncode(SessionCodec.encode(filled, includeFreeText: true)),
        contains('two offers'),
      );
    });

    test('writes slugs, never enum indexes', () {
      final json = SessionCodec.encode(filled);
      expect(json['goal'], 'internship-or-job');
      expect((json['profile']! as Map)['educationLevel'], 'some-college');
      expect((json['onboarding']! as Map)['step'], 'interests');
    });

    test('drops values it does not recognise instead of failing', () {
      final decoded = SessionCodec.decode(<String, Object?>{
        'goal': 'no-such-goal',
        'onboarding': <String, Object?>{'status': 'mystery', 'step': 7},
        'profile': <String, Object?>{
          'educationLevel': 'kindergarten',
          'interests': <Object?>['data', 'juggling', 3],
          'priorities': 'not-a-list',
        },
      });
      expect(decoded.selectedGoal, isNull);
      expect(decoded.onboardingStatus, OnboardingStatus.notStarted);
      expect(decoded.onboardingStep, isNull);
      expect(decoded.profile.educationLevel, isNull);
      expect(decoded.profile.interests, <InterestArea>{InterestArea.data});
      expect(decoded.profile.priorities, isEmpty);
    });

    test('never restores more priorities than can be chosen', () {
      final decoded = SessionCodec.decode(<String, Object?>{
        'profile': <String, Object?>{
          'priorities': Priority.values.map((item) => item.slug).toList(),
        },
      });
      expect(decoded.profile.priorities, hasLength(Priority.maxChoices));
    });
  });

  group('PersistentSessionRepository', () {
    test('writes nothing at all before the person opts in', () async {
      final store = InMemoryKeyValueStore();
      final repository = PersistentSessionRepository(store);

      await repository.update(filled);

      expect(repository.storageEnabled, isFalse);
      expect(repository.current(), filled);
      expect(store.snapshot, isEmpty);
    });

    test('opting in stores the session and it survives a restart', () async {
      final store = InMemoryKeyValueStore();
      final first = PersistentSessionRepository(store);
      await first.update(filled);
      await first.enableStorage();

      final second = PersistentSessionRepository(store);
      expect(second.storageEnabled, isTrue);
      expect(second.current(), filled.copyWith(freeTextPrompt: null));
      expect(second.lastSavedAt, isNotNull);
    });

    test('later changes are saved once storage is on', () async {
      final store = InMemoryKeyValueStore();
      final repository = PersistentSessionRepository(store);
      await repository.enableStorage();
      await repository.update(filled);

      expect(
        PersistentSessionRepository(store).current().selectedGoal,
        GoalId.internshipOrJob,
      );
    });

    test('the free text never reaches the store', () async {
      final store = InMemoryKeyValueStore();
      final repository = PersistentSessionRepository(store);
      await repository.enableStorage();
      await repository.update(filled);

      expect(store.snapshot.values.join(), isNot(contains('two offers')));
    });

    test('only the owned keys are ever written', () async {
      final store = InMemoryKeyValueStore();
      final repository = PersistentSessionRepository(store);
      await repository.enableStorage();
      await repository.update(filled);

      expect(store.snapshot.keys, isNotEmpty);
      expect(
        store.snapshot.keys.toSet().difference(
              PersistentSessionRepository.ownedKeys,
            ),
        isEmpty,
      );
    });

    test('turning storage off erases the stored copy but keeps working',
        () async {
      final store = InMemoryKeyValueStore();
      final repository = PersistentSessionRepository(store);
      await repository.update(filled);
      await repository.enableStorage();

      await repository.disableStorage();

      expect(store.snapshot, isEmpty);
      expect(repository.storageEnabled, isFalse);
      expect(repository.current(), filled);

      await repository.update(filled.copyWith(selectedGoal: GoalId.direction));
      expect(store.snapshot, isEmpty);
    });

    test('delete everything clears the store and the session in memory',
        () async {
      final store = InMemoryKeyValueStore();
      final repository = PersistentSessionRepository(store);
      await repository.update(filled);
      await repository.enableStorage();

      await repository.deleteEverything();

      expect(store.snapshot, isEmpty);
      expect(repository.storageEnabled, isFalse);
      expect(repository.current(), const Session());
      expect(PersistentSessionRepository(store).current(), const Session());
    });

    test('a stored copy past the retention period is erased, not loaded',
        () async {
      final store = InMemoryKeyValueStore();
      var now = DateTime.utc(2026, 1, 1);
      final first = PersistentSessionRepository(store, clock: () => now);
      await first.enableStorage();
      await first.update(filled);

      now = DateTime.utc(2027, 1, 3);
      final second = PersistentSessionRepository(store, clock: () => now);
      await Future<void>.delayed(Duration.zero);

      expect(second.current(), const Session());
      expect(
        store.read(PersistentSessionRepository.sessionKey),
        isNull,
      );
    });

    test('a copy inside the retention period is loaded', () async {
      final store = InMemoryKeyValueStore();
      var now = DateTime.utc(2026, 1, 1);
      final first = PersistentSessionRepository(store, clock: () => now);
      await first.enableStorage();
      await first.update(filled);

      now = DateTime.utc(2026, 12, 1);
      final second = PersistentSessionRepository(store, clock: () => now);
      expect(second.current().selectedGoal, GoalId.internshipOrJob);
    });

    test('a stored session without an opt-in on record is erased', () async {
      final store = InMemoryKeyValueStore(<String, String>{
        PersistentSessionRepository.sessionKey: jsonEncode(<String, Object?>{
          'savedAt': DateTime.utc(2026).toIso8601String(),
          'session': SessionCodec.encode(filled),
        }),
      });

      final repository = PersistentSessionRepository(store);
      await Future<void>.delayed(Duration.zero);

      expect(repository.current(), const Session());
      expect(store.snapshot, isEmpty);
    });

    test('an opt-in to older wording does not carry over', () async {
      final store = InMemoryKeyValueStore(<String, String>{
        PersistentSessionRepository.consentKey:
            '{"storage":"granted","at":"2025-01-01T00:00:00Z","version":"old"}',
        PersistentSessionRepository.sessionKey: jsonEncode(<String, Object?>{
          'savedAt': DateTime.utc(2026).toIso8601String(),
          'session': SessionCodec.encode(filled),
        }),
      });

      final repository = PersistentSessionRepository(store);
      await Future<void>.delayed(Duration.zero);

      expect(repository.storageEnabled, isFalse);
      expect(repository.current(), const Session());
      expect(store.snapshot, isEmpty);
    });

    test('a corrupt stored copy is discarded without throwing', () async {
      final store = InMemoryKeyValueStore(<String, String>{
        PersistentSessionRepository.consentKey:
            '{"storage":"granted","at":"2026-01-01T00:00:00Z","version":"${PersistentSessionRepository.consentVersion}"}',
        PersistentSessionRepository.sessionKey: '{not json',
      });

      final repository = PersistentSessionRepository(store);
      expect(repository.storageEnabled, isTrue);
      expect(repository.current(), const Session());
    });

    test('export holds everything, including text that is never stored',
        () async {
      final repository = PersistentSessionRepository(InMemoryKeyValueStore());
      await repository.update(filled);

      final export =
          jsonDecode(repository.exportData()) as Map<String, Object?>;
      expect(export['format'], 'launchpad-career-export');
      expect(export['keptOnThisDevice'], isFalse);
      final session = export['session']! as Map<String, Object?>;
      expect(
          session['somethingElseText'], 'I have two offers and cannot choose.');
      expect((session['profile']! as Map)['preferredName'], 'Sam');
    });

    test('watch replays the current session to a new listener', () async {
      final repository = PersistentSessionRepository(InMemoryKeyValueStore());
      await repository.update(filled);
      expect(await repository.watch().first, filled);
      await repository.dispose();
    });
  });
}

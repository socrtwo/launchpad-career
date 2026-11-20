import 'package:launchpad_domain/launchpad_domain.dart';
import 'package:test/test.dart';

void main() {
  group('ResumeBulletCheck', () {
    test('a specific, measured bullet raises nothing', () {
      expect(
        ResumeBulletCheck.check(
          'Rebuilt the club sign-up form, cutting drop-offs from 40 to 12 a term',
        ),
        isEmpty,
      );
    });

    test('flags a duty-style opening', () {
      expect(
        ResumeBulletCheck.check('Responsible for 3 weekly inventory counts'),
        <BulletIssue>[BulletIssue.weakOpening],
      );
      expect(
        ResumeBulletCheck.check('- Helped organise 2 campus events'),
        contains(BulletIssue.weakOpening),
      );
    });

    test('flags first-person wording but not words that contain it', () {
      expect(
        ResumeBulletCheck.check('I trained 4 new volunteers on the till'),
        contains(BulletIssue.firstPerson),
      );
      expect(
        ResumeBulletCheck.check('Improved media coverage across 4 outlets'),
        isNot(contains(BulletIssue.firstPerson)),
      );
    });

    test('flags a bullet with no number', () {
      expect(
        ResumeBulletCheck.check('Trained new volunteers on the till system'),
        <BulletIssue>[BulletIssue.noMeasure],
      );
    });

    test('flags very long and very short bullets', () {
      expect(
        ResumeBulletCheck.check(List<String>.filled(40, 'word').join(' ')),
        contains(BulletIssue.tooLong),
      );
      expect(ResumeBulletCheck.check('Sold shoes'), <BulletIssue>[
        BulletIssue.tooShort,
      ]);
    });

    test('ignores blank input', () {
      expect(ResumeBulletCheck.check('   '), isEmpty);
      expect(ResumeBulletCheck.check('• '), isEmpty);
    });
  });

  group('Workspace tool state', () {
    test('choices are set, replaced and cleared', () {
      var workspace = const Workspace().withChoice(
        Workspace.searchHoursKey,
        SearchHours.steady.slug,
      );
      expect(workspace.searchHours, SearchHours.steady);
      workspace = workspace.withChoice(Workspace.searchHoursKey, null);
      expect(workspace.searchHours, isNull);
      expect(workspace.isEmpty, isTrue);
    });

    test('skill levels are kept per occupation and skill', () {
      final workspace = const Workspace()
          .withChoice(Workspace.skillKey('nurse', 0), SkillLevel.canShow.slug)
          .withChoice(Workspace.skillKey('nurse', 2), SkillLevel.notYet.slug);
      expect(workspace.skillLevel('nurse', 0), SkillLevel.canShow);
      expect(workspace.skillLevel('nurse', 1), isNull);
      expect(workspace.skillLevel('nurse', 2), SkillLevel.notYet);
      expect(workspace.skillLevel('electrician', 0), isNull);
    });

    test('notes are trimmed, capped, and blank clears them', () {
      final key = Workspace.interviewNoteKey('strength', ExamplePart.action);
      expect(key, 'interview/strength/action');
      var workspace = const Workspace().withNote(key, '  Ran the rota.  ');
      expect(workspace.notes[key], 'Ran the rota.');
      workspace = workspace.withNote(key, 'x' * 5000);
      expect(workspace.notes[key], hasLength(Workspace.maxNoteLength));
      workspace = workspace.withNote(key, '   ');
      expect(workspace.notes, isEmpty);
    });

    test('new notes are refused once the limit is reached', () {
      var workspace = const Workspace();
      for (var i = 0; i < Workspace.maxNotes; i++) {
        workspace = workspace.withNote('n/$i', 'note');
      }
      final full = workspace.withNote('n/extra', 'note');
      expect(full.notes, hasLength(Workspace.maxNotes));
      expect(full.withNote('n/0', 'changed').notes['n/0'], 'changed');
    });

    test('closing a search week clears its ticks and note and counts it', () {
      final workspace = const Workspace()
          .toggleDone(Workspace.searchTaskKey('apply'))
          .toggleDone(Workspace.resumeKey('education'))
          .withNote(Workspace.searchNoteKey, 'Two replies.')
          .withChoice(Workspace.searchHoursKey, SearchHours.light.slug);

      final closed = workspace.withSearchWeekClosed();

      expect(closed.searchWeeksCompleted, 1);
      expect(closed.isDone(Workspace.searchTaskKey('apply')), isFalse);
      expect(closed.isDone(Workspace.resumeKey('education')), isTrue);
      expect(closed.notes, isEmpty);
      expect(closed.searchHours, SearchHours.light);
      expect(closed.withSearchWeekClosed().searchWeeksCompleted, 2);
    });

    test('counts what is done under a prefix', () {
      final workspace = const Workspace()
          .toggleDone(Workspace.resumeKey('education'))
          .toggleDone(Workspace.resumeKey('skills'))
          .toggleDone(Workspace.linkedInKey('headline'));
      expect(workspace.doneUnder('resume/'), 2);
      expect(workspace.doneUnder('linkedin/'), 1);
      expect(workspace.doneUnder('interview/'), 0);
    });

    test('saved bullets come back in order', () {
      final workspace = const Workspace()
          .withNote(Workspace.resumeBulletKey(1), 'Second')
          .withNote(Workspace.resumeBulletKey(0), 'First');
      expect(workspace.savedBullets, <String>['First', 'Second']);
    });

    test('stored enums have unique slugs', () {
      for (final slugs in <Iterable<String>>[
        SkillLevel.values.map((value) => value.slug),
        SearchHours.values.map((value) => value.slug),
        ExamplePart.values.map((value) => value.slug),
        QuestionCategory.values.map((value) => value.slug),
      ]) {
        expect(slugs.toSet(), hasLength(slugs.length));
      }
    });
  });
}

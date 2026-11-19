import 'dart:convert';

import 'package:launchpad_data/launchpad_data.dart';
import 'package:launchpad_domain/launchpad_domain.dart';
import 'package:test/test.dart';

final RegExp outcomePromise = RegExp(
  r"\b(guarantee[ds]?|guaranteed|ensures? you get|will land you|land the job|"
  r"you will get (the|a) job|sure to|certain to|will get you hired)\b",
  caseSensitive: false,
);

final RegExp bareFigure = RegExp(r'[$£€]\s?\d|\d\s?%|\d{2,}[,.]\d{3}');

/// Wording that labels the reader instead of describing a situation.
final RegExp labelsReader = RegExp(
  r"\b(don't worry|you've got this|if you're feeling|anxious|confused|lost)\b",
  caseSensitive: false,
);

void main() {
  const repository = InMemoryGuidanceRepository();

  void expectClean(String text, String where) {
    expect(outcomePromise.hasMatch(text), isFalse, reason: '$where: "$text"');
    expect(bareFigure.hasMatch(text), isFalse, reason: '$where: "$text"');
    expect(labelsReader.hasMatch(text), isFalse, reason: '$where: "$text"');
  }

  test('guides have unique section ids and specific points', () async {
    for (final sections in <List<GuideItem>>[
      await repository.resumeSections(),
      await repository.linkedInSections(),
    ]) {
      expect(sections, hasLength(greaterThanOrEqualTo(6)));
      final ids = sections.map((section) => section.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
      for (final section in sections) {
        expect(section.points, hasLength(inInclusiveRange(2, 3)));
        expectClean(section.title, section.id);
        for (final point in section.points) {
          expectClean(point, section.id);
        }
      }
    }
  });

  test('the question bank covers every category with unique ids', () async {
    final questions = await repository.interviewQuestions();
    final ids = questions.map((question) => question.id).toList();
    expect(ids.toSet(), hasLength(ids.length));
    for (final category in QuestionCategory.values) {
      expect(
        questions.where((question) => question.category == category),
        isNotEmpty,
        reason: category.slug,
      );
    }
    for (final question in questions) {
      expect(question.prompt, isNotEmpty);
      expect(question.tips, hasLength(2));
      expectClean(question.prompt, question.id);
      expectClean(question.purpose, question.id);
      for (final tip in question.tips) {
        expectClean(tip, question.id);
      }
    }
    expect(questions.where((question) => question.usesExample), isNotEmpty);
    expect(questions.where((question) => !question.usesExample), isNotEmpty);
  });

  test('a search week scales with the time available and keeps its shape',
      () async {
    final light = await repository.searchWeek(SearchHours.light);
    final intensive = await repository.searchWeek(SearchHours.intensive);
    expect(
      light.map((task) => task.id),
      intensive.map((task) => task.id),
    );
    int count(List<SearchTask> week, String id) =>
        week.firstWhere((task) => task.id == id).count!;
    expect(count(light, 'apply'), lessThan(count(intensive, 'apply')));
    expect(count(light, 'talk'), lessThan(count(intensive, 'talk')));
    for (final task in light) {
      expectClean('${task.title} ${task.detail}', task.id);
    }
  });

  test('tool guidance is labelled as a draft', () {
    expect(repository.evidence.kind, EvidenceKind.generatedGuidance);
  });

  group('SessionCodec with tool state', () {
    final session = const Session().copyWith(
      workspace: const Workspace()
          .withChoice(Workspace.searchHoursKey, SearchHours.steady.slug)
          .withChoice(Workspace.skillKey('electrician', 1), 'building')
          .withNote(
            Workspace.interviewNoteKey('teamwork', ExamplePart.action),
            'Rewrote the rota so nobody closed twice in a row.',
          )
          .toggleDone(Workspace.resumeKey('education')),
    );

    test('round-trips choices and notes', () {
      expect(SessionCodec.decode(SessionCodec.encode(session)), session);
    });

    test('notes are part of what is stored after opt-in and of the export',
        () async {
      final store = InMemoryKeyValueStore();
      final repository = PersistentSessionRepository(store);
      await repository.update(session);
      expect(store.snapshot, isEmpty);
      expect(repository.exportData(), contains('Rewrote the rota'));

      await repository.enableStorage();
      expect(
        store.snapshot[PersistentSessionRepository.sessionKey],
        contains('Rewrote the rota'),
      );

      await repository.deleteEverything();
      expect(store.snapshot, isEmpty);
      expect(repository.exportData(), isNot(contains('Rewrote the rota')));
    });

    test('drops malformed entries and enforces the limits on load', () {
      final decoded = SessionCodec.decode(<String, Object?>{
        'workspace': <String, Object?>{
          'choices': <String, Object?>{
            'search/hours': 'steady',
            'bad': 7,
            '': 'empty-key',
            'long': 'x' * 500,
          },
          'notes': <String, Object?>{
            for (var i = 0; i < Workspace.maxNotes + 50; i++) 'n/$i': 'note $i',
            'blank': '   ',
            'huge': 'y' * 5000,
          },
        },
      });
      expect(decoded.workspace.searchHours, SearchHours.steady);
      expect(decoded.workspace.choices.containsKey('bad'), isFalse);
      expect(decoded.workspace.choices.containsKey(''), isFalse);
      expect(decoded.workspace.choices['long'], hasLength(64));
      expect(decoded.workspace.notes, hasLength(Workspace.maxNotes));
      for (final note in decoded.workspace.notes.values) {
        expect(note.length, lessThanOrEqualTo(Workspace.maxNoteLength));
      }
    });

    test('writes keys in a stable order', () {
      final a = jsonEncode(SessionCodec.encode(session));
      final b = jsonEncode(
        SessionCodec.encode(SessionCodec.decode(SessionCodec.encode(session))),
      );
      expect(a, b);
    });
  });
}

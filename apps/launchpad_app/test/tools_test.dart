import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:launchpad_app/src/app/providers.dart';
import 'package:launchpad_app/src/features/explore/explore_page.dart';
import 'package:launchpad_app/src/features/explore/plan_page.dart';
import 'package:launchpad_app/src/features/tools/guide_pages.dart';
import 'package:launchpad_app/src/features/tools/interview_page.dart';
import 'package:launchpad_app/src/features/tools/progress_page.dart';
import 'package:launchpad_app/src/features/tools/search_plan_page.dart';
import 'package:launchpad_app/src/features/tools/skills_page.dart';
import 'package:launchpad_app/src/features/tools/tools_page.dart';
import 'package:launchpad_app/src/routing/app_router.dart';
import 'package:launchpad_data/launchpad_data.dart';
import 'package:launchpad_domain/launchpad_domain.dart';
import 'package:launchpad_ui/launchpad_ui.dart';

import 'helpers.dart';

Workspace workspaceOf(WidgetTester tester) =>
    containerOf(tester).read(sessionProvider).workspace;

String visibleText(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((text) => text.data ?? '')
    .join('\n');

void main() {
  group('tools index', () {
    testWidgets('lists every tool and each one opens', (tester) async {
      await pumpApp(tester);
      await tapVisible(tester, find.widgetWithText(TextButton, 'All tools'));
      expect(find.byType(ToolsPage), findsOneWidget);
      expect(find.byType(SecondaryChoiceTile), findsNWidgets(10));

      final destinations = <String, Type>{
        'Weekly job-search plan': SearchPlanPage,
        'Resume guide': ResumePage,
        'LinkedIn profile guide': LinkedInPage,
        'Interview practice': InterviewPage,
        'Skills plan': SkillsPage,
        'Your progress': ProgressPage,
        'Browse occupations': ExplorePage,
      };
      for (final entry in destinations.entries) {
        await goTo(tester, Routes.tools);
        await tapVisible(tester, find.text(entry.key));
        expect(find.byType(entry.value), findsOneWidget, reason: entry.key);
      }
    });
  });

  group('job-search plan', () {
    testWidgets('a week appears once the time available is chosen',
        (tester) async {
      await pumpApp(tester);
      await goTo(tester, Routes.searchPlan);

      expect(find.text('This week'), findsNothing);
      expect(find.textContaining('not a benchmark'), findsOneWidget);

      await tapVisible(tester, find.text('A few hours'));
      expect(find.text('This week'), findsOneWidget);
      expect(find.text('0 of 5 done'), findsOneWidget);
      expect(find.text('Send tailored applications: 2'), findsOneWidget);

      await tapVisible(tester, find.text('Several days'));
      expect(find.text('Send tailored applications: 6'), findsOneWidget);
      expect(workspaceOf(tester).searchHours, SearchHours.intensive);
    });

    testWidgets('finishing a week clears it and counts it', (tester) async {
      await pumpApp(tester);
      await goTo(tester, Routes.searchPlan);
      await tapVisible(tester, find.text('A few hours'));
      await tapVisible(tester, find.text('Send tailored applications: 2'));
      expect(find.text('1 of 5 done'), findsOneWidget);

      await tester.ensureVisible(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'Two replies.');
      await tester.pumpAndSettle();
      expect(
        workspaceOf(tester).notes[Workspace.searchNoteKey],
        'Two replies.',
      );

      await tapVisible(
        tester,
        find.text('Finish this week and start the next'),
      );

      expect(workspaceOf(tester).searchWeeksCompleted, 1);
      expect(workspaceOf(tester).doneUnder('search/week/'), 0);
      expect(workspaceOf(tester).notes, isEmpty);
      expect(find.text('1 week finished.'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Two replies.'), findsNothing);
    });

    testWidgets('names saved occupations as the roles aimed at',
        (tester) async {
      await pumpApp(tester);
      await goTo(tester, Routes.searchPlan);
      expect(
        find.textContaining('You have not saved any occupations yet'),
        findsOneWidget,
      );

      containerOf(tester)
          .read(sessionProvider.notifier)
          .toggleSaved('paralegal');
      await tester.pumpAndSettle();
      expect(find.text('Paralegal'), findsOneWidget);
    });
  });

  group('resume guide', () {
    testWidgets('sections can be ticked off and the count follows',
        (tester) async {
      await pumpApp(tester);
      await goTo(tester, Routes.resumeGuide);

      expect(find.text('0 of 6 done'), findsOneWidget);
      await tapVisible(tester, find.widgetWithText(OptionTile, 'Education'));
      expect(find.text('1 of 6 done'), findsOneWidget);
      expect(workspaceOf(tester).isDone('resume/education'), isTrue);
    });

    testWidgets('never asks for the resume itself', (tester) async {
      await pumpApp(tester);
      await goTo(tester, Routes.resumeGuide);
      expect(
        find.textContaining('Nothing here asks you to upload or paste'),
        findsOneWidget,
      );
    });

    testWidgets('the wording check explains what it found and its limits',
        (tester) async {
      await pumpApp(tester);
      await goTo(tester, Routes.resumeGuide);

      expect(
        find.textContaining('finding nothing is not a seal of approval'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.byType(TextField));
      await tester.enterText(
        find.byType(TextField),
        'Responsible for helping my manager with the till',
      );
      await tapVisible(tester, find.text('Check wording'));

      expect(
        find.textContaining('opens with a phrase that describes a duty'),
        findsOneWidget,
      );
      expect(find.textContaining('uses "I", "my" or "me"'), findsOneWidget);
      expect(find.textContaining('It has no number'), findsOneWidget);
      expect(workspaceOf(tester).notes, isEmpty, reason: 'checked, not kept');
    });

    testWidgets('a clean line says only that no pattern was found',
        (tester) async {
      await pumpApp(tester);
      await goTo(tester, Routes.resumeGuide);
      await tester.ensureVisible(find.byType(TextField));
      await tester.enterText(
        find.byType(TextField),
        'Trained 4 new volunteers to run the till on weekend shifts',
      );
      await tapVisible(tester, find.text('Check wording'));
      expect(
        find.text('None of the patterns this looks for were found.'),
        findsOneWidget,
      );
    });

    testWidgets('a line is kept only when asked, and can be removed',
        (tester) async {
      await pumpApp(tester);
      await goTo(tester, Routes.resumeGuide);
      const line = 'Trained 4 new volunteers to run the till';
      await tester.ensureVisible(find.byType(TextField));
      await tester.enterText(find.byType(TextField), line);
      await tapVisible(tester, find.text('Keep this line'));

      expect(find.text('Line kept.'), findsOneWidget);
      expect(workspaceOf(tester).savedBullets, <String>[line]);
      expect(find.text('Lines you kept'), findsOneWidget);

      await tapVisible(tester, find.byTooltip('Remove line: $line'));
      expect(workspaceOf(tester).savedBullets, isEmpty);
    });
  });

  group('LinkedIn guide', () {
    testWidgets('is a checklist that says it is independent', (tester) async {
      await pumpApp(tester);
      await goTo(tester, Routes.linkedIn);

      expect(find.text('0 of 7 done'), findsOneWidget);
      await tapVisible(tester, find.widgetWithText(OptionTile, 'Headline'));
      expect(find.text('1 of 7 done'), findsOneWidget);
      expect(
        find.textContaining('does not connect to LinkedIn'),
        findsOneWidget,
      );
      expect(
        find.textContaining('not affiliated with or endorsed by LinkedIn'),
        findsOneWidget,
      );
    });
  });

  group('interview practice', () {
    testWidgets('lists questions by kind and opens one', (tester) async {
      await pumpApp(tester);
      await goTo(tester, Routes.interview);

      expect(find.text('0 of 12 questions practised'), findsOneWidget);
      expect(find.text('Examples from your experience'), findsOneWidget);
      await tapVisible(
        tester,
        find.text('Tell me about a time you worked as part of a team.'),
      );

      expect(find.text('What it is asking'), findsOneWidget);
      expect(find.text('Your example'), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(4));
    });

    testWidgets('notes are kept as typed and survive leaving the page',
        (tester) async {
      await pumpApp(tester);
      await goTo(tester, Routes.interviewQuestion('teamwork'));

      final action = find.widgetWithText(TextField, 'Action: what you did');
      await tester.ensureVisible(action);
      await tester.enterText(action, 'Rewrote the rota.');
      await tester.pumpAndSettle();
      expect(
        workspaceOf(tester).notes['interview/teamwork/action'],
        'Rewrote the rota.',
      );

      await goTo(tester, Routes.interview);
      await goTo(tester, Routes.interviewQuestion('teamwork'));
      expect(
        find.widgetWithText(TextField, 'Rewrote the rota.'),
        findsOneWidget,
      );
    });

    testWidgets('a question can be marked practised and the list shows it',
        (tester) async {
      await pumpApp(tester);
      await goTo(tester, Routes.interviewQuestion('why-role'));
      expect(find.byType(TextField), findsOneWidget);

      await tapVisible(tester, find.text('Mark as practised'));
      expect(find.text('Mark as not practised'), findsOneWidget);
      expect(workspaceOf(tester).isDone('interview/why-role'), isTrue);

      await tapVisible(
        tester,
        find.widgetWithText(OutlinedButton, 'Back to the questions'),
      );
      expect(find.text('1 of 12 questions practised'), findsOneWidget);
      expect(find.text('Practised'), findsOneWidget);
    });

    testWidgets('an unknown question explains itself', (tester) async {
      await pumpApp(tester);
      await goTo(tester, Routes.interviewQuestion('riddle'));
      expect(
        find.text('That question link is not one we recognise.'),
        findsOneWidget,
      );
    });

    testWidgets('each question tile says what it opens and its state',
        (tester) async {
      final handle = tester.ensureSemantics();
      await pumpApp(tester);
      await goTo(tester, Routes.interview);
      final data = tester
          .getSemantics(
            find.bySemanticsLabel('Open question: Why do you want this role?'),
          )
          .getSemanticsData();
      expect(data.value, 'Not yet practised');
      expect(data.flagsCollection.isButton, isTrue);
      handle.dispose();
    });
  });

  group('skills plan', () {
    testWidgets('choose an occupation, rate its skills, see what to work on',
        (tester) async {
      await pumpApp(tester);
      await goTo(tester, Routes.skills);
      expect(find.text('Which occupation?'), findsOneWidget);

      await tapVisible(tester, find.widgetWithText(OptionTile, 'Electrician'));
      expect(find.text('Skills for: Electrician'), findsOneWidget);
      expect(find.text('0 of 4 skills rated'), findsOneWidget);
      expect(
        find.textContaining('Rate the skills above'),
        findsOneWidget,
      );

      await tapVisible(tester, find.text('I can show this').first);
      await tapVisible(tester, find.text('Not yet').at(1));
      expect(find.text('2 of 4 skills rated'), findsOneWidget);
      expect(
        workspaceOf(tester).skillLevel('electrician', 0),
        SkillLevel.canShow,
      );
      expect(
        workspaceOf(tester).skillLevel('electrician', 1),
        SkillLevel.notYet,
      );
      expect(
        find.text(
          'Pick one small project that would let you show: Safe working '
          'practice.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('says so when every skill is one the person can show',
        (tester) async {
      await pumpApp(tester);
      final session = containerOf(tester).read(sessionProvider.notifier);
      for (var i = 0; i < 4; i++) {
        session.setChoice(
          Workspace.skillKey('electrician', i),
          SkillLevel.canShow.slug,
        );
      }
      await goTo(tester, Routes.skillsFor('electrician'));
      expect(
        find.textContaining('You marked every skill as one you can show'),
        findsOneWidget,
      );
    });

    testWidgets('it is framed as a self-estimate, not a test', (tester) async {
      await pumpApp(tester);
      await goTo(tester, Routes.skillsFor('electrician'));
      expect(find.textContaining('it is not a test'), findsOneWidget);
      final text = visibleText(tester);
      expect(text, isNot(contains('%')));
      expect(text.toLowerCase(), isNot(contains('score')));
    });

    testWidgets('saved occupations are offered first', (tester) async {
      await pumpApp(tester);
      containerOf(tester).read(sessionProvider.notifier).toggleSaved('plumber');
      await goTo(tester, Routes.skills);
      final first = tester.widget<OptionTile>(find.byType(OptionTile).first);
      expect(first.label, 'Plumber or pipefitter');
    });
  });

  group('progress', () {
    testWidgets('an empty record invites action', (tester) async {
      await pumpApp(tester);
      await tapVisible(
        tester,
        find.widgetWithText(TextButton, 'Your progress'),
      );
      expect(find.byType(ProgressPage), findsOneWidget);
      expect(find.textContaining('Nothing yet.'), findsOneWidget);
      expect(find.textContaining('no scores and no streaks'), findsOneWidget);
    });

    testWidgets('summarises every tool in words and links to each',
        (tester) async {
      await pumpApp(tester);
      containerOf(tester).read(sessionProvider.notifier)
        ..updateProfile(
          const Profile().copyWith(
            interests: <InterestArea>{InterestArea.building},
            educationLevel: EducationLevel.highSchool,
          ),
        )
        ..toggleSaved('electrician')
        ..setPlanRoute('electrician', RouteKind.apprenticeship)
        ..toggleDone('plan/electrician/apprenticeship/apply')
        ..setChoice(Workspace.searchHoursKey, SearchHours.light.slug)
        ..toggleDone(Workspace.searchTaskKey('apply'))
        ..toggleDone(Workspace.resumeKey('education'))
        ..toggleDone(Workspace.resumeKey('skills'))
        ..toggleDone(Workspace.linkedInKey('headline'))
        ..toggleDone(Workspace.interviewKey('teamwork'));
      await goTo(tester, Routes.progress);

      expect(find.text('2 of 5 answered'), findsOneWidget);
      expect(find.text('1 saved'), findsOneWidget);
      expect(find.text('Plan: Electrician'), findsOneWidget);
      expect(find.text('1 of 5 steps done'), findsOneWidget);
      expect(
        find.text('No weeks finished yet. This week: 1 of 5 done'),
        findsOneWidget,
      );
      expect(find.text('2 of 6 done'), findsOneWidget);
      expect(find.text('1 of 7 done'), findsOneWidget);
      expect(find.text('1 of 12 questions practised'), findsOneWidget);
      expect(find.textContaining('Nothing yet.'), findsNothing);

      final open = find.bySemanticsLabel('Open: Plan: Electrician');
      await tester.ensureVisible(open);
      await tester.pumpAndSettle();
      await tester.tap(open);
      await tester.pumpAndSettle();
      expect(find.byType(PlanPage), findsOneWidget);
    });

    testWidgets('carries no score, streak or percentage', (tester) async {
      await pumpApp(tester);
      containerOf(tester)
          .read(sessionProvider.notifier)
          .toggleDone(Workspace.resumeKey('education'));
      await goTo(tester, Routes.progress);
      final text = visibleText(tester);
      expect(text, isNot(contains('%')));
      expect(text.toLowerCase(), isNot(contains('points')));
      expect(text.toLowerCase(), isNot(contains('day streak')));
    });
  });

  group('storage', () {
    testWidgets('tool state is stored only after opting in, and is exported',
        (tester) async {
      final store = InMemoryKeyValueStore();
      await pumpApp(tester, store: store);
      containerOf(tester).read(sessionProvider.notifier)
        ..toggleDone(Workspace.resumeKey('education'))
        ..setNote('interview/teamwork/action', 'Rewrote the rota.')
        ..keepBullet('Trained 4 new volunteers');
      await tester.pumpAndSettle();
      expect(store.snapshot, isEmpty);

      final local = containerOf(tester).read(storageEnabledProvider.notifier);
      expect(local.exportData(), contains('Rewrote the rota.'));
      await local.enable();
      await tester.pumpAndSettle();
      final stored = store.snapshot[PersistentSessionRepository.sessionKey]!;
      expect(stored, contains('Rewrote the rota.'));
      expect(stored, contains('Trained 4 new volunteers'));
      expect(stored, contains('resume/education'));

      await local.deleteEverything();
      await tester.pumpAndSettle();
      expect(store.snapshot, isEmpty);
      expect(workspaceOf(tester).isEmpty, isTrue);
    });
  });

  group('every tool', () {
    final pages = <String, String>{
      'tools index': Routes.tools,
      'job-search plan': Routes.searchPlan,
      'resume guide': Routes.resumeGuide,
      'LinkedIn guide': Routes.linkedIn,
      'interview list': Routes.interview,
      'interview question': Routes.interviewQuestion('teamwork'),
      'skills chooser': Routes.skills,
      'skills ratings': Routes.skillsFor('electrician'),
      'progress': Routes.progress,
    };

    Future<void> prepare(WidgetTester tester) async {
      containerOf(tester).read(sessionProvider.notifier)
        ..toggleSaved('electrician')
        ..setPlanRoute('electrician', RouteKind.apprenticeship)
        ..setChoice(Workspace.searchHoursKey, SearchHours.steady.slug)
        ..toggleDone(Workspace.searchTaskKey('apply'))
        ..toggleDone(Workspace.resumeKey('education'))
        ..toggleDone(Workspace.linkedInKey('headline'))
        ..toggleDone(Workspace.interviewKey('strength'))
        ..keepBullet('Trained 4 new volunteers to run the till')
        ..setChoice(Workspace.skillKey('electrician', 0), 'can-show')
        ..setChoice(Workspace.skillKey('electrician', 1), 'not-yet');
      await tester.pumpAndSettle();
    }

    for (final entry in pages.entries) {
      testWidgets('${entry.key} meets the guidelines in both themes',
          (tester) async {
        for (final brightness in Brightness.values) {
          final handle = tester.ensureSemantics();
          await pumpApp(tester, platformBrightness: brightness);
          await prepare(tester);
          await goTo(tester, entry.value);

          await expectMeetsGuidelines(tester);
          handle.dispose();
          await tester.pumpWidget(const SizedBox());
        }
      });

      testWidgets('${entry.key} survives 2x text on a phone', (tester) async {
        await pumpApp(
          tester,
          surfaceSize: const Size(360, 740),
          textScaleFactor: 2.0,
        );
        await prepare(tester);
        await goTo(tester, entry.value);
        expect(tester.takeException(), isNull);
      });

      testWidgets('${entry.key} labels its guidance and promises nothing',
          (tester) async {
        await pumpApp(tester);
        await prepare(tester);
        await goTo(tester, entry.value);
        // The standing disclaimer uses the word it disclaims, so it is taken
        // out before scanning for promises.
        final text = visibleText(tester).replaceAll(
          'Launchpad Career offers guidance, not guarantees about admission, '
              'hiring, or pay.',
          '',
        );
        expect(
          RegExp(
            r'\b(guarantee|will land you|land the job|sure to|certain to)',
            caseSensitive: false,
          ).hasMatch(text),
          isFalse,
        );
        if (entry.value != Routes.tools && entry.value != Routes.progress) {
          expect(text, contains('drafted with AI assistance'));
        }
      });
    }
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:launchpad_app/src/app/providers.dart';
import 'package:launchpad_app/src/features/explore/compare_page.dart';
import 'package:launchpad_app/src/features/explore/explore_page.dart';
import 'package:launchpad_app/src/features/explore/occupation_page.dart';
import 'package:launchpad_app/src/features/explore/occupation_widgets.dart';
import 'package:launchpad_app/src/features/explore/plan_page.dart';
import 'package:launchpad_app/src/features/explore/saved_page.dart';
import 'package:launchpad_app/src/features/explore/suggestions_page.dart';
import 'package:launchpad_app/src/features/onboarding/onboarding_page.dart';
import 'package:launchpad_app/src/routing/app_router.dart';
import 'package:launchpad_data/launchpad_data.dart';
import 'package:launchpad_domain/launchpad_domain.dart';
import 'package:launchpad_ui/launchpad_ui.dart';

import 'helpers.dart';

Workspace workspaceOf(WidgetTester tester) =>
    containerOf(tester).read(sessionProvider).workspace;

/// All text currently in the tree, for scanning.
String visibleText(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((text) => text.data ?? '')
    .join('\n');

final Profile dataAndCare = const Profile().copyWith(
  interests: <InterestArea>{InterestArea.data, InterestArea.caring},
  educationLevel: EducationLevel.someCollege,
  plannedEducation: PlannedEducation.associate,
  priorities: <Priority>{Priority.shortTraining, Priority.stability},
);

void main() {
  group('browse', () {
    testWidgets('lists the whole catalogue with a count', (tester) async {
      await pumpApp(tester);
      await tapVisible(
        tester,
        find.widgetWithText(TextButton, 'Browse occupations'),
      );

      expect(find.byType(ExplorePage), findsOneWidget);
      expect(
        find.text('${bundledOccupations.length} occupations'),
        findsOneWidget,
      );
      expect(find.text('Accountant or auditor'), findsOneWidget);
    });

    testWidgets('search narrows by every word and can be cleared',
        (tester) async {
      await pumpApp(tester);
      await goTo(tester, Routes.explore);

      await tester.enterText(find.byType(TextField), 'wind turbine');
      await tester.pumpAndSettle();
      expect(find.text('1 occupation'), findsOneWidget);
      expect(find.text('Wind turbine technician'), findsOneWidget);
      expect(find.text('Accountant or auditor'), findsNothing);

      await tester.tap(find.byTooltip('Clear search'));
      await tester.pumpAndSettle();
      expect(
        find.text('${bundledOccupations.length} occupations'),
        findsOneWidget,
      );
    });

    testWidgets('filters narrow by kind of work', (tester) async {
      await pumpApp(tester);
      await goTo(tester, Routes.explore);

      await tapVisible(tester, find.text('Outdoor and physical work'));
      await tapVisible(tester, find.text('Science and research'));

      final expected = bundledOccupations
          .where(
            (item) => item.interests.containsAll(<InterestArea>{
              InterestArea.outdoors,
              InterestArea.science,
            }),
          )
          .length;
      expect(find.text('$expected occupations'), findsOneWidget);
      expect(find.text('Accountant or auditor'), findsNothing);
    });

    testWidgets('an empty result says what to do and offers to clear',
        (tester) async {
      await pumpApp(tester);
      await goTo(tester, Routes.explore);

      await tester.enterText(find.byType(TextField), 'zzzz');
      await tester.pumpAndSettle();
      expect(find.text('No occupations match.'), findsOneWidget);
      expect(find.textContaining('Try fewer words'), findsOneWidget);

      await tapVisible(tester, find.text('Clear search and filters'));
      expect(
        find.text('${bundledOccupations.length} occupations'),
        findsOneWidget,
      );
    });
  });

  group('occupation page', () {
    testWidgets('shows the work, the ways in and the skills', (tester) async {
      await pumpApp(tester);
      await goTo(tester, Routes.occupation('electrician'));

      expect(find.byType(OccupationPage), findsOneWidget);
      expect(find.text('Electrician'), findsOneWidget);
      expect(find.text('What the work involves'), findsOneWidget);
      expect(find.text('Ways in'), findsOneWidget);
      expect(find.text('Registered apprenticeship'), findsOneWidget);
      expect(find.text('Paid apprenticeship'), findsOneWidget);
      expect(find.text('Skills commonly asked for'), findsOneWidget);
      expect(
        find.text('Standard Occupational Classification 2018: 47-2111, '
            'Electricians.'),
        findsOneWidget,
      );
    });

    testWidgets('labels the description as an unreviewed AI-assisted draft',
        (tester) async {
      await pumpApp(tester);
      await goTo(tester, Routes.occupation('electrician'));

      expect(
        find.textContaining('drafted with AI assistance in November 2026'),
        findsOneWidget,
      );
      expect(
        find.textContaining('not yet been reviewed by a careers adviser'),
        findsOneWidget,
      );
    });

    testWidgets('shows no pay number when no figures are loaded',
        (tester) async {
      await pumpApp(tester);
      await goTo(tester, Routes.occupation('electrician'));

      expect(
        find.textContaining('Pay figures are not loaded in this build'),
        findsOneWidget,
      );
      expect(visibleText(tester), isNot(contains(r'$')));
    });

    testWidgets('pay figures carry their source, period and caveats',
        (tester) async {
      await pumpApp(
        tester,
        laborMarket: testSnapshot(),
        now: DateTime.utc(2025, 3),
      );
      await goTo(tester, Routes.occupation('electrician'));

      expect(
        find.textContaining(
          r'median annual pay for this occupation in the United States was '
          r'$61,000 in May 2024',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining(r'less than $39,000'),
        findsOneWidget,
      );
      expect(find.textContaining('wide spread'), findsOneWidget);
      expect(
        find.textContaining('About 712,345 jobs were counted in May 2024'),
        findsOneWidget,
      );
      expect(
        find.text('Source: Test Statistics Office, May 2024.'),
        findsOneWidget,
      );
      expect(
        find.textContaining('not a prediction of what you would be paid'),
        findsOneWidget,
      );
      expect(find.textContaining('more than 18 months old'), findsNothing);
    });

    testWidgets('a narrow spread is not called wide', (tester) async {
      await pumpApp(
        tester,
        laborMarket: testSnapshot(),
        now: DateTime.utc(2025, 3),
      );
      await goTo(tester, Routes.occupation('plumber'));
      expect(find.textContaining(r'$60,000'), findsOneWidget);
      expect(find.textContaining('wide spread'), findsNothing);
    });

    testWidgets('old figures carry a staleness warning', (tester) async {
      await pumpApp(
        tester,
        laborMarket: testSnapshot(),
        now: DateTime.utc(2026, 6),
      );
      await goTo(tester, Routes.occupation('electrician'));
      expect(
        find.textContaining('more than 18 months old'),
        findsOneWidget,
      );
    });

    testWidgets('an occupation without a figure says so', (tester) async {
      await pumpApp(tester, laborMarket: testSnapshot());
      await goTo(tester, Routes.occupation('paralegal'));
      expect(
        find.text(
          'The publisher did not release a pay figure for this occupation.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('an unknown link explains itself and offers a way on',
        (tester) async {
      await pumpApp(tester);
      await goTo(tester, Routes.occupation('astronaut'));
      expect(
        find.text('That occupation link is not one we recognise.'),
        findsOneWidget,
      );
      await tapVisible(
        tester,
        find.widgetWithText(FilledButton, 'Browse occupations'),
      );
      expect(find.byType(ExplorePage), findsOneWidget);
    });
  });

  group('saved options', () {
    testWidgets('saving announces itself and fills the saved page',
        (tester) async {
      await pumpApp(tester);
      await goTo(tester, Routes.saved);
      expect(find.textContaining('Nothing saved yet'), findsOneWidget);

      await tapVisible(
        tester,
        find.widgetWithText(FilledButton, 'Browse occupations'),
      );
      await tester.enterText(find.byType(TextField), 'electrician');
      await tester.pumpAndSettle();
      await tapVisible(tester, find.widgetWithText(OutlinedButton, 'Save'));

      expect(find.text('Saved: Electrician'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Saved'), findsOneWidget);
      expect(workspaceOf(tester).savedOccupations, <String>{'electrician'});

      await goTo(tester, Routes.saved);
      expect(find.byType(SavedPage), findsOneWidget);
      expect(find.text('Electrician'), findsOneWidget);

      await tapVisible(tester, find.widgetWithText(OutlinedButton, 'Saved'));
      expect(workspaceOf(tester).savedOccupations, isEmpty);
      expect(find.textContaining('Nothing saved yet'), findsOneWidget);
    });

    testWidgets('saved options are stored only after opting in',
        (tester) async {
      final store = InMemoryKeyValueStore();
      await pumpApp(tester, store: store);
      await goTo(tester, Routes.occupation('electrician'));
      await tapVisible(tester, find.widgetWithText(OutlinedButton, 'Save'));
      expect(store.snapshot, isEmpty);

      await containerOf(tester).read(storageEnabledProvider.notifier).enable();
      await tester.pumpAndSettle();
      expect(
        store.snapshot[PersistentSessionRepository.sessionKey],
        contains('"saved":["electrician"]'),
      );
    });

    testWidgets('the save control says what it will do to which occupation',
        (tester) async {
      final handle = tester.ensureSemantics();
      await pumpApp(tester);
      await goTo(tester, Routes.occupation('electrician'));

      expect(find.bySemanticsLabel('Save Electrician'), findsOneWidget);
      await tapVisible(tester, find.widgetWithText(OutlinedButton, 'Save'));
      expect(
        find.bySemanticsLabel('Remove Electrician from saved options'),
        findsOneWidget,
      );
      handle.dispose();
    });
  });

  group('compare', () {
    testWidgets('puts the chosen occupations side by side on a wide window',
        (tester) async {
      await pumpApp(tester);
      await goTo(tester, Routes.compare(<String>['electrician', 'plumber']));

      expect(find.byType(ComparePage), findsOneWidget);
      final left = tester.getTopLeft(find.text('Electrician').first);
      final right = tester.getTopLeft(find.text('Plumber or pipefitter').first);
      expect(left.dy, right.dy);
      expect(right.dx, greaterThan(left.dx + 200));
      expect(find.text('Ways in'), findsOneWidget);
      expect(find.text('What the work involves'), findsOneWidget);
    });

    testWidgets('stacks on a phone and names the occupation in every cell',
        (tester) async {
      await pumpApp(tester, surfaceSize: const Size(390, 844));
      await goTo(tester, Routes.compare(<String>['electrician', 'plumber']));

      final first = tester.getTopLeft(find.text('Electrician').first);
      final second =
          tester.getTopLeft(find.text('Plumber or pipefitter').first);
      expect(second.dx, first.dx);
      expect(second.dy, greaterThan(first.dy));
      // Once as the column heading, once per compared row.
      expect(find.text('Electrician'), findsAtLeastNWidgets(4));
    });

    testWidgets('asks for a second occupation when only one is chosen',
        (tester) async {
      await pumpApp(tester);
      await goTo(tester, Routes.occupation('electrician'));
      await tapVisible(tester, find.text('Compare with others'));

      expect(
        find.text('Choose at least two occupations to compare.'),
        findsOneWidget,
      );
      await tapVisible(tester, find.widgetWithText(OptionTile, 'Paralegal'));
      expect(
        find.text('Choose at least two occupations to compare.'),
        findsNothing,
      );
      expect(find.text('2 selected'), findsOneWidget);
    });

    testWidgets('stops at three and says why', (tester) async {
      await pumpApp(tester);
      await goTo(
        tester,
        Routes.compare(<String>['electrician', 'plumber', 'paralegal']),
      );
      await tapVisible(tester, find.text('Choose occupations to compare'));
      await tapVisible(tester, find.widgetWithText(OptionTile, 'Logistician'));

      expect(
        find.text(
          'You can compare up to three at a time. Remove one to add another.',
        ),
        findsOneWidget,
      );
      expect(find.byType(ComparePage), findsOneWidget);
      expect(
        tester.widget<ComparePage>(find.byType(ComparePage)).ids,
        <String>['electrician', 'plumber', 'paralegal'],
      );
    });

    testWidgets('ignores unknown and repeated ids in the link', (tester) async {
      await pumpApp(tester);
      await goTo(tester, '/compare?ids=electrician,electrician,nope,plumber');
      expect(
        tester.widget<ComparePage>(find.byType(ComparePage)).ids,
        <String>['electrician', 'nope', 'plumber'],
      );
      expect(find.text('Ways in'), findsOneWidget);
      expect(find.text('nope'), findsNothing);
    });

    testWidgets('pay row appears only with figures, with one source line',
        (tester) async {
      await pumpApp(tester);
      await goTo(tester, Routes.compare(<String>['electrician', 'plumber']));
      expect(find.text('Pay'), findsNothing);
      expect(
        find.textContaining('Pay figures are not loaded'),
        findsOneWidget,
      );

      await tester.pumpWidget(const SizedBox());
      await pumpApp(
        tester,
        laborMarket: testSnapshot(),
        now: DateTime.utc(2025, 3),
      );
      await goTo(tester, Routes.compare(<String>['electrician', 'plumber']));
      expect(find.text('Pay'), findsOneWidget);
      expect(find.text(r'Median $61,000 a year (May 2024)'), findsOneWidget);
      expect(
        find.text('Source: Test Statistics Office, May 2024.'),
        findsOneWidget,
      );
    });

    testWidgets('saved options can be compared in one press', (tester) async {
      await pumpApp(tester);
      final session = containerOf(tester).read(sessionProvider.notifier)
        ..toggleSaved('electrician')
        ..toggleSaved('plumber');
      expect(session, isNotNull);
      await goTo(tester, Routes.saved);
      await tapVisible(tester, find.text('Compare saved options'));
      expect(
        tester.widget<ComparePage>(find.byType(ComparePage)).ids.toSet(),
        <String>{'electrician', 'plumber'},
      );
    });
  });

  group('suggestions', () {
    testWidgets('ask for interests before suggesting anything', (tester) async {
      await pumpApp(tester);
      await goTo(tester, Routes.suggestions);

      expect(find.byType(SuggestionsPage), findsOneWidget);
      expect(
        find.textContaining('we need to know what kinds of work interest you'),
        findsOneWidget,
      );
      await tapVisible(tester, find.text('Answer the interests question'));
      expect(find.byType(OnboardingPage), findsOneWidget);
      expect(find.text('What kinds of work interest you?'), findsOneWidget);
    });

    testWidgets('every suggestion states its reasons in the person\'s terms',
        (tester) async {
      await pumpApp(tester);
      await setProfile(tester, dataAndCare);
      await goTo(tester, Routes.suggestions);

      expect(find.textContaining('fixed rules'), findsOneWidget);
      expect(find.textContaining('not a prediction'), findsWidgets);
      final cards = find.byType(OccupationCard).evaluate().length;
      expect(cards, inInclusiveRange(2, Recommender.defaultLimit));
      expect(find.text('Why this is here'), findsNWidgets(cards));
      expect(
        find.textContaining('You said you are interested in'),
        findsAtLeastNWidgets(cards),
      );
      expect(
        find.textContaining('A way in to look at first:'),
        findsNWidgets(cards),
      );
    });

    testWidgets('confidence is in words and no percentage appears',
        (tester) async {
      await pumpApp(tester);
      await setProfile(tester, dataAndCare);
      await goTo(tester, Routes.suggestions);

      expect(find.textContaining('match'), findsWidgets);
      final text = visibleText(tester);
      expect(text, isNot(contains('%')));
      expect(text, isNot(contains('percent')));
    });

    testWidgets('says which priorities were not used and why', (tester) async {
      await pumpApp(tester);
      await setProfile(
        tester,
        dataAndCare.copyWith(
          priorities: <Priority>{Priority.earnings, Priority.stability},
        ),
      );
      await goTo(tester, Routes.suggestions);

      await tester.scrollUntilVisible(
        find.textContaining('Not used: Steady, predictable work'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.textContaining('Not used: Steady, predictable work'),
        findsOneWidget,
      );
      expect(
        find.textContaining('pay figures are not loaded in this build'),
        findsOneWidget,
      );
    });

    testWidgets('pay is a reason only with figures, and names its source',
        (tester) async {
      await pumpApp(
        tester,
        laborMarket: testSnapshot(),
        now: DateTime.utc(2025, 3),
      );
      await setProfile(
        tester,
        const Profile().copyWith(
          interests: <InterestArea>{InterestArea.technology},
          priorities: <Priority>{Priority.earnings},
        ),
      );
      await goTo(tester, Routes.suggestions);

      final reason = find.textContaining(
        r'reported median pay was $130,000 in May 2024, above the median for '
        r'all occupations ($50,000). Source: Test Statistics Office.',
      );
      await tester.scrollUntilVisible(
        reason,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(reason, findsOneWidget);
    });

    testWidgets('the answers behind the list are one press from editable',
        (tester) async {
      await pumpApp(tester);
      await setProfile(tester, dataAndCare);
      await goTo(tester, Routes.suggestions);
      await tapVisible(tester, find.text('Change your answers'));
      expect(find.text('Check your answers'), findsOneWidget);
    });

    testWidgets('the list is labelled as built on draft content',
        (tester) async {
      await pumpApp(tester);
      await setProfile(tester, dataAndCare);
      await goTo(tester, Routes.suggestions);
      final label = find.textContaining('drafted with AI assistance');
      await tester.scrollUntilVisible(
        label,
        400,
        scrollable: find.byType(Scrollable).first,
      );
      expect(label, findsOneWidget);
    });
  });

  group('plans', () {
    testWidgets('choosing a way in produces steps that can be ticked off',
        (tester) async {
      await pumpApp(tester);
      await goTo(tester, Routes.occupation('electrician'));
      await tapVisible(tester, find.text('Start a plan'));

      expect(find.byType(PlanPage), findsOneWidget);
      expect(find.text('Your plan: Electrician'), findsOneWidget);
      expect(find.text('Steps'), findsNothing);

      await tapVisible(
        tester,
        find.text('Registered apprenticeship (Paid apprenticeship)'),
      );
      expect(find.text('0 of 5 steps done'), findsOneWidget);

      await tapVisible(
        tester,
        find.text('Find apprenticeship sponsors in your area'),
      );
      expect(find.text('1 of 5 steps done'), findsOneWidget);
      expect(
        workspaceOf(tester).isDone(
          'plan/electrician/apprenticeship/find-sponsors',
        ),
        isTrue,
      );
    });

    testWidgets('a person can add, complete and remove their own step',
        (tester) async {
      await pumpApp(tester);
      await goTo(tester, Routes.plan('electrician'));
      await tapVisible(
        tester,
        find.text('Registered apprenticeship (Paid apprenticeship)'),
      );

      await tester.ensureVisible(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'Call the union local');
      await tapVisible(tester, find.text('Add step'));

      expect(find.text('Step added.'), findsOneWidget);
      expect(find.text('Call the union local'), findsOneWidget);
      expect(
        workspaceOf(tester).plans['electrician']!.customSteps.single.text,
        'Call the union local',
      );

      await tapVisible(tester, find.text('Call the union local'));
      expect(find.text('1 of 6 steps done'), findsOneWidget);

      await tapVisible(
        tester,
        find.byTooltip('Remove step: Call the union local'),
      );
      expect(find.text('Call the union local'), findsNothing);
      expect(workspaceOf(tester).completed, isEmpty);
    });

    testWidgets('a blank step is not added', (tester) async {
      await pumpApp(tester);
      await goTo(tester, Routes.plan('electrician'));
      await tapVisible(
        tester,
        find.text('Registered apprenticeship (Paid apprenticeship)'),
      );
      await tester.ensureVisible(find.byType(TextField));
      await tester.enterText(find.byType(TextField), '   ');
      await tapVisible(tester, find.text('Add step'));
      expect(workspaceOf(tester).plans['electrician']!.customSteps, isEmpty);
    });

    testWidgets('removing a plan clears its steps and progress',
        (tester) async {
      await pumpApp(tester);
      await goTo(tester, Routes.plan('electrician'));
      await tapVisible(
        tester,
        find.text('Registered apprenticeship (Paid apprenticeship)'),
      );
      await tapVisible(
        tester,
        find.text('Find apprenticeship sponsors in your area'),
      );
      await tapVisible(tester, find.text('Remove this plan'));

      expect(workspaceOf(tester).plans, isEmpty);
      expect(workspaceOf(tester).completed, isEmpty);
      expect(find.text('Steps'), findsNothing);
    });

    testWidgets('the saved page summarises plan progress', (tester) async {
      await pumpApp(tester);
      containerOf(tester).read(sessionProvider.notifier)
        ..toggleSaved('electrician')
        ..setPlanRoute('electrician', RouteKind.apprenticeship)
        ..toggleDone('plan/electrician/apprenticeship/find-sponsors')
        ..toggleDone('plan/electrician/apprenticeship/apply');
      await goTo(tester, Routes.saved);

      expect(find.text('Plan: 2 of 5 steps done'), findsOneWidget);
      await tapVisible(tester, find.text('Open your plan'));
      expect(find.byType(PlanPage), findsOneWidget);
    });

    testWidgets('steps a person writes are stored only after opting in',
        (tester) async {
      final store = InMemoryKeyValueStore();
      await pumpApp(tester, store: store);
      final session = containerOf(tester).read(sessionProvider.notifier)
        ..setPlanRoute('electrician', RouteKind.apprenticeship);
      expect(
        session.addCustomStep('electrician', 'Call the union local'),
        isTrue,
      );
      await tester.pumpAndSettle();
      expect(store.snapshot, isEmpty);

      await containerOf(tester).read(storageEnabledProvider.notifier).enable();
      await tester.pumpAndSettle();
      expect(
        store.snapshot[PersistentSessionRepository.sessionKey],
        contains('Call the union local'),
      );
    });
  });

  group('goal pages', () {
    testWidgets('a goal with tools links to them instead of describing plans',
        (tester) async {
      await pumpApp(tester);
      await goTo(tester, Routes.goalFor(GoalId.direction));

      expect(find.text('Start here'), findsOneWidget);
      expect(find.text('What happens next'), findsNothing);
      await tapVisible(tester, find.text('Suggestions from your answers'));
      expect(find.byType(SuggestionsPage), findsOneWidget);
    });

    testWidgets('a goal without tools still says they are planned',
        (tester) async {
      await pumpApp(tester);
      await goTo(tester, Routes.goalFor(GoalId.interviewPreparation));
      expect(find.text('What happens next'), findsOneWidget);
      expect(find.textContaining('planned, not yet built'), findsOneWidget);
    });
  });

  group('accessibility', () {
    final pages = <String, String>{
      'browse': Routes.explore,
      'occupation': Routes.occupation('software-developer'),
      'compare': Routes.compare(<String>['electrician', 'plumber']),
      'compare picker': Routes.compare(<String>['electrician']),
      'saved': Routes.saved,
      'suggestions': Routes.suggestions,
      'plan': Routes.plan('electrician'),
    };

    Future<void> prepare(WidgetTester tester) async {
      await setProfile(tester, dataAndCare);
      containerOf(tester).read(sessionProvider.notifier)
        ..toggleSaved('electrician')
        ..toggleSaved('registered-nurse')
        ..setPlanRoute('electrician', RouteKind.apprenticeship)
        ..addCustomStep('electrician', 'Call the union local')
        ..toggleDone('plan/electrician/apprenticeship/find-sponsors');
      await tester.pumpAndSettle();
    }

    for (final entry in pages.entries) {
      testWidgets('${entry.key} meets the guidelines in both themes',
          (tester) async {
        for (final brightness in Brightness.values) {
          final handle = tester.ensureSemantics();
          await pumpApp(
            tester,
            platformBrightness: brightness,
            laborMarket: testSnapshot(),
            now: DateTime.utc(2026, 6),
          );
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
          laborMarket: testSnapshot(),
        );
        await prepare(tester);
        await goTo(tester, entry.value);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('section titles are headings', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpApp(tester);
      await goTo(tester, Routes.occupation('electrician'));
      for (final title in <String>['Electrician', 'Ways in', 'Pay']) {
        final data = tester.getSemantics(find.text(title)).getSemanticsData();
        expect(data.flagsCollection.isHeader, isTrue, reason: title);
      }
      handle.dispose();
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:launchpad_app/src/app/providers.dart';
import 'package:launchpad_app/src/features/goal/goal_page.dart';
import 'package:launchpad_app/src/features/home/home_page.dart';
import 'package:launchpad_app/src/features/onboarding/onboarding_page.dart';
import 'package:launchpad_app/src/routing/app_router.dart';
import 'package:launchpad_data/launchpad_data.dart';
import 'package:launchpad_domain/launchpad_domain.dart';
import 'package:launchpad_ui/launchpad_ui.dart';

import 'helpers.dart';

Session sessionOf(WidgetTester tester) => ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    ).read(sessionProvider);

Future<void> pressContinue(WidgetTester tester) =>
    tapVisible(tester, find.widgetWithText(FilledButton, 'Continue'));

void main() {
  testWidgets('walks every question and carries the goal forward',
      (tester) async {
    await pumpApp(tester);
    await chooseGoalAndContinue(tester);

    expect(find.text('Step 1 of 6'), findsOneWidget);
    expect(find.text('What should we call you?'), findsOneWidget);
    expect(find.textContaining('Optional.'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Sam');
    await pressContinue(tester);

    expect(find.text('Step 2 of 6'), findsOneWidget);
    await tapVisible(tester, find.text('Some college, no degree yet'));
    await pressContinue(tester);

    expect(find.text('Are you planning more education?'), findsOneWidget);
    await tapVisible(tester, find.text("A bachelor's degree"));
    await pressContinue(tester);

    expect(find.text('What kinds of work interest you?'), findsOneWidget);
    await tapVisible(tester, find.text('Numbers, data, and analysis'));
    await tapVisible(tester, find.text('Teaching and explaining'));
    expect(find.text('2 selected'), findsOneWidget);
    await pressContinue(tester);

    expect(find.text('Step 5 of 6'), findsOneWidget);
    await tapVisible(tester, find.text('Steady, predictable work'));
    await pressContinue(tester);

    expect(find.text('Check your answers'), findsOneWidget);
    expect(find.text('Help me find an internship or job'), findsOneWidget);
    expect(find.text('Sam'), findsOneWidget);
    expect(find.text('Some college, no degree yet'), findsOneWidget);
    expect(find.text("A bachelor's degree"), findsOneWidget);
    expect(
      find.text('Numbers, data, and analysis, Teaching and explaining'),
      findsOneWidget,
    );
    expect(find.text('Steady, predictable work'), findsOneWidget);

    await tapVisible(tester, find.widgetWithText(FilledButton, 'Finish'));

    expect(find.byType(GoalPage), findsOneWidget);
    final session = sessionOf(tester);
    expect(session.onboardingStatus, OnboardingStatus.completed);
    expect(session.selectedGoal, GoalId.internshipOrJob);
    expect(session.profile.preferredName, 'Sam');
    expect(session.profile.educationLevel, EducationLevel.someCollege);
    expect(session.profile.plannedEducation, PlannedEducation.bachelors);
    expect(
      session.profile.interests,
      <InterestArea>{InterestArea.data, InterestArea.teaching},
    );
    expect(session.profile.priorities, <Priority>{Priority.stability});
  });

  testWidgets('every question can be skipped without answering',
      (tester) async {
    await pumpApp(tester);
    await chooseGoalAndContinue(tester);

    for (var i = 0; i < 5; i++) {
      await tapVisible(tester, find.text('Skip this question'));
    }

    expect(find.text('Check your answers'), findsOneWidget);
    expect(find.text('No answer'), findsNWidgets(5));
    expect(sessionOf(tester).profile.isEmpty, isTrue);
  });

  testWidgets('skipping the questions is remembered and never asked again',
      (tester) async {
    await pumpApp(tester);
    await chooseGoalAndContinue(tester);
    await tapVisible(tester, find.text('Skip the questions'));
    expect(find.byType(GoalPage), findsOneWidget);
    expect(sessionOf(tester).onboardingStatus, OnboardingStatus.skipped);

    await tester.tap(find.byTooltip('Back to start'));
    await tester.pumpAndSettle();
    await chooseGoalAndContinue(tester, title: 'Prepare for interviews');

    expect(find.byType(GoalPage), findsOneWidget);
    expect(find.byType(OnboardingPage), findsNothing);
  });

  testWidgets('priorities stop at three and say why', (tester) async {
    await pumpApp(tester);
    await chooseGoalAndContinue(tester);
    for (var i = 0; i < 4; i++) {
      await tapVisible(tester, find.text('Skip this question'));
    }
    expect(find.text('Step 5 of 6'), findsOneWidget);

    await tapVisible(tester, find.text('Higher pay over time'));
    await tapVisible(tester, find.text('Steady, predictable work'));
    await tapVisible(tester, find.text('Room to move up'));
    await tapVisible(tester, find.text('Helping people directly'));

    expect(
      find.text('You can choose up to three. Remove one to add another.'),
      findsOneWidget,
    );
    expect(sessionOf(tester).profile.priorities, hasLength(3));
    expect(
      sessionOf(tester).profile.priorities,
      isNot(contains(Priority.helpingPeople)),
    );

    await tapVisible(tester, find.text('Room to move up'));
    await tapVisible(tester, find.text('Helping people directly'));
    expect(
      sessionOf(tester).profile.priorities,
      contains(Priority.helpingPeople),
    );
  });

  testWidgets('an answer can be changed from the review', (tester) async {
    await pumpApp(tester);
    await chooseGoalAndContinue(tester);
    await tapVisible(tester, find.text('Skip this question'));
    await tapVisible(tester, find.text('Associate degree'));
    await pressContinue(tester);
    for (var i = 0; i < 3; i++) {
      await tapVisible(tester, find.text('Skip this question'));
    }
    expect(find.text('Associate degree'), findsOneWidget);

    await tapVisible(tester, find.text('Change education so far'));
    expect(find.text('Step 2 of 6'), findsOneWidget);
    await tapVisible(tester, find.text("Bachelor's degree"));

    expect(sessionOf(tester).profile.educationLevel, EducationLevel.bachelors);

    // Tapping the chosen answer again clears it: no answer is a valid answer.
    await tapVisible(tester, find.text("Bachelor's degree"));
    expect(sessionOf(tester).profile.educationLevel, isNull);
  });

  testWidgets('Back returns to the previous question and keeps the name',
      (tester) async {
    await pumpApp(tester);
    await chooseGoalAndContinue(tester);
    await tester.enterText(find.byType(TextField), 'Sam');
    await pressContinue(tester);
    await tapVisible(tester, find.widgetWithText(OutlinedButton, 'Back'));

    expect(find.text('Step 1 of 6'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Sam'), findsOneWidget);
  });

  testWidgets('the home screen offers to resume at the question reached',
      (tester) async {
    await pumpApp(tester);
    expect(find.text('Pick up where you left off'), findsNothing);

    await chooseGoalAndContinue(tester);
    await tester.enterText(find.byType(TextField), 'Sam');
    await pressContinue(tester);
    await tapVisible(tester, find.text('Skip this question'));
    expect(find.text('Step 3 of 6'), findsOneWidget);

    await tester.tap(find.byTooltip('Back to start'));
    await tester.pumpAndSettle();
    expect(find.byType(HomePage), findsOneWidget);
    expect(find.text('Pick up where you left off'), findsOneWidget);
    expect(find.textContaining('Welcome back, Sam.'), findsOneWidget);
    expect(
      find.textContaining('Your goal: Help me find an internship or job'),
      findsOneWidget,
    );
    expect(
      find.textContaining('You have answered 1 of 5 questions.'),
      findsOneWidget,
    );

    await tapVisible(tester, find.text('Continue where you left off'));
    expect(find.text('Step 3 of 6'), findsOneWidget);
  });

  testWidgets('a deep link to a question works without choosing a goal',
      (tester) async {
    await pumpApp(tester);
    ProviderScope.containerOf(tester.element(find.byType(MaterialApp)))
        .read(routerProvider)
        .go('/onboarding/plans');
    await tester.pumpAndSettle();

    expect(find.text('Are you planning more education?'), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      await tapVisible(tester, find.text('Skip this question'));
    }
    expect(find.text('No goal chosen yet'), findsOneWidget);
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Finish'));
    expect(find.byType(HomePage), findsOneWidget);
  });

  testWidgets('an unknown question link falls back to the first question',
      (tester) async {
    await pumpApp(tester);
    ProviderScope.containerOf(tester.element(find.byType(MaterialApp)))
        .read(routerProvider)
        .go('/onboarding/shoe-size');
    await tester.pumpAndSettle();
    expect(find.text('Step 1 of 6'), findsOneWidget);
  });

  testWidgets('answers are saved only after the person opts in',
      (tester) async {
    final store = InMemoryKeyValueStore();
    await pumpApp(tester, store: store);
    await chooseGoalAndContinue(tester);
    await tester.enterText(find.byType(TextField), 'Sam');
    await pressContinue(tester);
    for (var i = 0; i < 4; i++) {
      await tapVisible(tester, find.text('Skip this question'));
    }
    expect(find.text('Check your answers'), findsOneWidget);
    expect(store.snapshot, isEmpty, reason: 'nothing saved before opting in');

    await tapVisible(tester, find.text('Save on this device'));

    expect(find.text('Saved on this device.'), findsOneWidget);
    expect(
      store.snapshot[PersistentSessionRepository.sessionKey],
      contains('"preferredName":"Sam"'),
    );

    await tapVisible(tester, find.text('Stop saving and erase the saved copy'));
    expect(store.snapshot, isEmpty);
    expect(sessionOf(tester).profile.preferredName, 'Sam');
  });

  testWidgets('a saved session is resumed after a restart', (tester) async {
    final store = InMemoryKeyValueStore();
    final earlier = PersistentSessionRepository(store);
    await earlier.enableStorage();
    await earlier.update(
      Session(
        selectedGoal: GoalId.interviewPreparation,
        onboardingStatus: OnboardingStatus.inProgress,
        onboardingStep: OnboardingStep.interests,
        profile: const Profile().copyWith(preferredName: 'Sam'),
      ),
    );

    await pumpApp(tester, store: store);

    expect(find.text('Pick up where you left off'), findsOneWidget);
    expect(
      find.textContaining('Your goal: Prepare for interviews'),
      findsOneWidget,
    );
    await tapVisible(tester, find.text('Continue where you left off'));
    expect(find.text('What kinds of work interest you?'), findsOneWidget);
  });

  testWidgets('a failed save is explained and the answers are kept',
      (tester) async {
    await pumpApp(tester, store: FailingKeyValueStore());
    await chooseGoalAndContinue(tester);
    for (var i = 0; i < 5; i++) {
      await tapVisible(tester, find.text('Skip this question'));
    }
    await tapVisible(tester, find.text('Save on this device'));

    expect(
      find.textContaining('We could not save your latest change'),
      findsOneWidget,
    );
    expect(sessionOf(tester).selectedGoal, GoalId.internshipOrJob);
  });

  testWidgets('says so when the device cannot save', (tester) async {
    await pumpApp(tester, storageAvailable: false);
    await chooseGoalAndContinue(tester);
    for (var i = 0; i < 5; i++) {
      await tapVisible(tester, find.text('Skip this question'));
    }
    expect(
      find.textContaining('does not allow saving'),
      findsOneWidget,
    );
    expect(find.text('Save on this device'), findsNothing);
  });

  group('accessibility', () {
    for (final step in OnboardingStep.values) {
      testWidgets('${step.slug} meets the guidelines in both themes',
          (tester) async {
        for (final brightness in Brightness.values) {
          final handle = tester.ensureSemantics();
          await pumpApp(tester, platformBrightness: brightness);
          await chooseGoalAndContinue(tester);
          for (var i = 0; i < step.index; i++) {
            await tapVisible(tester, find.text('Skip this question'));
          }
          expect(
            find.text('Step ${step.position} of 6'),
            findsOneWidget,
          );
          // Select something so the selected state is checked for contrast too.
          final tiles = find.byType(OptionTile);
          if (tiles.evaluate().isNotEmpty) {
            await tapVisible(tester, tiles.first);
          }

          await expectLater(tester, meetsGuideline(textContrastGuideline));
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          handle.dispose();
          await tester.pumpWidget(const SizedBox());
        }
      });

      testWidgets('${step.slug} survives 2x text on a phone', (tester) async {
        await pumpApp(
          tester,
          surfaceSize: const Size(360, 740),
          textScaleFactor: 2.0,
        );
        await chooseGoalAndContinue(tester);
        for (var i = 0; i < step.index; i++) {
          await tapVisible(tester, find.text('Skip this question'));
        }
        expect(find.text('Step ${step.position} of 6'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('answers are operable from the keyboard', (tester) async {
      await pumpApp(tester);
      await chooseGoalAndContinue(tester);
      await tapVisible(tester, find.text('Skip this question'));
      expect(find.text('Step 2 of 6'), findsOneWidget);

      OptionTile? focused;
      for (var i = 0; i < 20 && focused == null; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        focused = FocusManager.instance.primaryFocus?.context
            ?.findAncestorWidgetOfExactType<OptionTile>();
      }
      expect(focused, isNotNull, reason: 'no answer received focus');

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(sessionOf(tester).profile.educationLevel, isNotNull);
    });

    testWidgets('the question is a heading and progress is in words',
        (tester) async {
      final handle = tester.ensureSemantics();
      await pumpApp(tester);
      await chooseGoalAndContinue(tester);

      final heading = tester
          .getSemantics(find.text('What should we call you?'))
          .getSemanticsData();
      expect(heading.flagsCollection.isHeader, isTrue);
      expect(find.bySemanticsLabel('Step 1 of 6'), findsOneWidget);
      handle.dispose();
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:launchpad_domain/launchpad_domain.dart';
import 'package:launchpad_ui/launchpad_ui.dart';

import 'helpers.dart';

void main() {
  testWidgets('renders the masthead, question and all six goals',
      (tester) async {
    await pumpApp(tester);

    expect(find.text('Launchpad Career'), findsOneWidget);
    expect(find.text('What can we help you with today?'), findsOneWidget);
    expect(
      find.text(
        'Choose one to start. You can return to the other options anytime.',
      ),
      findsOneWidget,
    );
    expect(find.byType(GoalCard), findsNWidgets(GoalId.values.length));
    expect(find.text('Help me pick a direction'), findsOneWidget);
    expect(find.text('Build skills employers are looking for'), findsOneWidget);
  });

  testWidgets('offers the Something else route without making it a card',
      (tester) async {
    await pumpApp(tester);

    expect(find.text('Something else'), findsOneWidget);
    expect(find.byType(SecondaryChoiceTile), findsOneWidget);
    expect(find.byType(GoalCard), findsNWidgets(6));
  });

  testWidgets('Continue is disabled until something is selected',
      (tester) async {
    await pumpApp(tester);

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Continue'),
    );
    expect(button.onPressed, isNull);

    await tester.tap(find.text('Prepare for interviews'));
    await tester.pumpAndSettle();

    final enabled = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Continue'),
    );
    expect(enabled.onPressed, isNotNull);
  });

  testWidgets('only one card can be selected at a time', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Help me pick a direction'));
    await tester.pumpAndSettle();
    expect(_selectedTitles(tester), <String>['Help me pick a direction']);

    await tester.tap(find.text('Prepare for interviews'));
    await tester.pumpAndSettle();
    expect(_selectedTitles(tester), <String>['Prepare for interviews']);
  });

  testWidgets('tapping the selected card clears the selection', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Help me pick a direction'));
    await tester.pumpAndSettle();
    expect(_selectedTitles(tester), hasLength(1));

    await tester.tap(find.text('Help me pick a direction'));
    await tester.pumpAndSettle();
    expect(_selectedTitles(tester), isEmpty);

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Continue'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('announces the current selection in a live region',
      (tester) async {
    await pumpApp(tester);

    expect(find.textContaining('Selected:'), findsNothing);

    await tester.tap(find.text('Improve my resume and LinkedIn'));
    await tester.pumpAndSettle();

    expect(
      find.text('Selected: Improve my resume and LinkedIn'),
      findsOneWidget,
    );
  });

  testWidgets('descriptions stay hidden until a card is selected',
      (tester) async {
    await pumpApp(tester);

    const description =
        'Practice common questions and develop clear examples from your experience.';
    expect(find.text(description), findsNothing);

    await tester.tap(find.text('Prepare for interviews'));
    await tester.pumpAndSettle();

    expect(find.text(description), findsOneWidget);
  });

  testWidgets('shows a recoverable error when the catalogue fails',
      (tester) async {
    await pumpApp(tester, goalCatalog: const FailingGoalCatalogRepository());

    expect(find.textContaining('could not load'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.byType(GoalCard), findsNothing);
  });

  testWidgets('survives a 2x text scale without overflowing', (tester) async {
    await pumpApp(
      tester,
      surfaceSize: const Size(390, 844),
      textScaleFactor: 2.0,
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(GoalCard), findsWidgets);
  });
}

List<String> _selectedTitles(WidgetTester tester) => tester
    .widgetList<GoalCard>(find.byType(GoalCard))
    .where((card) => card.selected)
    .map((card) => card.goal.title)
    .toList();

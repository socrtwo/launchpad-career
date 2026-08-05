import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:launchpad_app/src/features/goal/goal_page.dart';
import 'package:launchpad_app/src/features/info/info_pages.dart';
import 'package:launchpad_app/src/features/something_else/something_else_page.dart';
import 'package:launchpad_app/src/routing/app_router.dart';
import 'package:launchpad_domain/launchpad_domain.dart';

import 'helpers.dart';

void main() {
  testWidgets('Continue navigates to the selected goal', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Help me find an internship or job'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.byType(GoalPage), findsOneWidget);
    expect(find.text('Help me find an internship or job'), findsWidgets);
    expect(find.text('What happens next'), findsOneWidget);
  });

  testWidgets('Something else opens the open-text flow', (tester) async {
    await pumpApp(tester);

    await tester.ensureVisible(find.text('Something else'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Something else'));
    await tester.pumpAndSettle();

    expect(find.byType(SomethingElsePage), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.textContaining('stays on this device'), findsOneWidget);
  });

  testWidgets('Send is disabled until something is typed, then acknowledges',
      (tester) async {
    await pumpApp(tester);
    await tester.ensureVisible(find.text('Something else'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Something else'));
    await tester.pumpAndSettle();

    final before = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Send'),
    );
    expect(before.onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'I have two offers.');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Send'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Thanks'), findsOneWidget);
  });

  testWidgets('footer links reach the placeholder policy pages',
      (tester) async {
    await pumpApp(tester);

    await tester.ensureVisible(find.text('Privacy'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Privacy'));
    await tester.pumpAndSettle();
    expect(find.byType(PrivacyPage), findsOneWidget);

    await tester.tap(find.byTooltip('Back to start'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Accessibility'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Accessibility'));
    await tester.pumpAndSettle();
    expect(find.byType(AccessibilityPage), findsOneWidget);
  });

  test('goal slugs are stable and unique', () {
    final slugs = GoalId.values.map((id) => id.slug).toList();
    expect(slugs.toSet(), hasLength(slugs.length));
    expect(
      GoalId.fromSlug('interview-preparation'),
      GoalId.interviewPreparation,
    );
    expect(GoalId.fromSlug('nonsense'), isNull);
    expect(Routes.goalFor(GoalId.direction), '/goal?id=direction');
  });
}

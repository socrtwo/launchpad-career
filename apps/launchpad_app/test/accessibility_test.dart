import 'dart:ui' show Tristate;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:launchpad_ui/launchpad_ui.dart';

import 'helpers.dart';

void main() {
  testWidgets('meets the standard accessibility guidelines', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpApp(tester);

    await expectLater(tester, meetsGuideline(textContrastGuideline));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

    handle.dispose();
  });

  testWidgets(
      'cards expose title, description and selected state to '
      'assistive technology', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpApp(tester);

    // The description is in the semantics tree even though it is not painted.
    expect(
      find.bySemanticsLabel(RegExp('Help me pick a direction')),
      findsWidgets,
    );

    final before = tester
        .getSemantics(
          find.bySemanticsLabel(RegExp('Prepare for interviews')).first,
        )
        .getSemanticsData();
    expect(before.flagsCollection.isButton, isTrue);
    expect(before.flagsCollection.isSelected, isNot(Tristate.isTrue));
    expect(before.flagsCollection.isInMutuallyExclusiveGroup, isTrue);
    expect(
      before.hint,
      contains('Practice common questions'),
    );

    await tester.tap(find.text('Prepare for interviews'));
    await tester.pumpAndSettle();

    final after = tester
        .getSemantics(
          find.bySemanticsLabel(RegExp('Prepare for interviews')).first,
        )
        .getSemanticsData();
    expect(after.flagsCollection.isSelected, Tristate.isTrue);

    handle.dispose();
  });

  testWidgets('cards are reachable and activatable from the keyboard',
      (tester) async {
    await pumpApp(tester);

    // Walk focus forward until a GoalCard owns it.
    GoalCard? focused;
    for (var i = 0; i < 40 && focused == null; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      focused = focusedGoalCard(tester);
    }
    expect(focused, isNotNull, reason: 'no goal card received focus');

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    final selected = tester
        .widgetList<GoalCard>(find.byType(GoalCard))
        .where((card) => card.selected)
        .toList();
    expect(selected, hasLength(1));
    expect(selected.single.goal.id, focused!.goal.id);
  });

  testWidgets('space activates a focused card', (tester) async {
    await pumpApp(tester);

    GoalCard? focused;
    for (var i = 0; i < 40 && focused == null; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      focused = focusedGoalCard(tester);
    }
    expect(focused, isNotNull);

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();

    expect(
      tester
          .widgetList<GoalCard>(find.byType(GoalCard))
          .where((card) => card.selected),
      hasLength(1),
    );
  });

  testWidgets('respects reduce-motion by using zero-length animations',
      (tester) async {
    await pumpApp(tester, disableAnimations: true);

    await tester.tap(find.text('Help me pick a direction'));
    // A single frame is enough when animations are disabled.
    await tester.pump();

    expect(
      find.text(
        'Explore career paths that fit your interests, strengths, priorities, and circumstances.',
      ),
      findsOneWidget,
    );
  });
}

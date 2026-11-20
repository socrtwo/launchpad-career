import 'dart:ui' show CheckedState;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:launchpad_core/launchpad_core.dart';
import 'package:launchpad_ui/launchpad_ui.dart';

void main() {
  Widget wrap(Widget child, {ThemeData? theme}) => MaterialApp(
        theme: theme ?? AppTheme.light(),
        home: Scaffold(
          body: Padding(padding: const EdgeInsets.all(16), child: child),
        ),
      );

  testWidgets('announces a single-choice answer as one of a group',
      (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      wrap(
        OptionTile(
          label: 'Associate degree',
          description: 'Usually two years.',
          selected: true,
          onPressed: () {},
        ),
      ),
    );

    final data = tester
        .getSemantics(find.bySemanticsLabel('Associate degree'))
        .getSemanticsData();
    expect(data.flagsCollection.isChecked, CheckedState.isTrue);
    expect(data.flagsCollection.isInMutuallyExclusiveGroup, isTrue);
    expect(data.flagsCollection.isButton, isTrue);
    expect(data.hint, 'Usually two years.');
    handle.dispose();
  });

  testWidgets('announces a choose-any answer as a checkbox', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      wrap(
        OptionTile(
          label: 'Working with data',
          selected: false,
          multiSelect: true,
          onPressed: () {},
        ),
      ),
    );

    final data = tester
        .getSemantics(find.bySemanticsLabel('Working with data'))
        .getSemanticsData();
    expect(data.flagsCollection.isChecked, CheckedState.isFalse);
    expect(data.flagsCollection.isInMutuallyExclusiveGroup, isFalse);
    handle.dispose();
  });

  testWidgets('shows a different indicator when selected, not only a colour',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        Column(
          children: <Widget>[
            OptionTile(label: 'A', selected: true, onPressed: () {}),
            OptionTile(label: 'B', selected: false, onPressed: () {}),
          ],
        ),
      ),
    );
    expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
    expect(find.byIcon(Icons.radio_button_unchecked), findsOneWidget);
  });

  testWidgets('is activated by tap, Enter and Space', (tester) async {
    var presses = 0;
    await tester.pumpWidget(
      wrap(OptionTile(label: 'A', selected: false, onPressed: () => presses++)),
    );

    await tester.tap(find.text('A'));
    expect(presses, 1);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(presses, 2);

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(presses, 3);
  });

  testWidgets('meets tap-target and contrast guidelines in both themes',
      (tester) async {
    for (final theme in <ThemeData>[AppTheme.light(), AppTheme.dark()]) {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        wrap(
          Column(
            children: <Widget>[
              OptionTile(
                label: 'Selected answer',
                description: 'With a description.',
                selected: true,
                onPressed: () {},
              ),
              const SizedBox(height: 8),
              OptionTile(
                label: 'Other answer',
                description: 'With a description.',
                selected: false,
                multiSelect: true,
                onPressed: () {},
              ),
            ],
          ),
          theme: theme,
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    }
  });

  testWidgets('a notice card exposes its title as a heading', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      wrap(const NoticeCard(title: 'What is stored', text: 'Your answers.')),
    );
    final data = tester
        .getSemantics(find.bySemanticsLabel('What is stored'))
        .getSemanticsData();
    expect(data.flagsCollection.isHeader, isTrue);
    handle.dispose();
  });
}

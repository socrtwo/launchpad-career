import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:launchpad_core/launchpad_core.dart';
import 'package:launchpad_ui/launchpad_ui.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: Center(child: child)),
      );

  testWidgets('exposes its description as a hint, not as a second label',
      (tester) async {
    final handle = tester.ensureSemantics();
    var taps = 0;

    await tester.pumpWidget(
      wrap(
        SecondaryChoiceTile(
          title: 'Something else',
          description: 'Tell us what is on your mind.',
          icon: Icons.chat_bubble_outline,
          onPressed: () => taps++,
        ),
      ),
    );

    final data = tester
        .getSemantics(find.bySemanticsLabel('Something else').first)
        .getSemanticsData();
    expect(data.flagsCollection.isButton, isTrue);
    expect(data.hint, 'Tell us what is on your mind.');

    await tester.tap(find.text('Something else'));
    expect(taps, 1);

    handle.dispose();
  });

  testWidgets('meets tap-target and contrast guidelines', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      wrap(
        SizedBox(
          width: 400,
          child: SecondaryChoiceTile(
            title: 'Something else',
            description: 'Tell us what is on your mind.',
            icon: Icons.chat_bubble_outline,
            onPressed: () {},
          ),
        ),
      ),
    );

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    handle.dispose();
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:launchpad_core/launchpad_core.dart';

import 'helpers.dart';

void main() {
  testWidgets('builds in light mode with AA body contrast', (tester) async {
    await pumpApp(tester);

    final theme = Theme.of(tester.element(find.text('Launchpad Career')));
    expect(theme.brightness, Brightness.light);
    expect(
      Contrast.ratio(theme.colorScheme.onSurface, theme.colorScheme.surface),
      greaterThanOrEqualTo(Contrast.aaNormalText),
    );
  });

  testWidgets('builds in dark mode with AA body contrast', (tester) async {
    await pumpApp(tester, platformBrightness: Brightness.dark);

    final theme = Theme.of(tester.element(find.text('Launchpad Career')));
    expect(theme.brightness, Brightness.dark);
    expect(
      Contrast.ratio(theme.colorScheme.onSurface, theme.colorScheme.surface),
      greaterThanOrEqualTo(Contrast.aaNormalText),
    );
  });

  testWidgets('dark mode still meets contrast after selecting a card',
      (tester) async {
    await pumpApp(tester, platformBrightness: Brightness.dark);
    final handle = tester.ensureSemantics();

    await tester.tap(find.text('Help me pick a direction'));
    await tester.pumpAndSettle();

    await expectLater(tester, meetsGuideline(textContrastGuideline));
    handle.dispose();
  });
}

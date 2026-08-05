import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:launchpad_core/launchpad_core.dart';
import 'package:launchpad_ui/launchpad_ui.dart';

import 'helpers.dart';

void main() {
  group('GoalGrid.columnsFor', () {
    test('one column on phones, two on tablets, three on desktops', () {
      expect(GoalGrid.columnsFor(390), 1);
      expect(GoalGrid.columnsFor(599), 1);
      expect(GoalGrid.columnsFor(600), 2);
      expect(GoalGrid.columnsFor(834), 2);
      expect(GoalGrid.columnsFor(1000), 3);
      expect(GoalGrid.columnsFor(1440), 3);
    });
  });

  group('home layout', () {
    Future<void> expectColumns(
      WidgetTester tester,
      Size size,
      int expected,
    ) async {
      await pumpApp(tester, surfaceSize: size);
      final cards = find.byType(GoalCard);
      expect(cards, findsNWidgets(6));

      final firstTop = tester.getTopLeft(cards.at(0)).dy;
      final sameRow = <int>[];
      for (var i = 0; i < 6; i++) {
        if ((tester.getTopLeft(cards.at(i)).dy - firstTop).abs() < 1) {
          sameRow.add(i);
        }
      }
      expect(sameRow, hasLength(expected));
    }

    testWidgets('phone width lays out one card per row', (tester) async {
      await expectColumns(tester, const Size(390, 844), 1);
    });

    testWidgets('tablet width lays out two cards per row', (tester) async {
      await expectColumns(tester, const Size(834, 1112), 2);
    });

    testWidgets('desktop width lays out three cards per row', (tester) async {
      await expectColumns(tester, const Size(1440, 900), 3);
    });

    testWidgets('content is capped so lines do not run the full window',
        (tester) async {
      await pumpApp(tester, surfaceSize: const Size(1920, 1080));
      final width = tester.getSize(find.byType(GoalGrid)).width;
      expect(width, lessThanOrEqualTo(Breakpoints.maxContentWidth));
    });
  });
}

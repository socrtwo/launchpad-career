import 'package:flutter/material.dart';
import 'package:launchpad_core/launchpad_core.dart';
import 'package:launchpad_domain/launchpad_domain.dart';

import 'goal_card.dart';

/// Responsive grid of [GoalCard]s.
///
/// Uses [Wrap] with computed item widths rather than a [GridView] with a fixed
/// `childAspectRatio`: aspect-ratio grids overflow as soon as the user turns up
/// the system text size, which is the population we are explicitly designing
/// for. Rows here grow to fit their content instead.
class GoalGrid extends StatelessWidget {
  const GoalGrid({
    super.key,
    required this.goals,
    required this.selected,
    required this.onSelected,
    this.spacing = Spacing.md,
  });

  final List<Goal> goals;
  final GoalId? selected;
  final ValueChanged<GoalId> onSelected;
  final double spacing;

  /// Column count for a given *window* width.
  ///
  /// Deliberately not derived from the grid's own constraints: content is
  /// capped at [Breakpoints.maxContentWidth], so a 1440px desktop hands this
  /// widget about 976px and a constraint-driven rule would collapse to two
  /// columns on exactly the machines that have room for three.
  static int columnsFor(double windowWidth) =>
      switch (Breakpoints.sizeFor(windowWidth)) {
        WindowSize.compact => 1,
        WindowSize.medium => 2,
        WindowSize.expanded => 3,
      };

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = columnsFor(MediaQuery.sizeOf(context).width);
        final available = constraints.maxWidth - spacing * (columns - 1);
        final itemWidth = columns == 1
            ? constraints.maxWidth
            : (available / columns).clamp(1.0, constraints.maxWidth);
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: <Widget>[
            for (final (index, goal) in goals.indexed)
              SizedBox(
                width: itemWidth,
                child: GoalCard(
                  goal: goal,
                  selected: goal.id == selected,
                  onSelected: onSelected,
                  position: index + 1,
                  total: goals.length,
                ),
              ),
          ],
        );
      },
    );
  }
}

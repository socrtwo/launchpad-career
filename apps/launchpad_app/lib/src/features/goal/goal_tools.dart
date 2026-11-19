import 'package:flutter/material.dart';
import 'package:launchpad_domain/launchpad_domain.dart';

import '../../l10n/app_strings.dart';
import '../../routing/app_router.dart';

/// A tool a goal page can send a person to.
@immutable
class ToolLink {
  const ToolLink({
    required this.title,
    required this.description,
    required this.location,
    required this.icon,
  });

  final String title;
  final String description;
  final String location;
  final IconData icon;
}

/// The tools that exist today for each goal, most useful first.
///
/// A goal with an empty list has nothing built yet, and its page says so
/// rather than linking to something adjacent and calling it progress.
List<ToolLink> toolsFor(GoalId goal, AppStrings strings) {
  final suggestions = ToolLink(
    title: strings.suggestionsTitle,
    description: strings.suggestionsDescription,
    location: Routes.suggestions,
    icon: Icons.lightbulb_outline,
  );
  final explore = ToolLink(
    title: strings.exploreTitle,
    description: strings.exploreDescription,
    location: Routes.explore,
    icon: Icons.travel_explore_outlined,
  );
  final compare = ToolLink(
    title: strings.compareTitle,
    description: strings.compareDescription,
    location: Routes.compareBase,
    icon: Icons.compare_arrows,
  );
  final saved = ToolLink(
    title: strings.savedTitle,
    description: strings.savedDescription,
    location: Routes.saved,
    icon: Icons.bookmark_border,
  );
  return switch (goal) {
    GoalId.direction => <ToolLink>[suggestions, explore, saved],
    GoalId.majorOrGraduatePath => <ToolLink>[explore, compare, suggestions],
    GoalId.internshipOrJob ||
    GoalId.resumeAndLinkedIn ||
    GoalId.interviewPreparation ||
    GoalId.employableSkills =>
      const <ToolLink>[],
  };
}

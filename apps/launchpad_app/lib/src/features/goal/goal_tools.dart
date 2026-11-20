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

/// Identifies each tool, so a goal can name the ones that suit it.
enum Tool {
  suggestions,
  explore,
  compare,
  saved,
  searchPlan,
  resume,
  linkedIn,
  interview,
  skills,
  progress,
}

ToolLink toolLink(Tool tool, AppStrings strings) => switch (tool) {
      Tool.suggestions => ToolLink(
          title: strings.suggestionsTitle,
          description: strings.suggestionsDescription,
          location: Routes.suggestions,
          icon: Icons.lightbulb_outline,
        ),
      Tool.explore => ToolLink(
          title: strings.exploreTitle,
          description: strings.exploreDescription,
          location: Routes.explore,
          icon: Icons.travel_explore_outlined,
        ),
      Tool.compare => ToolLink(
          title: strings.compareTitle,
          description: strings.compareDescription,
          location: Routes.compareBase,
          icon: Icons.compare_arrows,
        ),
      Tool.saved => ToolLink(
          title: strings.savedTitle,
          description: strings.savedDescription,
          location: Routes.saved,
          icon: Icons.bookmark_border,
        ),
      Tool.searchPlan => ToolLink(
          title: strings.searchPlanTitle,
          description: strings.searchPlanDescription,
          location: Routes.searchPlan,
          icon: Icons.event_note_outlined,
        ),
      Tool.resume => ToolLink(
          title: strings.resumeTitle,
          description: strings.resumeDescription,
          location: Routes.resumeGuide,
          icon: Icons.description_outlined,
        ),
      Tool.linkedIn => ToolLink(
          title: strings.linkedInTitle,
          description: strings.linkedInDescription,
          location: Routes.linkedIn,
          icon: Icons.badge_outlined,
        ),
      Tool.interview => ToolLink(
          title: strings.interviewTitle,
          description: strings.interviewDescription,
          location: Routes.interview,
          icon: Icons.record_voice_over_outlined,
        ),
      Tool.skills => ToolLink(
          title: strings.skillsTitle,
          description: strings.skillsDescription,
          location: Routes.skills,
          icon: Icons.trending_up_outlined,
        ),
      Tool.progress => ToolLink(
          title: strings.progressTitle,
          description: strings.progressDescription,
          location: Routes.progress,
          icon: Icons.checklist,
        ),
    };

/// The tools that suit each goal, most useful first.
List<Tool> toolIdsFor(GoalId goal) => switch (goal) {
      GoalId.direction => const <Tool>[
          Tool.suggestions,
          Tool.explore,
          Tool.saved,
        ],
      GoalId.majorOrGraduatePath => const <Tool>[
          Tool.explore,
          Tool.compare,
          Tool.suggestions,
        ],
      GoalId.internshipOrJob => const <Tool>[
          Tool.searchPlan,
          Tool.resume,
          Tool.interview,
        ],
      GoalId.resumeAndLinkedIn => const <Tool>[Tool.resume, Tool.linkedIn],
      GoalId.interviewPreparation => const <Tool>[Tool.interview, Tool.resume],
      GoalId.employableSkills => const <Tool>[
          Tool.skills,
          Tool.explore,
          Tool.saved,
        ],
    };

List<ToolLink> toolsFor(GoalId goal, AppStrings strings) => <ToolLink>[
      for (final tool in toolIdsFor(goal)) toolLink(tool, strings),
    ];

List<ToolLink> allTools(AppStrings strings) => <ToolLink>[
      for (final tool in Tool.values) toolLink(tool, strings),
    ];

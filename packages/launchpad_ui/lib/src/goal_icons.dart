import 'package:flutter/material.dart';
import 'package:launchpad_domain/launchpad_domain.dart';

/// Resolves domain icon tokens to Material symbols.
///
/// A single icon set, never emoji: emoji render differently on every platform,
/// are announced verbatim by screen readers ("magnifying glass tilted left"),
/// and cannot be recoloured for contrast.
IconData iconForGoal(GoalIcon icon) => switch (icon) {
      GoalIcon.explore => Icons.explore_outlined,
      GoalIcon.school => Icons.school_outlined,
      GoalIcon.search => Icons.travel_explore_outlined,
      GoalIcon.document => Icons.description_outlined,
      GoalIcon.microphone => Icons.record_voice_over_outlined,
      GoalIcon.growth => Icons.trending_up_outlined,
      GoalIcon.conversation => Icons.chat_bubble_outline,
    };

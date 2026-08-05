import 'package:flutter/material.dart';
import 'package:launchpad_core/launchpad_core.dart';

/// A polite live region.
///
/// Selection changes are visible on the cards, but a screen-reader user who
/// activated a card off-screen needs the change announced too. Empty text
/// produces no node at all, so nothing is announced before a first selection.
class StatusLine extends StatelessWidget {
  const StatusLine({super.key, required this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final text = message;
    if (text == null || text.isEmpty) {
      return const SizedBox(height: Spacing.lg);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
      child: Semantics(
        liveRegion: true,
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}

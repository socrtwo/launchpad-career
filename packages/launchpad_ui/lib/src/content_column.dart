import 'package:flutter/material.dart';
import 'package:launchpad_core/launchpad_core.dart';

/// Centres page content, caps line length, and scales page padding with the
/// window size class.
class ContentColumn extends StatelessWidget {
  const ContentColumn({
    super.key,
    required this.child,
    this.maxWidth = Breakpoints.maxContentWidth,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final size = Breakpoints.of(context);
    final horizontal = switch (size) {
      WindowSize.compact => Spacing.md,
      WindowSize.medium => Spacing.lg,
      WindowSize.expanded => Spacing.xl,
    };
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: horizontal,
            vertical: Spacing.lg,
          ),
          child: child,
        ),
      ),
    );
  }
}

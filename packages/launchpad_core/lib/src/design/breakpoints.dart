import 'package:flutter/widgets.dart';

/// Material 3 window size classes, trimmed to the three we actually branch on.
enum WindowSize { compact, medium, expanded }

abstract final class Breakpoints {
  static const double compactMax = 600;
  static const double mediumMax = 1000;

  /// Measure line length, not screen width: long lines are a readability
  /// problem for exactly the users we are told to design for.
  static const double maxContentWidth = 1040;

  static WindowSize sizeFor(double width) {
    if (width < compactMax) return WindowSize.compact;
    if (width < mediumMax) return WindowSize.medium;
    return WindowSize.expanded;
  }

  static WindowSize of(BuildContext context) =>
      sizeFor(MediaQuery.sizeOf(context).width);
}

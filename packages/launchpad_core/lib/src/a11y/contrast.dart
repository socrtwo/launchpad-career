import 'dart:math' as math;
import 'dart:ui';

/// WCAG 2.x contrast helpers.
///
/// These operate on opaque colours. Alpha is ignored by [Color.computeLuminance],
/// which is precisely why the design system avoids translucent text: a value
/// like `rgba(255,255,255,0.62)` over a gradient cannot be verified at all.
abstract final class Contrast {
  static const double aaNormalText = 4.5;
  static const double aaLargeText = 3.0;
  static const double aaNonText = 3.0;

  static double ratio(Color foreground, Color background) {
    final a = foreground.computeLuminance();
    final b = background.computeLuminance();
    final lighter = math.max(a, b);
    final darker = math.min(a, b);
    return (lighter + 0.05) / (darker + 0.05);
  }

  static bool meetsAA(Color foreground, Color background,
          {bool largeText = false}) =>
      ratio(foreground, background) >= (largeText ? aaLargeText : aaNormalText);
}

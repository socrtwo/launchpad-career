/// Spacing scale. One 4dp base unit; no arbitrary paddings in widget code.
abstract final class Spacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

abstract final class Radii {
  static const double card = 16;
  static const double control = 12;
  static const double chip = 8;
}

abstract final class Elevations {
  /// Cards are outlined rather than shadowed: outlines survive high-contrast
  /// and forced-colour modes, shadows do not.
  static const double card = 0;
  static const double appBar = 0;
}

abstract final class MinTargets {
  /// WCAG 2.2 target size (minimum) is 24x24 CSS px; Material and the mobile
  /// platform guidelines both ask for 44-48. We use 48.
  static const double touch = 48;
}

abstract final class Motion {
  static const Duration fast = Duration(milliseconds: 120);
  static const Duration standard = Duration(milliseconds: 180);
}

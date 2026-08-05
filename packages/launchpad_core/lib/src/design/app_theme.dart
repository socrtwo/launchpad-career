import 'package:flutter/material.dart';

import 'tokens.dart';

/// Light and dark themes for Launchpad Career.
///
/// Two rules drive the choices here:
///  * text and interactive surfaces are opaque, so contrast can be computed and
///    tested (translucent white over a gradient cannot be);
///  * state is never signalled by colour alone - selection also changes the
///    outline weight and shows an explicit indicator.
abstract final class AppTheme {
  /// A deep slate blue. Credible for a product that sits next to a university
  /// careers office, and far enough from the usual startup violet.
  static const Color seed = Color(0xFF2C4A7C);

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
    ).copyWith(
      surface: const Color(0xFFFBFBFD),
      onSurface: const Color(0xFF17181C),
      // Default M3 surfaceVariant text can land near 4.3:1; pin it above 4.5:1.
      onSurfaceVariant: const Color(0xFF44474F),
      outline: const Color(0xFF74777F),
    );
    return _base(scheme);
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
    ).copyWith(
      surface: const Color(0xFF14161B),
      onSurface: const Color(0xFFEDEFF5),
      onSurfaceVariant: const Color(0xFFC6C9D3),
      outline: const Color(0xFF8E9199),
    );
    return _base(scheme);
  }

  static ThemeData _base(ColorScheme scheme) {
    final textTheme = _textTheme(scheme);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: Elevations.appBar,
        scrolledUnderElevation: 1,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: Elevations.card,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.card),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, MinTargets.touch),
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.lg,
            vertical: Spacing.sm,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.control),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(0, MinTargets.touch),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, MinTargets.touch),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.control),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.control),
        ),
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
      ),
      focusColor: scheme.primary.withValues(alpha: 0.12),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1),
      visualDensity: VisualDensity.standard,
    );
  }

  /// A tight scale. Display sizes are deliberately smaller than the M3 defaults:
  /// this is a screen people read, not a marketing page.
  static TextTheme _textTheme(ColorScheme scheme) {
    final base = ThemeData(brightness: scheme.brightness).textTheme;
    return base.copyWith(
      headlineLarge: base.headlineLarge?.copyWith(
        fontSize: 34,
        height: 1.15,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.6,
        color: scheme.onSurface,
      ),
      headlineSmall: base.headlineSmall?.copyWith(
        fontSize: 22,
        height: 1.25,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: scheme.onSurface,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontSize: 17,
        height: 1.3,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
      bodyLarge: base.bodyLarge?.copyWith(
        fontSize: 17,
        height: 1.5,
        color: scheme.onSurface,
      ),
      bodyMedium: base.bodyMedium?.copyWith(
        fontSize: 15,
        height: 1.45,
        color: scheme.onSurfaceVariant,
      ),
      labelLarge: base.labelLarge?.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
    );
  }
}

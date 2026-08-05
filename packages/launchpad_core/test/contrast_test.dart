import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:launchpad_core/launchpad_core.dart';

void main() {
  group('Contrast', () {
    test('black on white is 21:1', () {
      expect(
        Contrast.ratio(const Color(0xFF000000), const Color(0xFFFFFFFF)),
        closeTo(21, 0.01),
      );
    });

    test('is symmetric', () {
      const a = Color(0xFF2C4A7C);
      const b = Color(0xFFFBFBFD);
      expect(Contrast.ratio(a, b), closeTo(Contrast.ratio(b, a), 0.0001));
    });
  });

  group('theme contrast', () {
    for (final entry in <String, ThemeData>{
      'light': AppTheme.light(),
      'dark': AppTheme.dark(),
    }.entries) {
      final scheme = entry.value.colorScheme;

      test('${entry.key}: body text on surface meets AA', () {
        expect(
          Contrast.ratio(scheme.onSurface, scheme.surface),
          greaterThanOrEqualTo(Contrast.aaNormalText),
        );
      });

      test('${entry.key}: secondary text on surface meets AA', () {
        expect(
          Contrast.ratio(scheme.onSurfaceVariant, scheme.surface),
          greaterThanOrEqualTo(Contrast.aaNormalText),
        );
      });

      test('${entry.key}: primary button label meets AA', () {
        expect(
          Contrast.ratio(scheme.onPrimary, scheme.primary),
          greaterThanOrEqualTo(Contrast.aaNormalText),
        );
      });

      test('${entry.key}: outline meets non-text AA', () {
        expect(
          Contrast.ratio(scheme.outline, scheme.surface),
          greaterThanOrEqualTo(Contrast.aaNonText),
        );
      });
    }
  });

  group('Breakpoints', () {
    test('maps widths to window size classes', () {
      expect(Breakpoints.sizeFor(390), WindowSize.compact);
      expect(Breakpoints.sizeFor(599.9), WindowSize.compact);
      expect(Breakpoints.sizeFor(600), WindowSize.medium);
      expect(Breakpoints.sizeFor(999.9), WindowSize.medium);
      expect(Breakpoints.sizeFor(1440), WindowSize.expanded);
    });
  });
}

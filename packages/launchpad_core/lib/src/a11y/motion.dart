import 'package:flutter/widgets.dart';

import '../design/tokens.dart';

/// Honours the platform "reduce motion" setting.
///
/// Every animated widget in the product asks for its duration here, so the
/// preference cannot be forgotten in one place and respected in another.
abstract final class AppMotion {
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  static Duration duration(
    BuildContext context, {
    Duration standard = Motion.standard,
  }) =>
      reduced(context) ? Duration.zero : standard;

  static Curve curve(BuildContext context) =>
      reduced(context) ? Curves.linear : Curves.easeOutCubic;
}

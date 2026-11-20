import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:launchpad_ui/launchpad_ui.dart';

import '../l10n/app_strings.dart';
import '../routing/app_router.dart';

/// [PageShell] wired to this app's routes and strings.
///
/// Inner pages have one way back and it is always labelled with where it goes.
class AppPage extends StatelessWidget {
  const AppPage({
    super.key,
    required this.child,
    this.maxWidth = 720,
    this.backLocation = Routes.home,
    this.backLabel,
  });

  final Widget child;
  final double maxWidth;
  final String backLocation;

  /// Defaults to "Back to start".
  final String? backLabel;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return PageShell(
      appBarTitle: strings.appName,
      onBack: () => context.go(backLocation),
      backTooltip: backLabel ?? strings.backToStart,
      maxWidth: maxWidth,
      child: child,
    );
  }
}

/// A page heading, marked as a heading for assistive technology.
class PageHeading extends StatelessWidget {
  const PageHeading(this.text, {super.key, this.large = true});

  final String text;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      header: true,
      child: Text(
        text,
        style: large ? textTheme.headlineLarge : textTheme.headlineSmall,
      ),
    );
  }
}

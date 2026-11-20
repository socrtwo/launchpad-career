import 'package:flutter/material.dart';

import 'content_column.dart';

/// The frame every inner page shares: an app bar with one way back, and a
/// scrolling, width-capped column.
///
/// Routing stays out of this package, so the page supplies [onBack].
class PageShell extends StatelessWidget {
  const PageShell({
    super.key,
    required this.appBarTitle,
    required this.onBack,
    required this.backTooltip,
    required this.child,
    this.maxWidth = 720,
    this.actions = const <Widget>[],
  });

  final String appBarTitle;
  final VoidCallback onBack;
  final String backTooltip;
  final Widget child;
  final double maxWidth;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(appBarTitle),
        leading: IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back),
          tooltip: backTooltip,
        ),
        actions: actions,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: ContentColumn(maxWidth: maxWidth, child: child),
        ),
      ),
    );
  }
}

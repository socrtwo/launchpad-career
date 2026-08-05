import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:launchpad_core/launchpad_core.dart';
import 'package:launchpad_ui/launchpad_ui.dart';

import '../../l10n/app_strings.dart';
import '../../routing/app_router.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return InfoScaffold(title: strings.aboutTitle, body: strings.aboutBody);
  }
}

class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return InfoScaffold(title: strings.privacyTitle, body: strings.privacyBody);
  }
}

class AccessibilityPage extends StatelessWidget {
  const AccessibilityPage({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return InfoScaffold(
      title: strings.accessibilityTitle,
      body: strings.accessibilityBody,
    );
  }
}

class InfoScaffold extends StatelessWidget {
  const InfoScaffold({super.key, required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(strings.appName),
        leading: IconButton(
          onPressed: () => context.go(Routes.home),
          icon: const Icon(Icons.arrow_back),
          tooltip: strings.backToStart,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: ContentColumn(
            maxWidth: 720,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                ),
                const SizedBox(height: Spacing.md),
                Text(body, style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: Spacing.xl),
                OutlinedButton.icon(
                  onPressed: () => context.go(Routes.home),
                  icon: const Icon(Icons.arrow_back),
                  label: Text(strings.backToStart),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

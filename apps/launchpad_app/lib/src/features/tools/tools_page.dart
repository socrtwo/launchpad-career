import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:launchpad_core/launchpad_core.dart';
import 'package:launchpad_ui/launchpad_ui.dart';

import '../../app/app_page.dart';
import '../../l10n/app_strings.dart';
import '../goal/goal_tools.dart';

/// Every tool, in one list. Goals lead to the tools that suit them; this page
/// is for people who know what they want.
class ToolsPage extends StatelessWidget {
  const ToolsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return AppPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          PageHeading(strings.toolsTitle),
          const SizedBox(height: Spacing.sm),
          Text(
            strings.toolsIntro,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: Spacing.md),
          for (final tool in allTools(strings))
            Padding(
              padding: const EdgeInsets.only(bottom: Spacing.sm),
              child: SecondaryChoiceTile(
                title: tool.title,
                description: tool.description,
                icon: tool.icon,
                onPressed: () => context.go(tool.location),
              ),
            ),
        ],
      ),
    );
  }
}

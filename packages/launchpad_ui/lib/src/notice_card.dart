import 'package:flutter/material.dart';
import 'package:launchpad_core/launchpad_core.dart';

/// A quiet, outlined note: a status, a reason for a question, or a statement
/// of what is and is not real in this build.
///
/// Outlined rather than shadowed or tinted, so it survives high-contrast and
/// forced-colour modes, and always paired with an icon so it does not rely on
/// its fill to be noticed.
class NoticeCard extends StatelessWidget {
  const NoticeCard({
    super.key,
    required this.text,
    this.title,
    this.icon = Icons.info_outline,
    this.action,
  });

  final String text;
  final String? title;
  final IconData icon;

  /// An optional control placed under the text, usually a single button.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ExcludeSemantics(
            child: Icon(icon, size: 20, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (title != null) ...<Widget>[
                  Semantics(
                    header: true,
                    child: Text(title!, style: theme.textTheme.titleMedium),
                  ),
                  const SizedBox(height: Spacing.xxs),
                ],
                Text(text, style: theme.textTheme.bodyMedium),
                if (action != null) ...<Widget>[
                  const SizedBox(height: Spacing.sm),
                  action!,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:launchpad_core/launchpad_core.dart';

/// The lower-prominence "Something else" entry point.
///
/// Deliberately a separate control rather than a seventh card: it is not part
/// of the selection group, it does not need a Continue press, and it must not
/// look like the option you pick when the others "failed".
class SecondaryChoiceTile extends StatelessWidget {
  const SecondaryChoiceTile({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.onPressed,
  });

  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      container: true,
      button: true,
      label: title,
      hint: description,
      excludeSemantics: true,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.all(Spacing.md),
          minimumSize: const Size(0, MinTargets.touch),
          side: BorderSide(color: scheme.outlineVariant),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.card),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, size: 22, color: scheme.onSurfaceVariant),
            const SizedBox(width: Spacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(title, style: theme.textTheme.titleMedium),
                  const SizedBox(height: Spacing.xxs),
                  Text(description, style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

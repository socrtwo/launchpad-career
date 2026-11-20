import 'package:flutter/material.dart';
import 'package:launchpad_core/launchpad_core.dart';

/// One answer in a list of answers.
///
/// Used for single-choice questions ([multiSelect] false, announced as one of
/// a mutually exclusive group) and for choose-any questions ([multiSelect]
/// true, announced as a checkbox).
///
/// The selected state is carried by the indicator icon and the outline weight
/// as well as the fill, so colour is never the only signal. Keyboard
/// activation comes from [InkWell], which listens for `ActivateIntent`; no key
/// handling is written by hand.
class OptionTile extends StatefulWidget {
  const OptionTile({
    super.key,
    required this.label,
    required this.selected,
    required this.onPressed,
    this.description,
    this.multiSelect = false,
  });

  final String label;
  final String? description;
  final bool selected;
  final bool multiSelect;
  final VoidCallback onPressed;

  @override
  State<OptionTile> createState() => _OptionTileState();
}

class _OptionTileState extends State<OptionTile> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final selected = widget.selected;
    final foreground =
        selected ? scheme.onSecondaryContainer : scheme.onSurface;
    final secondary =
        selected ? scheme.onSecondaryContainer : scheme.onSurfaceVariant;
    final emphasised = selected || _focused;
    final indicator = switch ((widget.multiSelect, selected)) {
      (true, true) => Icons.check_box,
      (true, false) => Icons.check_box_outline_blank,
      (false, true) => Icons.radio_button_checked,
      (false, false) => Icons.radio_button_unchecked,
    };

    return Semantics(
      container: true,
      button: true,
      checked: selected,
      inMutuallyExclusiveGroup: !widget.multiSelect,
      label: widget.label,
      hint: widget.description,
      onTap: widget.onPressed,
      excludeSemantics: true,
      child: Material(
        color: selected ? scheme.secondaryContainer : scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.control),
          side: BorderSide(
            color: emphasised ? scheme.primary : scheme.outline,
            width: emphasised ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onPressed,
          onFocusChange: (value) => setState(() => _focused = value),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: MinTargets.touch + 8),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.md,
                vertical: Spacing.sm,
              ),
              child: Row(
                children: <Widget>[
                  Icon(
                    indicator,
                    size: 24,
                    color: selected ? scheme.primary : scheme.outline,
                  ),
                  const SizedBox(width: Spacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          widget.label,
                          style: theme.textTheme.titleMedium
                              ?.copyWith(color: foreground),
                        ),
                        if (widget.description != null) ...<Widget>[
                          const SizedBox(height: Spacing.xxs),
                          Text(
                            widget.description!,
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(color: secondary),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

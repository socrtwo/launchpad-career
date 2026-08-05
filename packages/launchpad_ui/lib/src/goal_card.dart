import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:launchpad_core/launchpad_core.dart';
import 'package:launchpad_domain/launchpad_domain.dart';

import 'goal_icons.dart';

/// A single selectable goal.
///
/// Behaviour worth knowing about before changing it:
///
///  * The description is revealed on hover, on keyboard focus, and on selection.
///    Hover is never the only route to it, and it is always present in the
///    semantics tree regardless of visual state, so a screen-reader user hears
///    it without having to trigger anything.
///  * Selection is announced (`Semantics.selected`) and shown with an explicit
///    indicator plus a heavier outline, not by colour alone.
///  * Enter and Space activate the card through `ActivateIntent`; the widget
///    does not hand-roll key handling, so platform conventions are preserved.
///  * All animation durations come from [AppMotion], so "reduce motion" works.
class GoalCard extends StatefulWidget {
  const GoalCard({
    super.key,
    required this.goal,
    required this.selected,
    required this.onSelected,
    this.position,
    this.total,
    this.autofocus = false,
  });

  final Goal goal;
  final bool selected;
  final ValueChanged<GoalId> onSelected;

  /// 1-based position, used for "option 2 of 6" announcements.
  final int? position;
  final int? total;
  final bool autofocus;

  @override
  State<GoalCard> createState() => _GoalCardState();
}

class _GoalCardState extends State<GoalCard> {
  bool _hovered = false;
  bool _focused = false;

  bool get _revealed => widget.selected || _hovered || _focused;

  void _activate() {
    HapticFeedback.selectionClick();
    widget.onSelected(widget.goal.id);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final reducedMotion = AppMotion.reduced(context);
    final duration = AppMotion.duration(context);
    final curve = AppMotion.curve(context);

    final background = widget.selected
        ? scheme.secondaryContainer
        : (_hovered ? scheme.surfaceContainerHighest : scheme.surface);
    final foreground =
        widget.selected ? scheme.onSecondaryContainer : scheme.onSurface;
    final borderColour = switch ((widget.selected, _focused)) {
      (true, _) => scheme.primary,
      (false, true) => scheme.primary,
      _ => scheme.outlineVariant,
    };
    final borderWidth = widget.selected || _focused ? 2.0 : 1.0;

    final positionLabel = (widget.position != null && widget.total != null)
        ? ', option ${widget.position} of ${widget.total}'
        : '';

    return Semantics(
      container: true,
      button: true,
      inMutuallyExclusiveGroup: true,
      selected: widget.selected,
      label: '${widget.goal.title}$positionLabel',
      hint: widget.goal.description,
      onTap: _activate,
      excludeSemantics: true,
      child: FocusableActionDetector(
        autofocus: widget.autofocus,
        mouseCursor: SystemMouseCursors.click,
        onShowHoverHighlight: (value) => setState(() => _hovered = value),
        onShowFocusHighlight: (value) => setState(() => _focused = value),
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.numpadEnter): ActivateIntent(),
        },
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              _activate();
              return null;
            },
          ),
          ButtonActivateIntent: CallbackAction<ButtonActivateIntent>(
            onInvoke: (_) {
              _activate();
              return null;
            },
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _activate,
          child: AnimatedContainer(
            duration: duration,
            curve: curve,
            constraints: const BoxConstraints(minHeight: 96),
            padding: const EdgeInsets.all(Spacing.md),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(Radii.card),
              border: Border.all(color: borderColour, width: borderWidth),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _IconBadge(
                      icon: iconForGoal(widget.goal.icon),
                      selected: widget.selected,
                    ),
                    const SizedBox(width: Spacing.sm),
                    Expanded(
                      child: Text(
                        widget.goal.title,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(color: foreground),
                      ),
                    ),
                    const SizedBox(width: Spacing.xs),
                    Icon(
                      widget.selected
                          ? Icons.check_circle
                          : Icons.circle_outlined,
                      size: 22,
                      color: widget.selected ? scheme.primary : scheme.outline,
                    ),
                  ],
                ),
                _RevealedDescription(
                  revealed: _revealed,
                  reducedMotion: reducedMotion,
                  duration: duration,
                  curve: curve,
                  text: widget.goal.description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: widget.selected
                        ? scheme.onSecondaryContainer
                        : scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Reveals the goal description.
///
/// [AnimatedSize] must not be given a zero duration - `RenderAnimatedSize`
/// restarts its controller inside `performLayout` and trips the "mutated in its
/// own performLayout implementation" assertion. So when the user has asked for
/// reduced motion we drop the animation wrapper entirely rather than animating
/// over zero milliseconds.
class _RevealedDescription extends StatelessWidget {
  const _RevealedDescription({
    required this.revealed,
    required this.reducedMotion,
    required this.duration,
    required this.curve,
    required this.text,
    required this.style,
  });

  final bool revealed;
  final bool reducedMotion;
  final Duration duration;
  final Curve curve;
  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final child = revealed
        ? Padding(
            padding: const EdgeInsets.only(top: Spacing.xs),
            child: Text(text, style: style),
          )
        : const SizedBox(width: double.infinity);

    if (reducedMotion) return child;

    return AnimatedSize(
      duration: duration,
      curve: curve,
      alignment: Alignment.topLeft,
      child: child,
    );
  }
}

class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon, required this.selected});

  final IconData icon;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: selected ? scheme.primary : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(Radii.chip),
      ),
      child: Icon(
        icon,
        size: 22,
        color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
      ),
    );
  }
}

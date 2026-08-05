# Accessibility requirements

**Target:** WCAG 2.1 Level AA, plus the platform conventions (Material accessibility
guidance, Apple HIG accessibility). Nothing here claims certification; these are the
requirements the code is written and tested against.

## Enforced by tests

| Requirement | Where it is enforced |
| --- | --- |
| Body and secondary text meet 4.5:1 in both themes | `packages/launchpad_core/test/contrast_test.dart`, `theme_test.dart` |
| Non-text boundaries meet 3:1 | `contrast_test.dart` |
| Touch targets ≥ 48dp | `accessibility_test.dart` (`androidTapTargetGuideline`, `iOSTapTargetGuideline`) |
| Every tappable element is labelled | `accessibility_test.dart` (`labeledTapTargetGuideline`) |
| Cards are reachable by Tab and activated by Enter and Space | `accessibility_test.dart` |
| Card descriptions reach assistive technology regardless of visual state | `accessibility_test.dart` |
| Selection is exposed as `selected` in a mutually exclusive group | `accessibility_test.dart` |
| Reduce-motion produces no animation | `accessibility_test.dart` |
| Layout survives 2× text scale without overflow | `home_page_test.dart` |
| One / two / three columns at phone / tablet / desktop | `responsive_test.dart` |

## Design rules

**Colour is never the only signal.** Selection changes the fill, the outline weight, *and*
shows a check indicator. (WCAG 1.4.1)

**Text and interactive colours are opaque.** Translucent white over a gradient cannot have
its contrast computed or tested. This is the single biggest departure from the original
HTML prototype, where secondary text sat at 62–70% opacity over a moving background.

**Hover is never the only route to information.** Card descriptions are revealed on hover,
on keyboard focus, and on selection — and are present in the semantics tree at all times,
so a screen-reader user hears them without triggering anything. (WCAG 1.4.13, 2.1.1)

**Focus is visible and never trapped.** Focus changes both the outline colour and its
weight. `FocusableActionDetector` handles the highlight so the platform's own
focus-visibility heuristics apply. (WCAG 2.4.7)

**Keyboard activation uses `ActivateIntent`**, not hand-rolled key listeners, so platform
conventions and future key bindings keep working. The prototype's `keydown` handler
duplicated the browser's native button behaviour and could double-fire.

**Motion is opt-out-able and never load-bearing.** All durations come from `AppMotion`;
nothing essential is revealed only by animation. (WCAG 2.3.3)

**Live regions are polite and quiet when empty.** The selection status renders no semantics
node at all before a first selection, so nothing is announced on load.

**Headings are marked as headings** (`Semantics(header: true)`) so screen-reader users can
navigate by structure.

## Manual test checklist

Before any release, on at least one platform each:

- [ ] TalkBack (Android): reach every control by swipe; selection state is announced
- [ ] VoiceOver (iOS and macOS): rotor lists headings; hints read the descriptions
- [ ] NVDA or JAWS (Windows, web build): tab order matches visual order
- [ ] Keyboard only, no mouse: complete goal selection and continue
- [ ] System text size at maximum: no clipping, no overlap, no truncation of instructions
- [ ] Reduce motion on: no movement anywhere
- [ ] Dark mode and light mode, both at maximum text size
- [ ] Browser zoom to 200% (web)
- [ ] Windows High Contrast mode (web build)

## Known gaps

- No automated audit runs in CI beyond Flutter's built-in guideline matchers. A real audit
  by someone who uses assistive technology daily has not happened and is a Phase 6 item.
- `androidTapTargetGuideline` checks size, not spacing; WCAG 2.2's 2.5.8 target spacing has
  not been verified.
- Forced-colours / high-contrast mode on the web build is untested.
- The accessibility statement at `/accessibility` is a placeholder. It must not claim
  conformance until an audit supports it.

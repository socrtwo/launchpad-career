# Architecture overview

## Shape

Five packages, path-linked, dependencies pointing one way:

```
        launchpad_app
        /     |     \
launchpad_ui  |   launchpad_data
      |       |        |
launchpad_core|   launchpad_domain
              \________/
```

- **`launchpad_domain`** — pure Dart. Entities (`Goal`, `Session`, `Evidence`) and
  repository interfaces. No Flutter, no I/O, no JSON. This is the layer that outlives
  every UI rewrite, so it is kept boring.
- **`launchpad_data`** — implementations of those interfaces. Today everything is
  in-memory; a networked implementation is added beside these, not in place of them.
- **`launchpad_core`** — design tokens, light and dark themes, breakpoints, and
  accessibility helpers (`Contrast`, `AppMotion`). Depends on Flutter but knows nothing
  about careers.
- **`launchpad_ui`** — shared widgets: `GoalCard`, `GoalGrid`, `SecondaryChoiceTile`,
  `ContentColumn`, `StatusLine`. Knows about domain entities, not about routing or state.
- **`launchpad_app`** — feature folders, routing, localisation, providers, tests.

### Why the domain package has no Flutter dependency

Because it is the one thing that must stay portable. The visible consequence is that
`Goal` carries a `GoalIcon` enum rather than an `IconData`; `launchpad_ui` maps tokens to
Material symbols in `goal_icons.dart`. If a design decision ever reaches into
`launchpad_domain`, that is the signal it has been put in the wrong place.

### Why no Melos

Five packages with path dependencies resolve fine with plain `flutter pub get`.
`tool/dev.sh` loops over them for get/format/analyze/test. Adding a bootstrap tool would
buy version-syncing and changelog generation that nothing here needs yet. Revisit when
packages start being published, or when the count roughly doubles.

## Feature-first layout inside the app

```
lib/src/
├── app/          App widget and provider wiring
├── routing/      Route table and route constants
├── l10n/         String table and delegate
└── features/
    ├── home/
    ├── goal/
    ├── something_else/
    └── info/
```

New modules — onboarding, exploration, comparison, résumé, interview — are new folders
under `features/`, each free to add its own controllers. Cross-feature widgets graduate to
`launchpad_ui`; cross-feature types graduate to `launchpad_domain`.

## State management

Riverpod. Three kinds of provider are in use, and there is no fourth pattern:

- `Provider` for dependency wiring (`goalCatalogRepositoryProvider`,
  `sessionRepositoryProvider`, `routerProvider`). Tests override these, nothing else.
- `FutureProvider` for repository reads (`goalsProvider`).
- `Notifier` for UI state a user can change (`SelectedGoalController`).

Note for future contributors: Riverpod 3 does not export the `Override` type, so test
helpers cannot declare `List<Override>` parameters. `test/helpers.dart` builds the override
list internally for exactly this reason.

## Routing

`go_router`, declarative, with these routes:

| Route | Purpose |
| --- | --- |
| `/` | Home: goal selection |
| `/goal?id=<slug>` | Placeholder destination for a selected goal |
| `/something-else` | Open-text entry point |
| `/about` | Product scope and disclaimers |
| `/privacy` | Placeholder for the reviewed privacy notice |
| `/accessibility` | Placeholder for the accessibility statement |

Goals are addressed by **slug**, never by enum index. Reordering `GoalId` must not silently
repoint saved links or stored state; `GoalId.fromSlug` is the only way in.

The goal page reads its goal from the URL rather than from selection state, so a refreshed
or shared link works.

## Responsive layout

`Breakpoints` implements the Material 3 window size classes we actually branch on:
compact (< 600), medium (< 1000), expanded (≥ 1000) → one, two, three columns.

Two deliberate choices:

1. **Column count comes from window width, not the grid's own constraints.** Content is
   capped at 1040 logical pixels for line length, so a 1440px desktop hands the grid about
   976px; a constraint-driven rule would collapse to two columns on exactly the machines
   with room for three.
2. **`Wrap` with computed item widths, not `GridView` with `childAspectRatio`.**
   Aspect-ratio grids overflow as soon as a user raises the system text size. Rows here
   grow to fit content instead, which is tested at 2× scale.

## Testing strategy

| Level | Location | What it covers |
| --- | --- | --- |
| Unit | `packages/*/test` | Contrast maths, breakpoints, slugs, catalogue invariants |
| Widget | `apps/launchpad_app/test` | The real widget tree: selection, routing, layout, semantics, themes |
| Integration | `apps/launchpad_app/integration_test` | End-to-end on a real device or browser |

Widget tests pump the actual `LaunchpadApp` with the real router and theme, not a
simplified harness — a test that passes against a stand-in tree proves little.

One environment trap worth knowing: `WidgetsApp` rebuilds `MediaQuery.fromView`
internally, so wrapping the app in a `MediaQuery` to fake brightness, text scale, or
reduce-motion silently asserts nothing. `test/helpers.dart` sets these on the test
`PlatformDispatcher` and sizes `tester.view` directly.

## Known Flutter-specific hazards recorded here so they are not rediscovered

- `AnimatedSize` must not be given `Duration.zero`. `RenderAnimatedSize` restarts its
  controller inside `performLayout` and trips a "mutated in its own performLayout
  implementation" assertion. The reduce-motion path therefore drops the animation wrapper
  entirely rather than animating over zero milliseconds. See `_RevealedDescription`.
- `tester.binding.setSurfaceSize` does not feed through to `MediaQuery`; layout tests that
  rely on it run at the default 800×600 and pass for the wrong reason.

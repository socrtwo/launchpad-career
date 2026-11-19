# Architecture overview

## Shape

Five app packages, path-linked, dependencies pointing one way, plus one server package
that stands alone:

```
        launchpad_app
        /     |     \
launchpad_ui  |   launchpad_data
      |       |        |
launchpad_core|   launchpad_domain
              \________/
```

- **`launchpad_domain`** — pure Dart. Entities (`Goal`, `Session`, `Profile`, `Workspace`,
  `Occupation`, `LaborStats`, `Evidence`), repository interfaces, and the one piece of
  domain logic, `Recommender`. No Flutter, no I/O, no JSON. This is the layer that outlives
  every UI rewrite, so it is kept boring.
- **`launchpad_data`** — implementations of those interfaces, still pure Dart. Catalogues
  are in memory. The session is in memory and, after an explicit opt-in, mirrored through
  the `KeyValueStore` interface; `SessionCodec` is where JSON lives. A networked
  implementation is added beside these, not in place of them.
- **`launchpad_core`** — design tokens, light and dark themes, breakpoints, and
  accessibility helpers (`Contrast`, `AppMotion`). Depends on Flutter but knows nothing
  about careers.
- **`launchpad_ui`** — shared widgets: `GoalCard`, `GoalGrid`, `SecondaryChoiceTile`,
  `OptionTile`, `NoticeCard`, `PageShell`, `ContentColumn`, `StatusLine`. Knows about
  domain entities, not about routing or state.
- **`launchpad_app`** — feature folders, routing, localisation, providers, tests.

- **`services/launchpad_server`** — the optional account and sync server: pure Dart
  (`shelf`), no Flutter, no dependency on the packages above. `launchpad_data` depends on
  it for tests only, so that the app's client is exercised against the real handler. See
  "Accounts and the server" below.

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
    ├── onboarding/
    ├── goal/
    ├── explore/        browse, occupation, compare, saved, suggestions, plan
    ├── tools/          job-search plan, résumé, LinkedIn, interview, skills, progress
    ├── something_else/
    ├── your_data/
    ├── account/        optional sign-in, sync, account export and deletion
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
- `Notifier` for state a user can change (`SelectedGoalController`, `SessionController`,
  `LocalDataController`). The session is read synchronously from its repository and
  written back through the notifier; there is deliberately no `StreamProvider`.

`FutureProvider.family` is used once, for plan steps keyed by occupation and route. It is
the same pattern with a parameter, not a fourth one.

### Where plugins live

`launchpad_data` is pure Dart, so it cannot depend on a Flutter plugin. It defines the
three-method `KeyValueStore` interface; the adapter over `shared_preferences`
(`SharedPreferencesStore`) lives in the app and is injected in `main`. Until `main`
supplies it the store is in memory, which is what every test runs against. The adapter is
allow-listed to the two keys the session repository owns.

Note for future contributors: Riverpod 3 does not export the `Override` type, so test
helpers cannot declare `List<Override>` parameters. `test/helpers.dart` builds the override
list internally for exactly this reason.

## Routing

`go_router`, declarative, with these routes:

| Route | Purpose |
| --- | --- |
| `/` | Home: goal selection |
| `/onboarding/<step>` | One onboarding question, by slug; `review` shows every answer |
| `/goal?id=<slug>` | Destination for a selected goal |
| `/something-else` | Open-text entry point |
| `/explore` | Search and browse occupations |
| `/occupation?id=<slug>` | One occupation |
| `/compare?ids=<slug>,<slug>` | Two or three occupations side by side; the selection is in the URL |
| `/saved` | Saved occupations and their plans |
| `/suggestions` | Occupations matched to the person's answers, with reasons |
| `/plan?id=<slug>` | Action plan towards one occupation |
| `/tools` | Every tool in one list |
| `/tools/search-plan` | Weekly job-search plan |
| `/tools/resume` | Résumé checklist and wording check |
| `/tools/linkedin` | LinkedIn profile checklist |
| `/tools/interview[?q=<slug>]` | Question bank, or one question |
| `/tools/skills[?id=<slug>]` | Skill self-rating for an occupation |
| `/progress` | Everything done so far, in words |
| `/your-data` | Storage opt-in, export, deletion |
| `/account` | Optional account: sign in, sync, export, delete. Says so when no service is configured |
| `/about` | Product scope and disclaimers |
| `/privacy` | What this build does with data; not yet a reviewed notice |
| `/accessibility` | Placeholder for the accessibility statement |

Goals are addressed by **slug**, never by enum index. Reordering `GoalId` must not silently
repoint saved links or stored state; `GoalId.fromSlug` is the only way in.

The goal page reads its goal from the URL rather than from selection state, so a refreshed
or shared link works.

## Tool state

Every tool keeps its state in `Workspace`, in three flat collections rather than a field
per tool: `completed` (a set of namespaced identifiers such as `resume/education`),
`choices` (key to slug, for selections from a closed set) and `notes` (key to free text).
The keys are built by static helpers on `Workspace` and nowhere else. The pay-off is that
a new tool needs no change to the stored shape, the codec, export or deletion; the cost is
that the keys are strings, which is why they are built in one place and tested.

Which tools suit which goal is a single table, `toolIdsFor` in
`features/goal/goal_tools.dart`.

## Accounts and the server

Accounts are optional at every level. The app reads the service address from
`--dart-define=LAUNCHPAD_API_URL=…`; without it `accountRepositoryProvider` is null, the
catalogues are the bundled ones, and no request is ever made. There is no route guard and
no feature checks for a sign-in.

- **Interface in the domain** (`AccountRepository`), **client in the data package**
  (`HttpAccountRepository`, on `package:http`), **server beside both**
  (`services/launchpad_server`, interface in its `API.md`).
- **What is synced is what would be stored**: `SessionCodec.encode` without the
  "Something else" text. The server treats it as an opaque document.
- **Sync is optimistic and explicit.** Each upload names the revision it is based on; a
  mismatch comes back as `SyncConflict` and the page asks which copy to keep.
- **The contract is tested for real.** `account_contract_test.dart` runs the client
  against `buildHandler` in process, bridging `package:http`'s `MockClient` to the shelf
  handler. A change on either side that breaks the other fails there. Widget tests use an
  in-memory fake with the same rules, because the real passphrase hash runs on an isolate
  that the widget-test clock does not drive.
- **Catalogue publishing**: `tool/catalog.dart export|validate|publish|rollback`. A
  published catalogue is used only if `CatalogCodec` accepts every entry; otherwise the
  app keeps the one it was built with. Publishing an entry with `"kind": "editorial"` is
  how reviewed content loses its draft label.

## Recommendations

`Recommender.recommend` is a pure function in `launchpad_domain`: profile and catalogue in,
`RecommendationSet` out. It scores by fixed rules, returns structured reasons
(`InterestReason`, `RouteOpenNowReason`, `PriorityReason`, …) rather than sentences, and
reports what it could not use (`RecommendationNote`, `unusedPriorities`) instead of
guessing. The interface words the reasons. Keeping it in the domain package means it has
no access to anything but the three inputs it is allowed to read, and it is tested without
Flutter. The specification it is built against is
`docs/product/career-recommendation-principles.md`.

## Content and figures

Occupation text is bundled in `launchpad_data/lib/src/catalog/`. Pay and employment
figures are a separate, generated file (`lib/src/labor/oews_snapshot.g.dart`) written by
`tool/import_oews.dart`; see `docs/product/labour-market-data.md`. Text carries no figures
and figures carry their own evidence, so the two cannot be confused.

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
| Contract | `packages/launchpad_data/test/account_contract_test.dart` | The app's account client against the real server handler |
| Server | `services/launchpad_server/test` | Every endpoint, the store, the cryptography, the log |
| Browser | `tool/web_audit/audit.cjs` | The release web build in Chromium: every request stays on the page's origin |

Widget tests pump the actual `LaunchpadApp` with the real router and theme, not a
simplified harness — a test that passes against a stand-in tree proves little.

One environment trap worth knowing: `WidgetsApp` rebuilds `MediaQuery.fromView`
internally, so wrapping the app in a `MediaQuery` to fake brightness, text scale, or
reduce-motion silently asserts nothing. `test/helpers.dart` sets these on the test
`PlatformDispatcher` and sizes `tester.view` directly.

## Web build

`tool/build_web.sh` is the only supported way to make a release web build. It serves
CanvasKit locally, compiles without run-time code generation, and writes a content
security policy into `index.html`. The typeface is bundled by the app under the exact
family name `Roboto`, and `web/flutter_bootstrap.js` points fallback-font lookups at the
site's own origin. Why each of those is needed, and the trade-off for non-Latin text, is
in `docs/release/web-hosting.md`.

## Known Flutter-specific hazards recorded here so they are not rediscovered

- `AnimatedSize` must not be given `Duration.zero`. `RenderAnimatedSize` restarts its
  controller inside `performLayout` and trips a "mutated in its own performLayout
  implementation" assertion. The reduce-motion path therefore drops the animation wrapper
  entirely rather than animating over zero milliseconds. See `_RevealedDescription`.
- `tester.binding.setSurfaceSize` does not feed through to `MediaQuery`; layout tests that
  rely on it run at the default 800×600 and pass for the wrong reason.
- Flutter's web engine downloads Roboto from `fonts.gstatic.com` unless the app's font
  manifest has a family named exactly `Roboto`. Declaring the font in a package gives it
  the family `packages/<name>/Roboto`, which does not count. Found by the browser audit;
  unit and widget tests cannot see it.
- `go_router` builds one page per route *pattern*. For `/onboarding/:step` that means the
  page's `State` is reused when only the parameter changes, so `initState` runs once for
  the whole sequence. The route builder keys the page widget by step.

# CLAUDE.md

Guidance for AI-assisted work in this repository. The full rationale lives in `docs/`;
this file is the summary you follow by default. When in doubt, the docs win — read them.

## What this project is

A career-planning and employment-guidance tool for undergraduates, graduate students,
recent graduates, and career changers. It is **not** a mental-health service, diagnostic
tool, job board, or promise of employment. Phases 1 (foundation), 2 (onboarding, opt-in
local storage), 3 (career exploration), 4 (employment tools) and 5 (optional accounts and
sync) are built, and Phase 6 (release) is prepared but nothing is released, deployed,
audited or legally reviewed; `docs/product/roadmap.md` is the
record of what is and is not done, and the interface must say the same thing honestly
(`docs/product/roadmap.md`, `docs/product/product-principles.md`).

## Architecture rules (`docs/architecture/architecture-overview.md`)

Five path-linked app packages with one-way dependencies, plus a standalone server:

- `packages/launchpad_domain` — pure Dart entities (`Goal`, `Session`, `Profile`,
  `Workspace`, `Occupation`, `LaborStats`, `Evidence`), repository interfaces, and the
  rule-based `Recommender`. **No Flutter, no I/O, no JSON.** If a design decision reaches
  into this package, it is in the wrong place (e.g. `Goal` carries a `GoalIcon` enum,
  never `IconData`).
- `packages/launchpad_data` — repository implementations, pure Dart (no Flutter plugins:
  storage goes through the `KeyValueStore` interface and the plugin adapter lives in the
  app). JSON lives here (`SessionCodec`). Networked implementations go **beside** these,
  not in place of them.
- `packages/launchpad_core` — design tokens, themes, breakpoints, accessibility helpers.
  Depends on Flutter, knows nothing about careers.
- `packages/launchpad_ui` — shared widgets. Knows domain entities, not routing or state.
- `apps/launchpad_app` — feature folders, routing, l10n, providers, tests.
- `services/launchpad_server` — the optional account and sync server. Pure Dart, depends
  on none of the above. `launchpad_data` dev-depends on it so the client's contract tests
  run against the real handler; keep that direction.

Other standing rules:

- **Feature-first layout**: new modules are new folders under `lib/src/features/`.
  Cross-feature widgets graduate to `launchpad_ui`; cross-feature types to
  `launchpad_domain`.
- **State management is Riverpod with exactly three patterns** — `Provider` for wiring,
  `FutureProvider` for repository reads, `Notifier` for user-changeable UI state. Do not
  introduce a fourth.
- **Routing is `go_router`, declarative.** Goals are addressed by **slug**, never by enum
  index; `GoalId.fromSlug` is the only way in. The goal page reads its goal from the URL,
  not from selection state, so refreshed/shared links work.
- **Responsive layout**: column count comes from window width via `Breakpoints`
  (compact/medium/expanded → 1/2/3 columns), not from the grid's own constraints. Use
  `Wrap` with computed item widths, not `GridView` with `childAspectRatio` (aspect-ratio
  grids overflow at large text sizes).
- **No Melos.** `./tool/dev.sh` handles get/format/analyze/test across packages.

## Tone and language rules (`docs/product/tone-and-language.md`)

Write like a good adviser: plain, specific, on the reader's side. Never patronising,
clinical, bureaucratic, trendy, or academic.

1. Active voice, second person.
2. A control says what it does ("Continue", not "Submit").
3. Sentence case everywhere — headings, buttons, labels.
4. Never label the person ("confused students", "if you're feeling lost"). Describe the
   situation, not the reader. Uncertainty is a situation, not a diagnosis.
5. **No outcome promises** — no "land the job", "guarantee", "ensures you get". Enforced
   by a test in `packages/launchpad_data/test`.
6. Errors explain what happened and what to do; no apologies, never vague.
7. Empty states invite action.
8. **No emoji in the product interface** (screen readers, rendering, contrast).
9. Numbers carry their source and as-of date, or they do not appear.

Content rules that are tested, not just reviewed:

- **Label content by what it actually is.** Bundled occupation text and plan steps are
  AI-assisted drafts, so they carry `EvidenceKind.generatedGuidance` and the interface
  says so. Do not relabel anything `editorial` until a careers adviser has reviewed it
  (`docs/product/content-review.md`).
- **Catalogue text carries no figures.** Pay and employment numbers come only from the
  generated labour-market snapshot, each with source and reference period
  (`docs/product/labour-market-data.md`). Never hand-type a statistic, and never invent
  one for a default or placeholder: no data means the interface says "not loaded".
- **Tools structure a person's own work; they do not grade the person.** No scores,
  streaks or percentages. An automatic check says it is pattern matching and what it
  cannot tell. Tests scan the tool pages for these.
- **New tool state goes in `Workspace.completed` / `choices` / `notes`** with a key helper
  on `Workspace`, not in a new stored field. Free text goes in `notes` and nowhere else.
- **Test fixtures use an invented publisher** ("Test Statistics Office") so invented
  numbers can never be mistaken for real ones.

Recommendations must show their reasoning and provenance (`Evidence.kind`),
express confidence in words not percentages, offer multiple paths including non-degree
routes, never condition on protected characteristics or their proxies, and refer
out-of-scope situations to human services — see
`docs/product/career-recommendation-principles.md`.

## Privacy rules (`docs/privacy/privacy-design.md`)

Data minimisation is a design constraint. The product collects nothing by default, stores
nothing durably without an explicit opt-in, and transmits nothing the person enters — keep
it that way:

- No analytics, advertising, attribution, or crash-reporting SDKs in the dependency tree.
  Check with `flutter pub deps` before adding any dependency.
- Nothing is written to the device before the person presses "Save on this device"
  (`PersistentSessionRepository.enableStorage`). Turning saving off erases the copy. The
  "Something else" free text is never written, opt-in or not. Any new stored field needs a
  row in `docs/privacy/retention.md` and a test, and export and deletion must cover it in
  the same change.
- **Never log personal information** — no user text, answers, or identifiers in logs,
  crash reports, or breadcrumbs. Free text is the highest-risk field.
- Ask only what changes the answer; explain at the point of asking; protected
  characteristics are not collected.
- Anonymous stays first-class: sign-in is never a gate on exploration. Local first.
  Deletion and export must exist before any durable storage ships.
- **Accounts are optional at every level.** No route guard, no feature that checks for a
  sign-in. No email address or name is collected. Nothing is sent to a server unless the
  build has `LAUNCHPAD_API_URL`, the person signed in, turned sync on, and pressed "Sync
  now". Sync never silently overwrites either copy. The "Something else" text is never
  sent. Anything new held on the server needs a row in `docs/privacy/retention.md`.
- **Never log on the server** anything but method, route template, status and duration.
- **No compliance claims** (FERPA, GDPR, CCPA, COPPA, …) anywhere — interface, README, or
  marketing — until legal and technical review is complete.
- **The web build must stay free of third-party requests.** Build it with
  `./tool/build_web.sh` and check it with `node tool/web_audit/audit.cjs` (CI does both).
  Do not add a font, script, image or API call that leaves the page's origin, and do not
  rename the bundled `Roboto` family or move it into a package: the engine only skips its
  Google-hosted download for a family named exactly `Roboto` in the app's own pubspec. The
  claim is limited as set out in `docs/release/web-hosting.md`.
- No signing credentials, provisioning profiles, or store secrets in this repository.

## Accessibility (`docs/accessibility/accessibility-requirements.md`)

WCAG 2.1 AA is part of the definition of done for every screen, and it is tested: 4.5:1
text contrast in both themes, 3:1 non-text boundaries, ≥ 48dp labelled tap targets,
keyboard operation via `ActivateIntent` (no hand-rolled key listeners), descriptions in
the semantics tree at all times, colour never the only signal, opaque text colours, all
durations from `AppMotion` with a real reduce-motion path, layout tested at 2× text
scale. Do not claim conformance anywhere; the audit has not happened.

## Known Flutter hazards — do not rediscover these

- **`AnimatedSize` must not be given `Duration.zero`.** `RenderAnimatedSize` restarts its
  controller inside `performLayout` and trips a "mutated in its own performLayout"
  assertion. The reduce-motion path drops the animation wrapper entirely instead of
  animating over zero milliseconds. See `_RevealedDescription`.
- **`tester.binding.setSurfaceSize` does not feed through to `MediaQuery`.** Layout tests
  relying on it run at the default 800×600 and pass for the wrong reason. Size
  `tester.view` directly.
- **Wrapping the app in a `MediaQuery` to fake brightness, text scale, or reduce-motion
  asserts nothing** — `WidgetsApp` rebuilds `MediaQuery.fromView` internally. Use
  `test/helpers.dart`, which sets these on the test `PlatformDispatcher`.
- **Riverpod 3 does not export the `Override` type**, so test helpers cannot declare
  `List<Override>` parameters. `test/helpers.dart` builds the override list internally
  for this reason.
- Widget tests pump the real `LaunchpadApp` with the real router and theme, not a
  simplified harness — a test that passes against a stand-in tree proves little.
- **`go_router` reuses a page's `State` across values of a path parameter** (one page per
  route pattern). Key the page widget by the parameter if `initState` must run per value.
  See the `/onboarding/:step` route.
- **Widget tests cannot drive real isolates or sockets**, so the account screens are
  tested against `FakeAccountRepository` (`test/helpers.dart`). The real client and server
  are tested together in `packages/launchpad_data/test/account_contract_test.dart`.
- **`find.widgetWithText(Type, …)` matches the exact type**, not subclasses. Use
  `find.bySubtype<ButtonStyleButton>()` with `find.ancestor` to match any button.
- **`dart format` in this workspace reflows to the pre-3.7 style**; when patching a file
  by exact text, read the formatted text first.
- **`flutter analyze` fails on infos**, including `require_trailing_commas` in tests. Run
  `./tool/dev.sh ci` rather than relying on `flutter test` alone.

## Release work (`docs/release/`)

- `ci.yml` builds and verifies without credentials. `release.yml` is the only workflow
  that may touch signing material, and only from the `release` environment's secrets.
  `deploy-web.yml` is manual. Neither of the last two has ever been run; say so if asked.
- An internal review is not an audit. `docs/release/security-review.md` and
  `performance-review.md` are labelled as the author's own; do not cite them as assurance.
- The accessibility audit, the legal review and the editorial review of draft content have
  not happened. Do not tick them, and do not write copy that implies they have.

## Run the tests before claiming work is done

Work is not done until the checks pass. Run:

```sh
./tool/dev.sh test    # every package's tests
./tool/dev.sh ci      # format check + analyze + test, exactly as CI does
```

For a change that could affect what the web build loads (fonts, assets, `web/`, a new
dependency), also run:

```sh
./tool/build_web.sh && node tool/web_audit/audit.cjs
```

Never report a change as complete without having run the tests and seen them pass. If
tests fail or cannot be run, say so explicitly instead of claiming success.

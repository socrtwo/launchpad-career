# Contributing

## Before you start

Open an issue first for anything that changes product copy, data collection, or the
recommendation surface. Those are reviewed against
`docs/product/tone-and-language.md`, `docs/privacy/privacy-design.md`, and
`docs/product/career-recommendation-principles.md`, not just against taste.

## Setup

```bash
./tool/dev.sh get
./tool/dev.sh ci     # format + analyze + test, same as the pipeline
```

## Standards

- **Formatting:** `dart format`. CI fails on any diff.
- **Analysis:** zero issues, including infos. Do not add `// ignore:` without a comment
  explaining why the lint is wrong here.
- **Tests:** new behaviour needs a test. Accessibility behaviour needs an accessibility
  test — `meetsGuideline(...)` and semantics assertions, not just "it renders".
- **Layers:** `launchpad_domain` stays pure Dart. If you find yourself importing Flutter
  into it, the type belongs in `launchpad_core` or `launchpad_ui` instead.
- **Copy:** user-facing strings go in `apps/launchpad_app/lib/src/l10n/app_strings.dart`,
  except editorial catalogue content, which lives in `launchpad_data`.

## Commits and pull requests

- Conventional-commit prefixes are used but not enforced: `feat:`, `fix:`, `docs:`,
  `test:`, `chore:`, `refactor:`.
- One logical change per pull request. Fill in the template, including the accessibility
  and privacy sections — "n/a" is an acceptable answer, silence is not.
- Never commit secrets, signing material, provisioning profiles, `google-services.json`,
  or generated platform folders. `.gitignore` covers the usual cases; it is not a
  substitute for looking at your diff.

## Reviewing

A reviewer should be able to answer three questions from the diff alone: what changed for
the user, what would break if it were wrong, and what data (if any) it now touches.

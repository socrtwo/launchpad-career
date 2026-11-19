# Content awaiting editorial review

The product distinguishes four kinds of source (`EvidenceKind`) and must never pass one
off as another. This page lists content whose current label is "drafted with AI
assistance, not yet reviewed" (`EvidenceKind.generatedGuidance`), and what has to happen
before that label may change.

## What is labelled as a draft today

| Content | Where | Shown to the user as |
| --- | --- | --- |
| Occupation summaries, tasks, skills, routes and change notes | `packages/launchpad_data/lib/src/catalog/occupations.dart` | "This description was drafted with AI assistance in November 2026 and has not yet been reviewed by a careers adviser." on every occupation, comparison, plan and suggestion list |
| Plan step templates | `packages/launchpad_data/lib/src/catalog/plan_templates.dart` | Same label, on every plan page |
| Résumé and LinkedIn checklists, the interview question bank, the weekly job-search plan | `packages/launchpad_data/lib/src/catalog/guidance.dart` | "This guidance was drafted with AI assistance and has not yet been reviewed by a careers adviser." at the foot of every tool |

## What is not a draft

- **Suggestions** are produced by fixed, published rules (`Recommender` in
  `launchpad_domain`) from the person's own answers. They are not model output. The page
  says so and shows the rule behind each suggestion.
- **Pay and employment figures** come only from the labour-market snapshot and are
  labelled with their publisher and reference period.
- **The résumé wording check** is a handful of fixed patterns (`ResumeBulletCheck` in
  `launchpad_domain`). It is not a model, and the page says what it cannot tell.
- **The counts in the weekly job-search plan** divide the time a person said they have.
  They are not statistics about what works, and the page says so before showing one. A
  reviewer should still judge whether the split is sensible.

## Before an entry may be relabelled "written and reviewed by a careers editor"

1. A person with careers-advising experience reads the entry against current, primary
   sources for that occupation (licensing boards, programme accreditors, the Bureau of
   Labor Statistics occupational profile).
2. They check it against `tone-and-language.md` and
   `career-recommendation-principles.md`: no outcome promises, routes that genuinely
   exist, non-degree routes included wherever they genuinely exist and not where they do
   not.
3. The entry's `evidence` is changed to `EvidenceKind.editorial` with the review date, in
   the same change as any corrections.

Known points a reviewer should check first: licensing statements (which vary by state),
whether each listed non-degree route is realistic in the current market, and the
"how this work is changing" notes, which date quickly.

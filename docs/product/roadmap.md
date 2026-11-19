# Roadmap

Phases 1, 2 and 4 are done and Phase 3 is done except for importing real figures.
Everything after that is planned, not built. Progress claims in the interface must match
this document.

## Phase 1 — Foundation (complete)

- [x] Repository, licence, contribution and security policy
- [x] Five-package workspace, layered architecture
- [x] CI: format, analyze, test, web build, unsigned native build verification
- [x] Responsive home page: six goals, single selection, Continue
- [x] "Something else" open-text route
- [x] Light and dark themes with tested contrast
- [x] Declarative routing with deep-linkable goal slugs
- [x] Mock catalogue and session repositories
- [x] Accessibility: keyboard, semantics, targets, text scaling, reduce-motion — tested
- [x] Docs: architecture, product, tone, accessibility, privacy, recommendations

## Phase 2 — Onboarding (complete)

- [x] Preferred name (optional, skippable, never required)
- [x] Current education level
- [x] Planned education
- [x] Primary goal carried forward from the home selection
- [x] Interests and priorities
- [x] Anonymous session support with explicit opt-in before anything is stored
- [x] Resume-where-you-left-off, local only
- [x] Export and deletion of everything held, shipped with storage rather than after it
- [x] Written retention schedule (`docs/privacy/retention.md`)

## Phase 3 — Career exploration (built; data import outstanding)

- [x] Occupation search and browse
- [x] Side-by-side career comparison
- [x] Explainable recommendations with `Evidence` rendering
- [x] Saved options
- [x] Career action plans
- [ ] Real labour-market data source, with attribution and as-of dates
  - [x] Importer for U.S. Bureau of Labor Statistics OEWS figures, with refusal checks
        (`docs/product/labour-market-data.md`)
  - [x] Attribution, reference period, spread and staleness rendering
  - [ ] A snapshot actually imported from the publisher. Until then the interface says
        pay figures are not loaded and shows no numbers.

Occupation descriptions and plan steps are AI-assisted drafts, labelled as such in the
interface, and await review by a careers adviser (`docs/product/content-review.md`).

## Phase 4 — Employment tools (complete)

- [x] Internship and job-search planning — a repeatable week sized to the time available
- [x] Résumé guidance — section checklist and a rule-based wording check for single lines
- [x] LinkedIn guidance — profile checklist; no connection to LinkedIn
- [x] Interview practice — question bank with purpose, tips and example notes
- [x] Skill-gap planning — self-rating against an occupation's skills, and what to work on
- [x] Progress tracking — one page, in words, with no scores or streaks

All tool guidance is an AI-assisted draft, labelled as such in the interface, and awaits
review by a careers adviser (`docs/product/content-review.md`). The tools structure a
person's own work; none of them sees a résumé or a profile, and none grades the person.

## Phase 5 — Backend and accounts

- [ ] Authentication (optional, never a gate on exploration)
- [ ] Secure profiles
- [ ] Data synchronisation
- [ ] Consent management, data export, account deletion
- [ ] Administrative content management for the goal and occupation catalogues

## Phase 6 — Production releases

- [ ] Performance and security review
- [ ] Accessibility audit by someone who uses assistive technology daily
- [ ] Legal and privacy review; only then may any compliance claim appear
- [ ] Store listings and metadata
- [ ] Signed builds in a separate credentialed workflow
- [ ] Web hosting and deployment
- [ ] Monitoring and incident response

## Release strategy (documented, not implemented)

| Channel | Requirements | Status |
| --- | --- | --- |
| Google Play | Play Console account, upload key, signed AAB, data-safety form | not started |
| Apple App Store | Developer Program, provisioning, App Privacy details, review | not started |
| Microsoft Store | Partner Center, MSIX packaging, signing | not started |
| macOS distribution | Developer ID, notarisation, stapling | not started |
| Web hosting | Static host, CSP, self-hosted CanvasKit | not started |
| Versioning | SemVer tags `vX.Y.Z`, release notes generated from conventional commits | not started |

No signing credentials, provisioning profiles, or store secrets are in this repository, and
none may be added. Signed release workflows will live separately from the unsigned build
verification in `ci.yml`.

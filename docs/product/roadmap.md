# Roadmap

Phase 1 is done. Everything after it is planned, not built. Progress claims in the
interface must match this document.

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

## Phase 2 — Onboarding

- [ ] Preferred name (optional, skippable, never required)
- [ ] Current education level
- [ ] Planned education
- [ ] Primary goal carried forward from the home selection
- [ ] Interests and priorities
- [ ] Anonymous session support with explicit opt-in before anything is stored
- [ ] Resume-where-you-left-off, local only

## Phase 3 — Career exploration

- [ ] Occupation search and browse
- [ ] Side-by-side career comparison
- [ ] Explainable recommendations with `Evidence` rendering
- [ ] Saved options
- [ ] Career action plans
- [ ] Real labour-market data source, with attribution and as-of dates

## Phase 4 — Employment tools

- [ ] Internship and job-search planning
- [ ] Résumé guidance
- [ ] LinkedIn guidance
- [ ] Interview practice
- [ ] Skill-gap planning
- [ ] Progress tracking

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

# Roadmap

Phases 1, 2, 4 and 5 are built and Phase 3 is built except for importing real figures.
Phase 6 is prepared as far as code and documents can take it; what remains needs people,
accounts and credentials this project does not have.

"Built" means implemented and tested in this repository. It does not mean deployed,
audited or reviewed. Progress claims in the interface must match this document.

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

## Phase 5 — Backend and accounts (built; not deployed, not independently reviewed)

- [x] Authentication (optional, never a gate on exploration) — a handle and a passphrase;
      no email address is collected, so there is no passphrase reset
- [x] Secure profiles — one document per account behind a bearer token; passphrases are
      salted PBKDF2-HMAC-SHA256, tokens are stored hashed, sign-in is rate limited. The
      design is written down for a reviewer in `services/launchpad_server/README.md`;
      **no independent security review has happened** (Phase 6)
- [x] Data synchronisation — explicit: nothing is sent until the person signs in, turns
      sync on and presses "Sync now". A difference between copies is settled by the
      person, never silently
- [x] Consent management, data export, account deletion — on the service and in the app
- [x] Administrative content management for the goal and occupation catalogues —
      publish, validate and roll back through the server and
      `packages/launchpad_data/tool/catalog.dart`. There is no admin web interface

The server (`services/launchpad_server`) is not deployed anywhere. An app built without
`--dart-define=LAUNCHPAD_API_URL=…` has no accounts and makes no requests.

## Phase 6 — Production releases (prepared; not released)

Each item is split into what could be done in the repository and what could not.

- [ ] Performance and security review
  - [x] Internal review, written up with its method and its limits
        (`docs/release/security-review.md`, `docs/release/performance-review.md`)
  - [ ] Independent security review of the account server and its client
- [ ] Accessibility audit by someone who uses assistive technology daily
  - [x] Brief for the audit (`docs/release/accessibility-audit-brief.md`)
  - [ ] The audit itself. No conformance claim until it is done
- [ ] Legal and privacy review; only then may any compliance claim appear
  - [x] Brief, data inventory and open questions (`docs/release/legal-review-brief.md`)
  - [ ] The review itself; a reviewed privacy notice and terms of use
- [ ] Store listings and metadata
  - [x] Draft listing text and data-safety answers (`docs/release/store-listing.md`);
        web screenshots (`docs/product/screenshots/`)
  - [ ] Store accounts, native screenshots, submission
- [ ] Signed builds in a separate credentialed workflow
  - [x] `release.yml`: verification, audited web package, signed Android bundle that
        checks its own signer, draft release notes. **Never run**: no signing key exists
  - [ ] iOS, macOS and Windows signing, which need accounts and certificates
- [ ] Web hosting and deployment
  - [x] Release build that makes no third-party requests, proved by a browser network
        trace in CI (`docs/release/web-hosting.md`)
  - [x] `deploy-web.yml` for GitHub Pages. **Never run**: needs the Pages source switched
        to GitHub Actions by the repository owner
  - [ ] A deployment on a host that can set security headers
- [ ] Monitoring and incident response
  - [x] Runbook and the signals worth watching (`docs/release/incident-response.md`)
  - [ ] An operator, an on-call arrangement, and something deployed to watch

Also open before any public release: editorial review of the draft content
(`docs/product/content-review.md`), the labour-market data import (Phase 3), and a real
contact address in `SECURITY.md`.

## Release strategy (documented, not implemented)

| Channel | Requirements | Status |
| --- | --- | --- |
| Google Play | Play Console account, upload key, signed AAB, data-safety form | workflow and draft answers written; no account |
| Apple App Store | Developer Program, provisioning, App Privacy details, review | not started |
| Microsoft Store | Partner Center, MSIX packaging, signing | not started |
| macOS distribution | Developer ID, notarisation, stapling | not started |
| Web hosting | Static host, CSP, self-hosted CanvasKit | build and audit done; not deployed |
| Versioning | SemVer tags `vX.Y.Z`, release notes generated from conventional commits | `tool/release_notes.sh`; no release tagged |

No signing credentials, provisioning profiles, or store secrets are in this repository, and
none may be added. The signed release workflow (`release.yml`) is separate from the
unsigned build verification in `ci.yml` and reads its credentials from a protected
environment. See `docs/release/release-process.md`.

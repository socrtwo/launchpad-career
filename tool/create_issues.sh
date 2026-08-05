#!/usr/bin/env bash
# Opens one tracking issue per roadmap area, using the GitHub CLI.
#
#   gh auth login
#   ./tool/create_issues.sh              # dry run, prints what it would create
#   ./tool/create_issues.sh --apply      # actually create them
#
# Requires: gh (https://cli.github.com), authenticated, run inside the clone.

set -euo pipefail

APPLY=false
[ "${1:-}" = "--apply" ] && APPLY=true

command -v gh >/dev/null || { echo "gh CLI not found"; exit 1; }

create() {
  local title="$1" label="$2" body="$3"
  if $APPLY; then
    gh issue create --title "$title" --label "$label" --body "$body"
  else
    echo "[dry run] $title  ($label)"
  fi
}

if $APPLY; then
  for label in phase-2 phase-3 phase-4 phase-5 phase-6 accessibility privacy epic; do
    gh label create "$label" --force >/dev/null 2>&1 || true
  done
fi

create "Phase 2: Onboarding" "epic,phase-2" \
"Preferred name (optional), current education level, planned education, primary goal carried forward, interests and priorities, anonymous session support.

Constraint: nothing is stored durably until consent and a retention policy exist. See docs/privacy/privacy-design.md.
Roadmap: docs/product/roadmap.md"

create "Phase 3: Career exploration" "epic,phase-3" \
"Occupation search and browse, comparison view, explainable recommendations, saved options, action plans.

Every displayed claim must carry Evidence provenance. See docs/product/career-recommendation-principles.md."

create "Phase 4: Employment tools" "epic,phase-4" \
"Internship and job-search planning, resume guidance, LinkedIn guidance, interview practice, skill-gap planning, progress tracking."

create "Phase 5: Backend and accounts" "epic,phase-5" \
"Authentication, secure profiles, synchronisation, consent management, export, deletion, content management.

Anonymous use must remain fully functional. Sign-in is never a gate on exploration."

create "Phase 6: Production releases" "epic,phase-6" \
"Performance and security review, accessibility audit, legal and privacy review, store preparation, signed builds, web deployment, monitoring.

Signed release workflows live separately from the unsigned verification in ci.yml."

create "Labour-market data source and attribution" "phase-3" \
"Select a data source, implement the Evidence pipeline, and render source plus as-of date everywhere a figure appears. Define the staleness threshold."

create "Replace the string table with ARB localisation" "phase-2" \
"Migrate lib/src/l10n/app_strings.dart to gen_l10n/ARB and add a second locale to prove the plumbing."

create "Accessibility audit with assistive technology users" "accessibility,phase-6" \
"Manual audit against docs/accessibility/accessibility-requirements.md, including the manual checklist and forced-colours mode on web. No conformance claim may be published before this closes."

create "Privacy notice, terms, consent, export and deletion" "privacy,phase-5" \
"Replace the /privacy placeholder with reviewed content and build the four missing controls. No compliance claim before legal review."

create "Self-host CanvasKit and audit runtime network requests" "privacy,phase-6" \
"Flutter web may fetch fallback fonts from Google-hosted URLs at runtime. Self-host and verify with a network trace before any 'no third-party requests' claim."

create "Persist session state locally, behind consent" "phase-2" \
"Replace InMemorySessionRepository with a local store. Requires a consent flow, a retention policy, and a working delete."

create "Screenshots and store-listing assets" "phase-6" \
"Populate docs/product/screenshots/ and the README screenshot table for phone, tablet and desktop, in both themes."

$APPLY || echo
$APPLY || echo "Dry run. Re-run with --apply to create these."

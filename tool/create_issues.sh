#!/usr/bin/env bash
# Opens one tracking issue for each thing still open in docs/product/roadmap.md,
# using the GitHub CLI. Keep this list in step with the roadmap: an issue for
# work that is already done is worse than no issue.
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
  for label in phase-3 phase-6 accessibility privacy security content needs-people; do
    gh label create "$label" --force >/dev/null 2>&1 || true
  done
fi

create "Import labour-market figures from the Bureau of Labor Statistics" "phase-3" \
"Register a free BLS API key, then run packages/launchpad_data/tool/import_oews.dart with BLS_API_KEY set, --save-responses and --occupation-table, check a few figures against the Bureau website, and commit the generated snapshot. Unregistered attempts were refused on 20 Nov 2026. Until then the interface shows no pay figures and says so. See docs/product/labour-market-data.md."

create "Editorial review of draft occupation and guidance content" "content,needs-people" \
"Every occupation description, plan step and tool guide is an AI-assisted draft and is labelled as one. A careers adviser needs to review each against primary sources before it is relabelled. See docs/product/content-review.md."

create "Accessibility audit with assistive technology users" "accessibility,phase-6,needs-people" \
"Not done. Brief, tasks and known risks: docs/release/accessibility-audit-brief.md. No conformance claim may be published before this closes."

create "Legal and privacy review; privacy notice and terms of use" "privacy,phase-6,needs-people" \
"Not done. Data inventory and open questions: docs/release/legal-review-brief.md. No compliance claim before this closes."

create "Independent security review of the account server and client" "security,phase-6,needs-people" \
"Not done. The internal review and fourteen known weaknesses are in docs/release/security-review.md. Needed before the server is deployed anywhere."

create "Host fallback fonts so non-Latin text renders on the web" "accessibility,phase-6" \
"The web build fetches no fonts from a third party, so typed text outside Latin, Greek and Cyrillic is drawn as empty boxes. Serve the Noto families under fallback-fonts/ on the same origin. See docs/release/web-hosting.md."

create "First signed release: set up the release environment and run release.yml" "phase-6,needs-people" \
"release.yml has never been run. Needs an upload key, the release environment and its secrets, and store accounts. iOS, macOS and Windows signing are not scripted. See docs/release/release-process.md."

create "Deploy the web build on a host that can set security headers" "phase-6,needs-people" \
"deploy-web.yml targets GitHub Pages and has never been run (the Pages source must be switched to GitHub Actions first). Pages cannot set headers; see the header table in docs/release/web-hosting.md."

create "Replace the SECURITY.md placeholder with a monitored address" "security,needs-people" \
"The reporting address is still a placeholder. Needed before anything is deployed."

create "Replace the string table with ARB localisation" "phase-6" \
"Migrate lib/src/l10n/ to gen_l10n/ARB and add a second locale to prove the plumbing. Catalogue and guidance content needs the same treatment through the published-catalogue route."

create "Native screenshots and store submission" "phase-6,needs-people" \
"Web screenshots exist in docs/product/screenshots/. Native captures, store accounts and submission are open. Draft listing: docs/release/store-listing.md."

$APPLY || echo
$APPLY || echo "Dry run. Re-run with --apply to create these."

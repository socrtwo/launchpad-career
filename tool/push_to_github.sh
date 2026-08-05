#!/usr/bin/env bash
# Creates the GitHub repository and pushes this working tree to it.
#
#   gh auth login
#   ./tool/push_to_github.sh <owner> [--public]
#
# Nothing here is automatic: it prints each command's effect and stops on error.

set -euo pipefail

OWNER="${1:-}"
VISIBILITY="--private"
[ "${2:-}" = "--public" ] && VISIBILITY="--public"

[ -n "$OWNER" ] || { echo "usage: $0 <owner> [--public]"; exit 1; }
command -v gh >/dev/null || { echo "gh CLI not found"; exit 1; }

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

DESCRIPTION="Cross-platform career planning and employment guidance for students and recent graduates."

gh repo create "$OWNER/launchpad-career" \
  $VISIBILITY \
  --description "$DESCRIPTION" \
  --source . \
  --remote origin \
  --push

echo
echo "Pushed. Next:"
echo "  ./tool/create_issues.sh --apply    # open the roadmap issues"
echo "  gh repo edit --enable-issues --enable-discussions"
echo "  Settings > Branches: protect main, require the CI check"

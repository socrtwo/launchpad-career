#!/usr/bin/env bash
# Prints release notes for a tag, grouped by conventional-commit type.
#
#   ./tool/release_notes.sh v0.6.0
#
# Covers the commits between the previous version tag and the one given (or
# HEAD, if the tag does not exist yet). Merge commits are left out.

set -euo pipefail

TAG="${1:?Give the version tag, for example v0.6.0}"
END="$TAG"
git rev-parse -q --verify "refs/tags/$TAG" >/dev/null || END="HEAD"
PREVIOUS="$(git describe --tags --abbrev=0 --match 'v*.*.*' "$END^" 2>/dev/null || true)"
RANGE="$END"
[ -n "$PREVIOUS" ] && RANGE="$PREVIOUS..$END"

subjects="$(git log --no-merges --pretty=format:%s "$RANGE")"

section() {
  local title="$1" pattern="$2" lines
  lines="$(printf '%s\n' "$subjects" | grep -E "^$pattern(\([^)]*\))?!?: " | sed -E "s/^$pattern(\([^)]*\))?!?: /- /" || true)"
  if [ -n "$lines" ]; then
    printf '## %s\n\n%s\n\n' "$title" "$lines"
  fi
}

printf '# %s\n\n' "$TAG"
if [ -n "$PREVIOUS" ]; then
  printf 'Changes since %s.\n\n' "$PREVIOUS"
fi
section "Added" "feat"
section "Fixed" "fix"
section "Documentation" "docs"
section "Build and dependencies" "(build|ci|chore)"

other="$(printf '%s\n' "$subjects" | grep -Ev '^(feat|fix|docs|build|ci|chore)(\([^)]*\))?!?: ' | sed 's/^/- /' || true)"
if [ -n "$other" ]; then
  printf '## Other\n\n%s\n\n' "$other"
fi

cat <<'NOTE'
---
Launchpad Career offers guidance, not guarantees about admission, hiring, or pay.
See docs/product/roadmap.md for what is and is not finished.
NOTE

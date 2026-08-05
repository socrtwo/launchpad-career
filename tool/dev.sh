#!/usr/bin/env bash
# Workspace helper. Replaces Melos for a five-package, path-linked workspace.
#
#   ./tool/dev.sh get       resolve dependencies everywhere
#   ./tool/dev.sh format    format in place
#   ./tool/dev.sh analyze   analyze every package
#   ./tool/dev.sh test      run every package's tests
#   ./tool/dev.sh ci        format check + analyze + test, exactly as CI does
#   ./tool/dev.sh clean     remove build output and .dart_tool

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# Dependency order: leaves first.
PACKAGES=(
  packages/launchpad_domain
  packages/launchpad_data
  packages/launchpad_core
  packages/launchpad_ui
  apps/launchpad_app
)

each() {
  for package in "${PACKAGES[@]}"; do
    echo "== $package: $*"
    (cd "$package" && "$@")
  done
}

case "${1:-}" in
  get)
    each flutter pub get
    ;;
  format)
    dart format apps packages
    ;;
  analyze)
    each flutter analyze
    ;;
  test)
    for package in "${PACKAGES[@]}"; do
      if [ -d "$package/test" ]; then
        echo "== $package: flutter test"
        (cd "$package" && flutter test)
      fi
    done
    ;;
  ci)
    dart format --output=none --set-exit-if-changed apps packages
    each flutter analyze
    "$0" test
    ;;
  clean)
    each flutter clean
    ;;
  *)
    sed -n '2,10p' "$0"
    exit 1
    ;;
esac

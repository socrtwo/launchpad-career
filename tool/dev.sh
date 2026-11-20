#!/usr/bin/env bash
# Workspace helper. Replaces Melos for a small, path-linked workspace.
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

# Dependency order: leaves first. The server is a pure Dart package with no
# dependency on the others; the data package's contract tests run against it.
PACKAGES=(
  services/launchpad_server
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
    dart format apps packages services
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
    dart format --output=none --set-exit-if-changed apps packages services
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

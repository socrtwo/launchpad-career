#!/usr/bin/env bash
# Builds the web app for release with nothing left to fetch from a third party.
#
#   ./tool/build_web.sh [--base-href=/path/] [--api-url=https://sync.example.org]
#                       [--allow-google-fonts]
#
# What it does beyond `flutter build web`:
#
#   --no-web-resources-cdn   CanvasKit is served from the build output instead
#                            of a Google-hosted address.
#   --csp                    The compiled JavaScript does not generate code at
#                            run time, so the page can forbid it.
#   Content-Security-Policy  A meta tag is written into index.html that limits
#                            the page to its own origin (plus the account
#                            service, if --api-url is given). This is also what
#                            stops the engine fetching fallback fonts.
#
# The typeface is bundled by the app under the family name "Roboto", so the
# default font is never fetched, and web/flutter_bootstrap.js points the
# engine's fallback-font lookups at this site's own origin.
# tool/web_audit/audit.cjs checks the result with a browser network trace.
#
# --allow-google-fonts restores Flutter's default: characters outside the
# bundled typeface (most non-Latin scripts, emoji) are drawn with fonts fetched
# from fonts.gstatic.com. That discloses each visitor's network address to
# Google, so a build made this way must not be described as making no
# third-party requests.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BASE_HREF="/"
API_URL=""
GOOGLE_FONTS=false

for argument in "$@"; do
  case "$argument" in
    --base-href=*) BASE_HREF="${argument#*=}" ;;
    --api-url=*) API_URL="${argument#*=}" ;;
    --allow-google-fonts) GOOGLE_FONTS=true ;;
    *)
      sed -n '2,6p' "$0"
      exit 64
      ;;
  esac
done

CONNECT="'self'"
DEFINES=()
if [ -n "$API_URL" ]; then
  case "$API_URL" in
    https://*) ;;
    http://localhost*|http://127.0.0.1*) ;;
    *)
      echo "The account service address must be https:// (or http://localhost)." >&2
      exit 64
      ;;
  esac
  # Scheme and authority only: a policy source has no path.
  ORIGIN="$(printf '%s' "$API_URL" | sed -E 's#^(https?://[^/]+).*#\1#')"
  CONNECT="'self' $ORIGIN"
  DEFINES+=("--dart-define=LAUNCHPAD_API_URL=$API_URL")
fi

cd "$ROOT/apps/launchpad_app"
flutter build web --release --no-web-resources-cdn --csp \
  --base-href="$BASE_HREF" "${DEFINES[@]}"

if [ "$GOOGLE_FONTS" = true ]; then
  CONNECT="$CONNECT https://fonts.gstatic.com"
  BOOTSTRAP="build/web/flutter_bootstrap.js"
  if ! grep -q 'FONT_FALLBACK_BASE' "$BOOTSTRAP"; then
    echo "flutter_bootstrap.js has no fallback-font marker; cannot switch it." >&2
    exit 1
  fi
  awk '{ if ($0 ~ /FONT_FALLBACK_BASE/) print "    fontFallbackBaseUrl: \x27https://fonts.gstatic.com/s/\x27,"; else print }' \
    "$BOOTSTRAP" > "$BOOTSTRAP.tmp"
  mv "$BOOTSTRAP.tmp" "$BOOTSTRAP"
fi

POLICY="default-src 'self'; script-src 'self' 'wasm-unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: blob:; font-src 'self'; connect-src $CONNECT; worker-src 'self' blob:; object-src 'none'; base-uri 'self'; form-action 'none'"
INDEX="build/web/index.html"

if ! grep -q '<!-- CSP_PLACEHOLDER -->' "$INDEX"; then
  echo "index.html has no CSP placeholder; refusing to ship a build without a policy." >&2
  exit 1
fi
META="<meta http-equiv=\"Content-Security-Policy\" content=\"$POLICY\">"
# Written with a temporary file so the script behaves the same with GNU and BSD sed.
awk -v meta="$META" '{ sub(/<!-- CSP_PLACEHOLDER -->/, meta); print }' "$INDEX" > "$INDEX.tmp"
mv "$INDEX.tmp" "$INDEX"

echo "Built $ROOT/apps/launchpad_app/build/web"
echo "connect-src: $CONNECT"
if [ "$GOOGLE_FONTS" = true ]; then
  echo "This build fetches fallback fonts from fonts.gstatic.com."
fi

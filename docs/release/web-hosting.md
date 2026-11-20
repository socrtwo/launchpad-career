# Web hosting

## What the release build guarantees

Built with `./tool/build_web.sh` and no options, the web app requests nothing from any
origin but its own. This is checked, not assumed: `tool/web_audit/audit.cjs` loads the
build in Chromium, visits eight routes at four viewport sizes, types Chinese, Korean,
Arabic, Greek and emoji into a text field, records every request, and fails if one leaves
the origin or if the content security policy had to block anything. CI runs it on every
pull request.

Three things make that true, and each was found necessary by the audit:

| Leak in a default Flutter web build | What stops it |
| --- | --- |
| CanvasKit (the renderer) is downloaded from `www.gstatic.com` | `--no-web-resources-cdn`: it is served from the build output |
| Roboto is downloaded from `fonts.gstatic.com` | The app bundles Roboto and registers it under exactly the family name `Roboto` (`apps/launchpad_app/pubspec.yaml`). A package-prefixed family name does **not** stop the download |
| Fallback fonts for characters Roboto lacks are downloaded from `fonts.gstatic.com` | `web/flutter_bootstrap.js` sets `fontFallbackBaseUrl` to the site's own origin |

A content security policy (`default-src 'self'`, no run-time code generation) is written
into `index.html` as a second line of defence. It is added at build time rather than kept
in the source file because the debug compiler used by `flutter run` needs script features
the policy forbids.

## The trade-off: non-Latin text

No fallback fonts are hosted yet, so text a person **types** in a script Roboto does not
cover (Chinese, Japanese, Korean, Arabic, Hebrew, Devanagari, Thai, emoji and others) is
drawn as empty boxes in the web build. The app's own text is English and unaffected, and
the native builds use the platform's fonts. The in-app accessibility page says this.

Two ways to lift the limitation:

1. **Host the fonts.** Serve the Noto families the engine asks for under
   `fallback-fonts/` on the same origin. The engine requests paths such as
   `fallback-fonts/notosanssc/v37/<file>.woff2`; the audit's request log lists them.
   This keeps the guarantee.
2. **Allow Google's.** `./tool/build_web.sh --allow-google-fonts` restores Flutter's
   default and adds `https://fonts.gstatic.com` to the policy. Each visitor's network
   address is then disclosed to Google when such text is drawn. A build made this way
   must not be described as making no third-party requests.

## Builds with an account service

`./tool/build_web.sh --api-url=https://sync.example.org` compiles the address in and adds
its origin to `connect-src`. Such a build talks to that service when a person uses the
account page, and fetches the published catalogues from it on start. The server must list
the site's origin in `ALLOWED_ORIGINS`.

## Headers the host should send

A meta-tag policy cannot express everything. The host should add:

| Header | Value | Why |
| --- | --- | --- |
| `Content-Security-Policy` | the policy from `index.html`, plus `frame-ancestors 'none'` | `frame-ancestors` is ignored in a meta tag |
| `Strict-Transport-Security` | `max-age=31536000; includeSubDomains` | HTTPS only |
| `Referrer-Policy` | `no-referrer` | Deep links carry a goal or occupation slug |
| `X-Content-Type-Options` | `nosniff` | |
| `Permissions-Policy` | `camera=(), microphone=(), geolocation=()` | The app uses none of them |
| `Cache-Control` | long-lived for `canvaskit/` and `assets/`, `no-cache` for `index.html`, `flutter_bootstrap.js` and `main.dart.js` | The entry files are not content-hashed |

GitHub Pages cannot set custom headers. It is adequate for a preview; a real deployment
belongs on a host that can.

## Deploying

`.github/workflows/deploy-web.yml` builds, audits, and publishes the landing page at the
site root with the app under `/app/`. It is manual (`workflow_dispatch`) and **has never
been run**: it needs the repository's Pages source changed from "Deploy from a branch" to
"GitHub Actions", which is the owner's decision. Nothing is deployed until that is done
and the workflow is started by hand.

## What may be claimed

- "The web app makes no requests to third parties" — for a default `build_web.sh` build,
  while the audit passes.
- Not for a build with `--allow-google-fonts`.
- Not about the landing page (`docs/index.html`), which loads the README from GitHub's API.
- Nothing about what the hosting provider itself logs.

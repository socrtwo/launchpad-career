# Release process

## Versioning

Semantic versioning, tags `vX.Y.Z` on `main`. The tag must equal `version:` in
`apps/launchpad_app/pubspec.yaml` (the release workflow checks). Release notes come from
conventional-commit subjects: `./tool/release_notes.sh vX.Y.Z`.

## Before tagging

- [ ] `./tool/dev.sh ci` passes on `main`
- [ ] `./tool/build_web.sh && node tool/web_audit/audit.cjs` passes
- [ ] `docs/product/roadmap.md` matches what the build does
- [ ] `docs/privacy/retention.md` has a row for everything newly stored or sent
- [ ] The manual accessibility checklist in
      `docs/accessibility/accessibility-requirements.md` has been run on one platform
- [ ] No compliance or conformance claim has crept into the interface, README or listing
- [ ] `version:` bumped

## Workflows

| Workflow | Trigger | Holds credentials | Status |
| --- | --- | --- | --- |
| `ci.yml` | every pull request and push to `main` | no | running |
| `deploy-web.yml` | manual | no (uses the Pages token) | written, never run |
| `release.yml` | a `v*.*.*` tag, or manual | yes, from the `release` environment | written, never run |

`release.yml` is separate from `ci.yml` so that unsigned verification builds and signed
release builds never share a job, and so the `release` environment can require a reviewer.

### Setting up the `release` environment

1. Settings → Environments → new environment `release`; add required reviewers.
2. Secrets: `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`,
   `ANDROID_KEY_PASSWORD`.
3. Variable: `ANDROID_CERT_SHA256` — the upload certificate's fingerprint exactly as
   `keytool -list -v` prints it.

The Android job signs through the Android Gradle plugin's injected signing properties,
written to the runner's own Gradle properties outside the checkout, because platform
folders are generated rather than committed. It then reads the signer back out of the
bundle and fails unless the fingerprint matches. **It has not been run with a real key.**
Expect to adjust it the first time.

## Channels

| Channel | Needs | Automated here | Status |
| --- | --- | --- | --- |
| Web | A static host that can set headers (`web-hosting.md`) | build, audit, package; Pages deploy | not deployed |
| Google Play | Play Console account, upload key, data-safety form | signed bundle | not started; no account |
| Apple App Store | Developer Program, provisioning, App Privacy details, review | nothing | not started; no account |
| macOS direct | Developer ID, notarisation, stapling | nothing | not started |
| Microsoft Store | Partner Center, MSIX packaging, signing | nothing | not started |
| Account server | A host, TLS termination, backups, an operator | Dockerfile only; image never built in CI | not deployed |

iOS, macOS and Windows signing are deliberately not scripted: each needs an account and
certificates this project does not have, and a workflow written without them could not be
tested even for syntax against the real services.

## Before any public release

These are not engineering tasks and none is done. Each has a brief in this folder.

- An accessibility audit by people who use assistive technology daily
  (`accessibility-audit-brief.md`)
- Legal and privacy review (`legal-review-brief.md`)
- An independent security review if the account server is to be deployed
  (`security-review.md`)
- Editorial review of the draft content (`../product/content-review.md`)
- A real, monitored address in `SECURITY.md`

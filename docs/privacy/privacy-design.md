# Privacy design

## Position

Data minimisation is a design constraint, not a later feature. The product collects
nothing by default, stores nothing durably unless the person opts in, and transmits
nothing they enter. Everything below describes how that is kept true as features arrive.

## Current state (Phase 5)

- No email, no device identifier. Accounts are optional and exist only in a build made
  with an account service address; the default build has none and makes no requests.
- An account is a handle and a passphrase. Signing in sends nothing but those. Sync is a
  separate, explicit opt-in recorded on the service, and a copy is sent only when "Sync
  now" is pressed. Turning sync off deletes the copy. The app shows what the service
  holds and deletes the account on request. See [`retention.md`](retention.md).
- `Session` holds the chosen goal, an optional `Profile` (preferred name, education so
  far, planned education, interests, priorities), the onboarding step reached, and the
  free text typed into "Something else". All of it is optional and all of it is something
  the person chose or typed; nothing is inferred.
- Everything lives in memory until the person presses **Save on this device**.
  `PersistentSessionRepository` then mirrors the session to the platform preference store
  (browser local storage on the web). The free text is never written, opt-in or not.
- The opt-in, the twelve-month expiry, export and deletion are specified in
  [`retention.md`](retention.md) and enforced by tests in `packages/launchpad_data/test`
  and `apps/launchpad_app/test/your_data_test.dart`.
- Every question states why it is asked next to the question, and every one can be
  skipped.
- The session also holds a `Workspace`: saved occupations, plans, and steps marked done.
  Steps a person writes themselves are free text and are treated like the rest of the
  session: memory until opt-in, then the device store, covered by export and deletion.
- The employment tools add checklists, self-ratings and notes to the `Workspace`. Notes
  are free text and follow the same rule as everything else. The tools never ask for a
  résumé or a profile: a person works on their own documents with the guide beside them.
  A résumé line typed into the wording check is examined on the device and forgotten
  unless the person presses "Keep this line". Nothing connects to LinkedIn.
- Searching the catalogue happens on the device against bundled data. The query is not
  stored and nothing is requested from a server. Labour-market figures are compiled into
  the app for the same reason: reading about an occupation discloses nothing.
- Suggestions read interests, education and priorities only. They take no name, age,
  location or institution; a test pins that the preferred name cannot change the result.
- No analytics, advertising, attribution, or crash-reporting SDK is in the dependency tree.
  Check with `flutter pub deps` before adding anything. The only plugin is
  `shared_preferences`.
- Nothing logs. A failed write is reported to the person on screen and nowhere else.

## Rules for future work

1. **Ask only what changes the answer.** If a field would not alter the guidance produced,
   it is not collected.
2. **Explain at the point of asking.** Any sensitive or unexpected question carries a
   one-line reason next to the field, not in a policy page nobody opens.
3. **Protected characteristics are not collected** — age band, race, ethnicity, disability,
   national origin, gender identity, immigration status — unless a specific feature makes
   them necessary, the reason is written down, and they are optional with a visible skip.
4. **Never log personal information.** No user text, no answers, no identifiers in logs,
   crash reports, or breadcrumbs. Free text is the highest-risk field in the product.
5. **Anonymous stays first-class.** Any account feature must have a fully functional
   anonymous path. Sign-in is never a gate on exploration.
6. **Local first.** Data that can stay on the device stays on the device.
7. **Deletion and export are features, not requests.** Both must exist before any durable
   storage ships.

## Placeholders that must be replaced before release

| Item | Where | Status |
| --- | --- | --- |
| Privacy notice | `/privacy` route | describes this build; not a reviewed notice |
| Terms of use | not built | missing |
| Consent for local storage | `/your-data`, onboarding review | built |
| Local data export | `/your-data` | built (on screen and to the clipboard) |
| Local data deletion | `/your-data` | built |
| Retention schedule | `docs/privacy/retention.md` | written for local data |
| Consent for sync | `/account` | built |
| Account data export | `/account` | built |
| Account deletion | `/account` | built |
| Sub-processor list | nothing is deployed, so there are none | to be written by whoever deploys the service |

## No compliance claims

The product does **not** claim FERPA, GDPR, UK GDPR, CCPA/CPRA, COPPA, or any other
regulatory compliance, and no such claim may be added to the interface, the README, or
marketing material until legal and technical review is complete. Note that student career
conversations may be education records in some deployments, and that a product aimed at
undergraduates will be used by some people under 18 — both need review before any claim.

## Known technical leak paths

- **Web fonts.** Flutter's CanvasKit renderer can fetch fallback fonts from Google-hosted
  URLs at runtime, which discloses the user's IP to a third party. Self-host CanvasKit
  (`--web-renderer` configuration and `FLUTTER_WEB_CANVASKIT_URL`) before making any "no
  third-party requests" claim. Icon and Material fonts are already bundled.
- **Store and platform telemetry** is outside the app's control; document it rather than
  claim it away.
- **CI artefacts.** Build artefacts uploaded by workflows must never include user data;
  they currently include only compiled output.

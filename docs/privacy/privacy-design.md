# Privacy design

## Position

Data minimisation is a design constraint, not a later feature. The product currently
collects nothing, stores nothing durably, and transmits nothing. Everything below describes
how that is kept true as features arrive.

## Current state (Phase 1)

- No account, no name, no email, no device identifier.
- `Session` holds an optional preferred name and the free text typed into "Something else",
  both in memory only, both cleared when the process ends.
- `InMemorySessionRepository` is deliberately not backed by `shared_preferences` or a
  database. Nothing the user types survives a restart until there is a consent flow and a
  documented retention policy.
- No analytics, advertising, attribution, or crash-reporting SDK is in the dependency tree.
  Check with `flutter pub deps` before adding anything.

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
| Privacy notice | `/privacy` route | placeholder text |
| Terms of use | not built | missing |
| Consent management | not built | missing |
| Account deletion | not built | missing |
| Data export | not built | missing |
| Retention schedule | not written | missing |
| Sub-processor list | not written | missing |

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

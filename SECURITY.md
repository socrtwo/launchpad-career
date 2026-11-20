# Security policy

## Supported versions

The project is pre-release. Only `main` is supported; there are no maintained release
branches yet.

| Version | Supported |
| --- | --- |
| `main` | yes |
| tagged pre-releases | no |

## Reporting a vulnerability

Report privately. Do **not** open a public issue for a security problem.

- Preferred: GitHub → **Security** → **Report a vulnerability** (private advisory).
- Alternative: email the maintainers at `security@<domain>` — replace this with a real
  monitored address before the repository is made public.

Please include what you were doing, what happened, the platform and build, and a
proof of concept if you have one.

**Expected response:** acknowledgement within 5 business days, an initial assessment within
10, and coordinated disclosure once a fix is available. We will credit reporters who want
credit.

## Scope

In scope: this repository's application and package code, its CI workflows, and its
dependency configuration.

Also in scope: the optional account and sync server in `services/launchpad_server`
(authentication, token handling, consent enforcement, rate limiting, the data store) and
the app's client for it. Its design and the limitations already known are written down in
`services/launchpad_server/README.md` and `docs/release/security-review.md`; reports that
go beyond those are especially welcome.

Out of scope for now: any particular deployment. This project does not run the server
anywhere, so there is no production system to test against. Do not test against a
deployment you do not operate.

## Notes on secrets

This repository contains no API keys, signing certificates, provisioning profiles, or
production credentials, and must not. If you find any committed, treat it as a security
report and follow the process above.

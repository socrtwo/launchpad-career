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

Out of scope for now: there is no backend, no authentication, and no production deployment.
Findings that depend on those will be re-scoped when Phase 5 lands.

## Notes on secrets

This repository contains no API keys, signing certificates, provisioning profiles, or
production credentials, and must not. If you find any committed, treat it as a security
report and follow the process above.

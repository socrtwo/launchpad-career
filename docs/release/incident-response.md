# Monitoring and incident response

**Status: written, not in use.** Nothing is deployed, so nothing is monitored and there is
no on-call. This is the plan an operator starts from.

## What can be monitored without watching people

The app has no telemetry and gets none. That is a product decision
(`docs/privacy/privacy-design.md`), so client-side failures are learned about from people
telling us, through the issue tracker.

The account server can be monitored from the outside and from its own log:

| Signal | Source | Alert when |
| --- | --- | --- |
| Up | `GET /healthz` from an external checker | two consecutive failures |
| Errors | request log: `status=5xx` | any sustained rate |
| Overload | request log: `status=503` on sign-in routes | sustained; the hashing queue is full |
| Abuse | request log: `status=429` | a sharp rise |
| Latency | request log: `duration_ms` by route template | sign-in is about a second by design; alert on the others |
| Disk | host | the data file's volume filling |
| Certificate expiry | the TLS proxy | 14 days out |

The request log holds a method, a route template, a status and a duration, and nothing
else. Do not add fields to it to make an investigation easier.

## Severity

| Level | Meaning | Examples |
| --- | --- | --- |
| 1 | People's data exposed, altered or lost; or the service compromised | data file read by an outsider; admin token leaked; a published catalogue that harms |
| 2 | The service is down or wrong for everyone | sign-in failing; sync returning errors |
| 3 | Degraded or wrong for some | one route slow; a bad catalogue entry |

## First hour

1. **Stop the harm.** Level 1: take the server offline, or rotate `ADMIN_TOKEN` and roll
   back the catalogue (`tool/catalog.dart rollback`). A build without an account service
   keeps working when the server is down, because nothing in it depends on the server.
2. **Preserve evidence.** Copy the data file and the logs before changing anything.
3. **Write down** what is known, with times, in a private place. Not in a public issue.
4. **Decide who must be told.** If data may have been exposed, that is a legal question
   with deadlines; involve whoever answers it (`legal-review-brief.md`).

## Afterwards

- A written account within a week: what happened, what was affected, what changed.
- Revoke sign-ins if tokens may be exposed: delete the token records, which forces
  everyone to sign in again. If the data file was read, passphrase hashes are exposed;
  tell account holders plainly and ask them to change the passphrase.
- Add a test for whatever let it happen.

## Reports from outside

Security reports follow `SECURITY.md`. The contact address there is still a placeholder
and must be replaced with a monitored one before anything is deployed.

# Security review (internal)

**What this is.** A review of the code in this repository by its author, an AI coding
assistant, in November 2026, recorded so that a human reviewer has somewhere to start.

**What this is not.** An independent security audit or a penetration test. Nobody outside
the project has reviewed this code, and nothing here should be read as assurance. The
roadmap item for an independent review stays open.

## Scope and method

- Read the server's authentication, token, consent, storage and request-handling code,
  and the client that talks to it.
- Ran the test suites: 250 server tests, plus contract tests that drive the real server
  handler from the app's client.
- Mutation check on the server, carried out by the automated agent that wrote the server
  package and reported by it, not repeated afterwards: twelve security-relevant lines were
  broken one at a time (logging the URL, skipping the dummy hash, skipping the body limit,
  writing the data file in place, and others) and the suite failed each time.
- Browser network trace of the release web build (`web-hosting.md`).
- `pub get` reported no security advisories, discontinued or retracted packages for the
  app or the server on the date of the review.

## What holds, with the evidence

| Property | Evidence |
| --- | --- |
| Passphrases are stored only as salted PBKDF2-HMAC-SHA256 (600,000 iterations by default) | `crypto_test.dart`, checked against published vectors |
| Unknown handle and wrong passphrase are indistinguishable in status, body and work done | `accounts_test.dart` |
| Tokens are 256-bit random, stored hashed, expire, and are revoked on sign-out, passphrase change and deletion | `accounts_test.dart` |
| Sign-in is rate limited per handle and per client | `rate_limiter_test.dart`, `account_contract_test.dart` |
| The server refuses to store a profile without consent and deletes it when consent is withdrawn | `sync_test.dart`, `account_contract_test.dart` |
| Request bodies are size-limited while being read | `http_test.dart` |
| The request log cannot contain a handle, passphrase, token, address or profile content | `http_test.dart` |
| The client never stores the passphrase, and stores the token only with the person's storage opt-in | `account_contract_test.dart` |
| The "Something else" text never leaves the device | `account_contract_test.dart` inspects everything sent |
| The service address must be HTTPS (or this machine) | `account_contract_test.dart`, `tool/build_web.sh` |
| The default web build makes no third-party requests | `tool/web_audit/audit.cjs` in CI |
| No analytics, advertising or crash-reporting package is in the dependency tree | `flutter pub deps`, checked at each phase |

## Known weaknesses

None of these is fixed. Each is a decision for whoever deploys the server.

1. **PBKDF2 is not memory-hard.** A stolen data file can be attacked on GPUs far faster
   than the server hashes. Argon2id would be better and needs a dependency.
2. **The data file is not encrypted at rest**, and Dart cannot set its permissions; only
   the container's directory mode protects it.
3. **No account recovery**, by design: no contact details are held.
4. **Five wrong guesses lock a handle for fifteen minutes**, including for its owner. That
   is a cheap way to annoy a known handle.
5. **Account creation reveals whether a handle is taken** (limited to ten attempts per
   client per hour).
6. **Sign-in is deliberately expensive**, so many clients together can fill the hashing
   queue and cause 503s.
7. **`TRUST_PROXY=true` trusts the first `X-Forwarded-For` value**, which the client
   controls unless the proxy overwrites it.
8. **Rate-limit state is per process and in memory.** A restart clears it; it does not
   work across replicas.
9. **Withdrawing consent resets the profile revision**, so in a narrow case a stale device
   could overwrite a newer document without a conflict.
10. **One shared admin token** and no record of who published a catalogue.
11. **On the web, the sign-in token is in browser local storage** when the person has
    storage on. Any script running on the origin could read it; the content security
    policy is what stands in the way.
12. **Sync is not end-to-end encrypted.** The operator of the server can read synced
    answers and notes.
13. **The single-file store rewrites the whole file on each change** and is suitable for
    small pilots only.
14. **The server speaks plain HTTP** and depends entirely on the TLS proxy in front of it.

## Not reviewed

- Any deployment, since there is none: TLS configuration, host hardening, backups.
- The container image, which has never been built in CI.
- The native platform builds beyond confirming that they compile in CI.
- Supply-chain risk in dependencies beyond the advisory check above.

## For an independent reviewer

Start with `services/launchpad_server/README.md` (design and limitations) and `API.md`,
then `lib/src/api/accounts_api.dart`, `lib/src/crypto/`, `lib/src/http/middleware.dart`
and `lib/src/store/file_server_store.dart`. On the client:
`packages/launchpad_data/lib/src/account/http_account_repository.dart`.

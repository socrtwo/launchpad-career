# Launchpad Career server

The optional account and sync server for Launchpad Career. The app works fully without
it: anonymous use stays first-class, and nothing in this package is a gate on exploring
the product. A person who chooses to create an account gets three things from this
server:

- a profile document synced between their devices, **only while they consent to sync**;
- an export of everything the server holds about them, and deletion of all of it;
- the goal and occupation catalogues the app displays, published by an administrator.

It is a pure Dart package (`shelf`, `shelf_router`, `crypto`, `meta`). It has no Flutter
dependency, depends on no other package in this repository, and contains no analytics,
telemetry or crash-reporting code and no database driver.

The HTTP interface is described in [API.md](API.md).

## Status

Read this before relying on the server for anything.

- **It is not deployed anywhere.** Nothing in this repository runs it. The app talks to
  it only when built with `--dart-define=LAUNCHPAD_API_URL=https://…`; a build without
  that has no accounts and makes no requests.
- **It has not been independently security-reviewed.** The design choices are written
  down below so that a reviewer can check them; nobody outside the project has.
- **It makes no compliance claims.** This server has not had legal or technical review
  against any privacy, education or consumer-protection regulation, and nothing here
  should be read as saying it meets one. See `docs/privacy/privacy-design.md`.
- **The single-file store is for small pilots only.** It holds the whole data set in
  memory and rewrites the whole file on every change. It runs as one process on one
  machine. There is no replication and no built-in backup.
- **The container image has not been built in this repository's CI.** The `Dockerfile`
  follows the documented pattern for compiled Dart servers; build and run it yourself
  before trusting it.

## Run it locally

You need the Dart SDK 3.6 or later (the Flutter SDK includes one).

```sh
cd services/launchpad_server
dart pub get

# Nothing is persisted: fine for trying the API.
dart run bin/server.dart

# Persist to a file and turn the admin routes on.
DATA_FILE=./data/launchpad.json \
ADMIN_TOKEN="$(head -c 32 /dev/urandom | base64)" \
ALLOWED_ORIGINS=http://localhost:5000 \
dart run bin/server.dart
```

Then:

```sh
curl http://localhost:8080/healthz
# {"status":"ok"}
```

The first sign-in takes about a second. That is the passphrase hash doing its job; see
"Security design".

## Run it with Docker

```sh
cd services/launchpad_server
docker build -t launchpad-server .

docker run --rm -p 8080:8080 \
  -v launchpad-data:/data \
  -e ADMIN_TOKEN="$(head -c 32 /dev/urandom | base64)" \
  -e ALLOWED_ORIGINS=https://app.example.org \
  -e TRUST_PROXY=true \
  launchpad-server
```

The image is built in two stages: `dart:stable` compiles `bin/server.dart` to a native
executable, and the runtime stage is `scratch` plus that executable and the shared
libraries it links against. There is no shell and no package manager in it. The server
runs as the unprivileged user `10001`.

The image sets `DATA_FILE=/data/launchpad.json`. `/data` is owned by user `10001` with
mode `0700`. If you mount a host directory there instead of a named volume, give it the
same owner and mode.

There is no `HEALTHCHECK` in the image, because the runtime stage has nothing to run one
with. Point your orchestrator's HTTP probe at `GET /healthz`.

## Configuration

Every setting is an environment variable. Empty values count as unset.

| Variable | Default | Meaning |
| --- | --- | --- |
| `PORT` | `8080` | TCP port. The server listens on all IPv4 interfaces. |
| `DATA_FILE` | unset | Path of the JSON data file. When unset, everything is held in memory and lost on exit; the server prints one warning line saying so. |
| `ADMIN_TOKEN` | unset | Bearer token for the catalogue admin routes. When unset, those routes answer 404. The server refuses to start if it is set and shorter than 32 characters. |
| `ALLOWED_ORIGINS` | unset | Comma-separated browser origins allowed to call the API, for example `https://app.example.org,http://localhost:5000`. Exact origins only; the server refuses to start on `*`, a path or a trailing slash. Needed only for the web build of the app. |
| `PBKDF2_ITERATIONS` | `600000` | Work factor for new passphrase hashes. See "Raising the work factor". |
| `TRUST_PROXY` | `false` | Set to `true` only behind a reverse proxy that **overwrites** `X-Forwarded-For`. See "What you must put in front of it". |

Start-up failures exit with a message on standard error and a non-zero status: 64 for a
configuration problem, 65 for a data file that cannot be read, 74 when the data file is
already in use.

`SIGINT` and `SIGTERM` stop the server gracefully: it stops accepting connections, lets
requests in progress finish (for up to ten seconds), writes nothing further and exits.

## What you must put in front of it

**The server speaks plain HTTP. Do not expose it directly.** Passphrases and bearer
tokens travel in every request, so a reverse proxy that terminates TLS must sit in front
of it, and the server's port must be reachable only from that proxy.

The proxy is also responsible for:

- **`X-Forwarded-For`.** With `TRUST_PROXY=true` the server takes the *first* value of
  this header as the client address for rate limiting. That is only safe if the proxy
  replaces whatever the client sent with the address it actually saw. A proxy that
  appends to a client-supplied header lets anyone choose their own rate-limit identity.
- **HSTS** (`Strict-Transport-Security`) and the redirect from HTTP to HTTPS.
- **Its own access log.** This server never logs client addresses or request paths, but
  your proxy probably does by default. If the proxy logs addresses, the deployment as a
  whole does; configure it deliberately.
- **Connection limits and timeouts** for slow or abusive clients. The server bounds body
  size and body read time, but it does not limit the number of open connections.

## What the server holds, and for how long

Everything below is the complete list. There is no email address, name, device
identifier or IP address in the store, and no field for one.

| Data | Why | Kept until |
| --- | --- | --- |
| Handle (lower-cased) and account creation time | To sign in | The account is deleted |
| Passphrase hash: `pbkdf2-sha256$<iterations>$<salt>$<hash>` | To check the passphrase without storing it | The account is deleted, or the passphrase is changed |
| For each sign-in: the SHA-256 of its token, when it was created, when it expires | To recognise the token | Sign-out; a passphrase change (every other sign-in); account deletion; 30 days after creation; or a 21st sign-in, which revokes the oldest |
| The latest sync consent decision: granted or not, when, and the policy version shown | To know whether sync is allowed | The account is deleted. Only the latest decision is kept, not a history |
| The profile document, its revision number and when it last changed | Sync between devices | Sync consent is withdrawn (deleted in the same step), or the account is deleted |
| Catalogue documents: the published revision and the one before it, per catalogue | To serve and roll back the catalogue | Replaced by the next publication. Not personal data |

Held in memory only, never written to the data file:

| Data | Why | Kept until |
| --- | --- | --- |
| Handles with failed sign-ins, and client addresses with failed sign-ins or account creations | Rate limiting | 15 minutes after the attempt (an hour for account creation), or a restart |

Things to know about the above:

- **Accounts do not expire.** An account that is never used again stays until its owner
  deletes it. The project has not yet written a retention schedule
  (`docs/privacy/privacy-design.md` lists it as missing); this table describes what the
  code does, it is not that schedule.
- **The profile document is opaque.** The server stores it, measures it and returns it.
  It never reads inside it and never logs it. It is stored as sent, not encrypted with
  a key the server lacks: whoever operates the server can read it.
- **Deletion removes the records, not every trace on the disk.** Deleting an account
  rewrites the data file without it. The old bytes may linger in freed disk blocks,
  filesystem snapshots and any backups you have made. Plan backups with that in mind.
- **Expired sign-ins** are removed when next presented and by an hourly sweep, so one
  may sit in the data file for up to an hour past its expiry. It cannot be used.

### The request log

One line per request goes to standard output:

```
request method=GET route=/v1/catalog/<name> status=200 duration_ms=3
```

The line is built only from values the server chose: the method (anything unusual is
written as `OTHER`), the route *template*, the status and the duration. It never
contains the path the client asked for, the query string, any header, any part of a
body, a handle, a token or a client address. An unexpected failure adds the error's
class name, for example `error=FileSystemException`, and never its message. A test
sends recognisable secrets through every route and asserts that none reaches the log.

## Security design

Written down so it can be checked, not as a claim that it is sufficient.

- **Passphrases** are hashed with PBKDF2-HMAC-SHA256, a random 16-byte salt per account
  and 600,000 iterations by default, and verified with a constant-time comparison. The
  derivation runs on a separate isolate so one sign-in does not stall other requests.
  At the default work factor one derivation took 1.2 to 1.6 seconds of one core in pure
  Dart (measured on the development machine, x64, Dart 3.12, 19 November 2026).
- **Unknown handles** cost the same derivation as a wrong passphrase and get the same
  401 response, so sign-in does not reveal which handles exist.
- **Tokens** are 32 random bytes from the operating system's secure generator, returned
  once. Only their SHA-256 is stored, so a copy of the data file does not contain a
  usable token.
- **Rate limits**: 5 failed passphrase checks per handle and 20 per client in 15
  minutes; 10 account creation attempts per client in an hour. An attempt is counted
  before the passphrase is checked and taken back on success, so parallel guesses
  cannot outrun the limit. The same limits apply to the passphrase re-check on
  passphrase change and account deletion.
- **Re-authentication**: changing the passphrase and deleting the account both require
  the passphrase again, not just a token.
- **Store operations are atomic and conditional.** For example a token is only issued if
  the account still has the passphrase hash that was just verified, so a sign-in that
  races a passphrase change cannot end up with a valid token.
- **Catalogue publication** requires an admin token compared in constant time, and
  refuses any document containing outcome-promise wording ("guarantee", "land the job"
  and similar), because the product never promises outcomes.
- **Request bodies** are size-limited while they are read, never buffered first.
- **CORS** echoes only listed origins, never `*`, and never enables credentials. The API
  uses bearer tokens and sets no cookies, so there is nothing for a cross-site request
  to ride on.

### Raising the work factor

Set `PBKDF2_ITERATIONS` to a higher number and restart. New accounts and changed
passphrases use it at once. An existing account is upgraded the next time its owner
signs in successfully, because that is the only moment the server has the passphrase.
Lowering the number never weakens an existing hash.

## Known limitations

These are the weaknesses we know about. A security review should start here.

1. **PBKDF2 is not memory-hard.** An attacker who obtains the data file can test guesses
   on graphics hardware far faster than this server can. A memory-hard function such as
   Argon2id would be the better choice; it needs a dependency this package does not
   have. The 12-character minimum is the main defence, and it is not a strong one
   against a passphrase that is long but common.
2. **Sign-in is expensive by design, which makes it a target.** Each attempt costs about
   a second of one core. The limits above bound what one client can do, but many clients
   together can keep every derivation slot busy; other people then get 503
   `server_busy`.
3. **The per-handle limit can be used to lock someone out.** Five wrong guesses against
   a handle block sign-in to it for up to 15 minutes, for its real owner too. Existing
   sign-ins keep working.
4. **Account creation reveals whether a handle is taken**, as any handle-based sign-up
   must. It is limited to 10 attempts per client per hour.
5. **There is no account recovery.** No contact details are held, so a forgotten
   passphrase cannot be reset. The account and its synced profile are unreachable from
   then on, though any device still signed in can export the data first.
6. **Rate-limit state is per process and in memory.** A restart clears it, and a second
   instance would not share it.
7. **The data file is not encrypted**, and Dart cannot set file permissions, so the file
   is created with the process's default mode. Keep it in a directory only the server's
   user can enter (the container image does this) on an encrypted volume.
8. **Durability stops at `rename`.** Each change is written to a temporary file, flushed
   and renamed over the data file, so a crash never leaves a half-written file. Dart
   cannot flush the directory entry itself, so a power failure immediately after a
   change can lose that one change.
9. **Passphrases are compared as the exact characters sent.** There is no Unicode
   normalisation, so the same accented passphrase typed on two keyboards that encode it
   differently will not match.
10. **Revision numbers restart after consent is withdrawn.** Withdrawing sync consent
    deletes the profile; the next one starts at revision 1 again. A device still holding
    an old revision number could, in a narrow case, overwrite a newer document without
    seeing a conflict. Clients should discard their sync state when consent changes.
11. **One admin token, no admin accounts and no audit trail.** Whoever holds
    `ADMIN_TOKEN` can replace either catalogue. The request log shows that a publication
    happened, not who made it.
12. **The outcome-promise check is a word list, not understanding.** It catches the
    listed phrases in string values; it does not catch a promise worded differently, and
    it does not inspect object keys.
13. **Writes are not rate limited once signed in.** A signed-in client can rewrite its
    256 KiB profile as often as it likes, and with the file store every write rewrites
    the whole file.

## Development

```sh
cd services/launchpad_server
dart format --output=none --set-exit-if-changed .
dart analyze --fatal-infos
dart test
```

`flutter analyze` and `flutter test` also pass here, which is what the repository's
`tool/dev.sh` runs. This package is not in that script's package list yet.

Tests call the handler directly with `shelf` requests, with an injected clock, log sink
and a low PBKDF2 work factor so the suite is fast. One test file binds a real port on
localhost and makes a full round trip.

### Layout

```
bin/server.dart             entry point: environment, store, signals
lib/launchpad_server.dart   public exports
lib/src/handler.dart        buildHandler: routes and the middleware around them
lib/src/api/                endpoint groups: accounts, sync, catalogue
lib/src/http/               body reading, errors, middleware, client identification
lib/src/crypto/             PBKDF2, passphrase hashing, tokens, constant-time compare
lib/src/store/              ServerStore and its two implementations
lib/src/rate_limiter.dart   sliding-window limiter
lib/src/catalog_validator.dart
```

### Adding a database

`ServerStore` (`lib/src/store/server_store.dart`) is the only thing the handlers know
about storage. A database implementation goes beside `InMemoryServerStore` and
`FileServerStore`, not in place of them. Each method is documented as atomic and several
are compare-and-set; map each one to a single statement or a transaction. The contract
tests in `test/store_test.dart` run the same expectations against every implementation:
add yours to that list.

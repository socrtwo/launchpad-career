# Launchpad Career server API

Version 1. Every path below is relative to the server's base URL, which must be an
HTTPS address served by the reverse proxy in front of the server (see the README).

## Conventions

- **Bodies are JSON.** A request with a body must send `Content-Type: application/json`.
  Responses with a body are `application/json`, encoded as UTF-8.
- **Authentication** is a bearer token: `Authorization: Bearer <token>`. Tokens come from
  creating an account or signing in. No cookies are used anywhere.
- **Timestamps** are ISO 8601 in UTC, for example `2026-01-15T09:00:00.000Z`.
- **Every response** carries `X-Content-Type-Options: nosniff`. Every response except a
  published catalogue carries `Cache-Control: no-store`.
- **Unknown addresses** and wrong methods answer 404 `not_found`.

### Errors

Every error has the same shape:

```json
{
  "error": {
    "code": "invalid_credentials",
    "message": "The handle or passphrase is not correct. Check both and try again."
  }
}
```

`code` is stable and safe to branch on. `message` is a plain sentence for a person; its
wording may change. Messages never repeat what the request contained.

Errors that any endpoint with a body can return:

| Status | Code | When |
| --- | --- | --- |
| 400 | `invalid_json` | The body is not valid UTF-8 JSON. |
| 400 | `incomplete_body` | The connection broke before the whole body arrived. |
| 408 | `request_timeout` | The body took longer than 30 seconds to arrive. |
| 413 | `body_too_large` | The body is over the endpoint's limit. The limit is enforced while the body is read. |
| 415 | `unsupported_media_type` | The body is not `application/json`. |
| 422 | `invalid_request` | The JSON is not an object, a field is missing or has the wrong type, or the document is nested more than 64 levels deep. |

Errors that any endpoint can return:

| Status | Code | When |
| --- | --- | --- |
| 401 | `invalid_token` | On an authenticated endpoint: the token is missing, malformed, unknown, expired or revoked. Sign in again. Comes with `WWW-Authenticate: Bearer`. |
| 404 | `not_found` | Nothing exists at this method and path. |
| 429 | `too_many_attempts` | A rate limit is reached. `Retry-After` gives the wait in seconds. |
| 500 | `internal_error` | The server failed. The response says nothing about why. |
| 503 | `server_busy` | Too many passphrase checks are queued. `Retry-After: 5`. |

Body limits: 16 KiB for account, session and consent endpoints; 256 KiB of profile data;
1 MiB for a catalogue.

### Rate limits

| Limit | Scope | Window |
| --- | --- | --- |
| 5 failed passphrase checks | per handle | 15 minutes |
| 20 failed passphrase checks | per client address | 15 minutes |
| 10 account creation attempts | per client address | 1 hour |

A passphrase check happens at sign-in, passphrase change and account deletion. While a
handle is limited, even the correct passphrase answers 429. Successful checks are not
counted. Account creation attempts count once the request is well-formed, whether or
not an account results.

### Cross-origin requests

The server answers `OPTIONS` preflight requests and adds
`Access-Control-Allow-Origin: <origin>` only for origins the operator has listed. It
never sends `*` and never allows credentials. Allowed request headers are
`authorization`, `content-type` and `if-none-match`; `ETag` and `Retry-After` are
exposed to scripts. A preflight from an origin that is not listed answers 403
`origin_not_allowed`.

---

## Health

### `GET /healthz`

Public. Says the process is up, and nothing else.

```
200 OK
{"status":"ok"}
```

---

## Accounts and sign-in

There is no email address anywhere in this API. An account is a handle and a
passphrase. **There is no passphrase reset**: with no contact details there is no way to
prove who is asking.

### `POST /v1/accounts`

Public. Creates an account and signs it in.

```json
{"handle": "ada_l", "passphrase": "correct horse battery staple"}
```

- `handle`: 3 to 32 characters from `a`–`z`, `0`–`9`, `_` and `-`. It is lower-cased
  before use, so `Ada_L` and `ada_l` are the same handle. It must not contain `@`.
- `passphrase`: 12 to 256 characters, counted as Unicode code points. It is used exactly
  as sent.

```
201 Created
{"token": "pX8…43 characters…Qk", "expiresAt": "2026-02-14T09:00:00.000Z"}
```

The token is shown once. The server keeps only a hash of it.

| Status | Code | When |
| --- | --- | --- |
| 409 | `handle_taken` | The handle is in use. |
| 422 | `invalid_handle` | The handle breaks the rules above. If it contains `@`, the message says not to use an email address. |
| 422 | `invalid_passphrase` | The passphrase is shorter than 12 or longer than 256 characters. |
| 429 | `too_many_attempts` | More than 10 creation attempts from this client in an hour. |

### `POST /v1/sessions`

Public. Signs in.

```json
{"handle": "ada_l", "passphrase": "correct horse battery staple"}
```

```
200 OK
{"token": "…", "expiresAt": "2026-02-14T09:00:00.000Z"}
```

A token lasts 30 days. An account holds at most 20 sign-ins; one more revokes the
oldest.

| Status | Code | When |
| --- | --- | --- |
| 401 | `invalid_credentials` | The handle does not exist **or** the passphrase is wrong. The two cases are deliberately identical in status, body and the work the server does. |
| 429 | `too_many_attempts` | See "Rate limits". |

### `DELETE /v1/sessions/current`

Bearer. Signs out: revokes the token used for this request and no other.

```
204 No Content
```

### `PUT /v1/account/passphrase`

Bearer. Changes the passphrase and revokes every other sign-in. The token used for this
request keeps working.

```json
{"currentPassphrase": "correct horse battery staple", "newPassphrase": "a new long passphrase"}
```

```
204 No Content
```

| Status | Code | When |
| --- | --- | --- |
| 403 | `incorrect_passphrase` | `currentPassphrase` is wrong. |
| 409 | `account_changed` | The account changed while the request was in progress. Sign in again and repeat it. |
| 422 | `invalid_passphrase` | `newPassphrase` breaks the length rule, or is the same as the current one. |
| 429 | `too_many_attempts` | See "Rate limits". |

### `DELETE /v1/account`

Bearer, plus the passphrase again. Deletes the account, its consents, its profile
document and every sign-in. **This cannot be undone.** The handle becomes available to
anyone afterwards.

```json
{"passphrase": "correct horse battery staple"}
```

```
204 No Content
```

This is a `DELETE` with a body. Make sure nothing between the client and the server
strips it.

| Status | Code | When |
| --- | --- | --- |
| 403 | `incorrect_passphrase` | The passphrase is wrong. Nothing is deleted. |
| 409 | `account_changed` | The account changed while the request was in progress. |
| 429 | `too_many_attempts` | See "Rate limits". |

---

## Consent

Sync is off until the person turns it on. The server refuses to store a profile without
a current, granted `sync` consent.

### `GET /v1/consents`

Bearer. The latest decision for each purpose. `sync` is the only purpose.

```
200 OK
{
  "consents": {
    "sync": {
      "granted": true,
      "at": "2026-01-15T09:00:00.000Z",
      "policyVersion": "2026-01"
    }
  }
}
```

Before any decision: `{"consents": {}}`.

### `PUT /v1/consents/sync`

Bearer. Records a decision, replacing the previous one.

```json
{"granted": true, "policyVersion": "2026-01"}
```

- `granted`: a boolean.
- `policyVersion`: 1 to 64 characters naming the policy text the person was shown.

```
200 OK
{"granted": true, "at": "2026-01-15T09:00:00.000Z", "policyVersion": "2026-01"}
```

**Sending `"granted": false` deletes the stored profile document immediately**, in the
same step as recording the decision. Granting again later does not bring it back.

---

## Profile sync

The profile is one JSON object per account. The server stores it and returns it; it
never looks inside it and never logs it.

Sync uses optimistic concurrency. Every stored profile has a `revision`. To write, send
the revision your change is based on. If someone else wrote in between, you get the
current document back and merge.

### `GET /v1/profile`

Bearer.

```
200 OK
{
  "revision": 3,
  "updatedAt": "2026-01-15T09:00:00.000Z",
  "data": {"goal": "explore", "notes": ["…"]}
}
```

| Status | Code | When |
| --- | --- | --- |
| 404 | `no_profile` | Nothing is stored for this account. |

### `PUT /v1/profile`

Bearer.

```json
{"baseRevision": 3, "data": {"goal": "explore", "notes": ["…"]}}
```

- `baseRevision`: the `revision` this change is based on. Use `0` when no profile is
  stored.
- `data`: a JSON object, at most 256 KiB (262,144 bytes) as compact UTF-8 JSON and at
  most 64 levels deep. Send the request body without extra whitespace: the body as a
  whole may be only 1 KiB larger than the limit for `data`.

```
200 OK
{"revision": 4, "updatedAt": "2026-01-15T09:05:00.000Z"}
```

| Status | Code | When |
| --- | --- | --- |
| 403 | `consent_required` | Sync consent is not currently granted. Checked before the body is read. |
| 409 | `revision_conflict` | `baseRevision` is not the stored revision. The body includes `current`. |
| 413 | `body_too_large` | `data` is over 256 KiB. |

A conflict looks like this:

```json
{
  "error": {
    "code": "revision_conflict",
    "message": "The stored profile has changed since the revision this request was based on. Merge your changes into \"current\" and send them again with its revision as baseRevision."
  },
  "current": {
    "revision": 5,
    "updatedAt": "2026-01-15T09:04:00.000Z",
    "data": {"goal": "interviews"}
  }
}
```

When nothing is stored and `baseRevision` is not `0`, `current` is
`{"revision": 0, "updatedAt": null, "data": null}`.

Withdrawing sync consent deletes the profile, and the next profile starts again at
revision 1. Discard any saved revision number when consent changes.

---

## Export

### `GET /v1/export`

Bearer. Everything the server holds about the account.

```
200 OK
{
  "handle": "ada_l",
  "createdAt": "2026-01-10T08:00:00.000Z",
  "consents": {
    "sync": {"granted": true, "at": "2026-01-15T09:00:00.000Z", "policyVersion": "2026-01"}
  },
  "profile": {
    "revision": 4,
    "updatedAt": "2026-01-15T09:05:00.000Z",
    "data": {"goal": "explore"}
  },
  "activeSignIns": 2,
  "exportedAt": "2026-01-16T10:00:00.000Z"
}
```

`profile` is `null` when none is stored. `activeSignIns` counts sign-ins that have not
expired or been revoked, including the one making this request. The export never
contains the passphrase hash, its salt, or any token or token hash.

---

## Catalogues

The app's goal and occupation catalogues. `<name>` is `goals` or `occupations`; any
other name answers 404 `not_found`.

### `GET /v1/catalog/<name>`

Public.

```
200 OK
ETag: "Zr0v…43 characters…8w"
Cache-Control: public, no-cache

{
  "revision": 7,
  "updatedAt": "2026-01-15T09:00:00.000Z",
  "document": {"schemaVersion": 1, "items": [{"id": "explore", "title": "Explore options"}]}
}
```

The `ETag` is strong: it is derived from the exact bytes of the response. Send it back
as `If-None-Match` to revalidate:

```
GET /v1/catalog/goals
If-None-Match: "Zr0v…8w"

304 Not Modified
ETag: "Zr0v…8w"
```

| Status | Code | When |
| --- | --- | --- |
| 404 | `no_catalog` | Nothing has been published under this name yet. |

### `PUT /v1/admin/catalog/<name>`

Admin: `Authorization: Bearer <ADMIN_TOKEN>`. Publishes the body as the next revision.
The body **is** the catalogue document, at most 1 MiB:

```json
{
  "schemaVersion": 1,
  "items": [
    {"id": "explore", "title": "Explore options"},
    {"id": "resume", "title": "Improve my resume and LinkedIn"}
  ]
}
```

```
200 OK
{"revision": 8, "updatedAt": "2026-01-16T10:00:00.000Z"}
```

The document is refused unless all of these hold:

- it is a JSON object;
- `schemaVersion` is an integer;
- `items` is a list of objects, each with a non-empty string `id`, and no `id` repeats;
- nothing is nested more than 32 levels deep;
- **no string value anywhere in it promises an outcome.** The check is the
  case-insensitive pattern
  `\b(guarantee[ds]?|guaranteed|ensures? you get|will land you|land the job)\b`, applied
  to every string value at any depth with runs of whitespace collapsed. Everything else
  in an item is up to the app.

A refused document changes nothing. The error lists up to 50 problems:

```json
{
  "error": {
    "code": "invalid_catalog",
    "message": "The catalogue was not published because it breaks the rules listed in \"problems\". Correct them and send it again.",
    "problems": [
      "\"schemaVersion\" must be an integer.",
      "items[2].id repeats an id used by an earlier item.",
      "items[4].summary contains outcome-promise wording (\"will land you\"). Describe what the reader can do, not a result."
    ]
  }
}
```

| Status | Code | When |
| --- | --- | --- |
| 401 | `invalid_token` | The admin token is missing or wrong. |
| 404 | `not_found` | No admin token is configured (the admin routes do not exist), or the name is unknown. |
| 413 | `body_too_large` | The document is over 1 MiB. |
| 422 | `invalid_catalog` | See above. |

### `POST /v1/admin/catalog/<name>/rollback`

Admin. No body. Publishes the previous document again, as a **new** revision, so clients
that cache by `ETag` or revision see a change. The document that was replaced is kept
in its place, which means a second rollback undoes the first. One earlier document is
kept, not a history.

```
200 OK
{"revision": 9, "updatedAt": "2026-01-16T10:30:00.000Z"}
```

| Status | Code | When |
| --- | --- | --- |
| 401 | `invalid_token` | The admin token is missing or wrong. |
| 404 | `no_catalog` | Nothing has been published under this name. |
| 404 | `not_found` | No admin token is configured, or the name is unknown. |
| 409 | `no_previous_revision` | Only one revision has ever been published. |

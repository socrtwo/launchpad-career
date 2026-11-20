# Retention schedule

What is kept, where, for how long, and how it goes away. This document describes what the
code does today; each row names the test that holds it true. It is a design record, not a
legal notice, and it makes no regulatory claim.

## On the device

Nothing is written to the device until the person presses **Save on this device**. Before
that, everything lives in memory and ends with the process.

| Data | Kept where | Kept until | Enforced by |
| --- | --- | --- | --- |
| Goal chosen | Memory; device store after opt-in | Deleted by the person, saving turned off, or 12 months without a save | `persistent_session_repository_test.dart` |
| Preferred name, education, plans, interests, priorities | Memory; device store after opt-in | Same | Same |
| Onboarding step reached | Memory; device store after opt-in | Same | Same |
| Saved occupations, plans, the route each plan follows, steps marked done | Memory; device store after opt-in | Same | `occupation_catalog_test.dart` (`SessionCodec with a workspace`), `explore_test.dart` |
| Plan steps the person wrote themselves (free text, up to 200 characters each, 12 per plan) | Memory; device store after opt-in | Same; also removed when the step or its plan is removed | `explore_test.dart` (`steps a person writes are stored only after opting in`) |
| Tool checklists (résumé, LinkedIn, interview questions practised, this week's job-search tasks), time available for the search, weeks finished, skill self-ratings | Memory; device store after opt-in | Same | `guidance_test.dart` (`SessionCodec with tool state`), `tools_test.dart` |
| Notes the person writes: interview example notes, the weekly job-search note, a skills project idea, résumé lines they chose to keep (free text, up to 600 characters each, 200 notes in all) | Memory; device store after opt-in | Same; the weekly note is also cleared when the week is finished | `tools_test.dart` (`tool state is stored only after opting in, and is exported`) |
| A résumé line typed into the wording check and not kept | Widget state only; never the session, never the store | Leaving the page or typing over it | `tools_test.dart` (`checked, not kept`) |
| Search text typed on the browse page | Widget state only; never the session, never the store | Leaving the page | Not part of `Session` |
| The opt-in itself (granted, when, wording version) | Device store | Saving turned off or everything deleted | Same |
| "Something else" free text | Memory only, never the device store | The app is closed, or everything is deleted | `the free text never reaches the store`, `your_data_test.dart` |

### Rules

- **No opt-in, no write.** Not even a "declined" marker is stored, which is why the choice
  is offered again in a later session rather than remembered.
- **Twelve-month expiry.** A stored copy whose last save is more than 365 days old is
  erased on start instead of being loaded.
- **Turning saving off erases the copy.** The answers stay in memory for the rest of the
  session, so the person does not lose their place by changing their mind.
- **Delete everything** erases the stored copy, withdraws the opt-in, and resets the
  session in memory.
- **A change of wording is a new question.** The opt-in records the version of the text
  agreed to. If the text changes meaning, the version changes, the old opt-in is not
  carried over, and the old copy is erased.
- **A stored copy with no opt-in on record is erased**, never loaded.
- **Only two keys are ever written** (`launchpad.consent.v1`, `launchpad.session.v1`), and
  the storage adapter is allow-listed to exactly those.

## On a server

Nothing, unless all of the following are true: the app was built with an account service
address; the person created an account; they turned sync on; and they pressed "Sync now".
The service is `services/launchpad_server`, which is not deployed anywhere by this
project.

| Data | Kept where | Kept until | Enforced by |
| --- | --- | --- | --- |
| Handle; salted, slow hash of the passphrase; account creation time | Account service | The account is deleted | `services/launchpad_server/test/accounts_test.dart` |
| Sign-ins: a hash of each token and its expiry | Account service | 30 days, sign-out, a passphrase change (other sign-ins), or account deletion | Same |
| Sync consent: granted or not, when, wording version | Account service | Replaced by the next decision; removed with the account | `services/launchpad_server/test/sync_test.dart` |
| Profile document: exactly what the device would store (goal, answers, workspace including notes). Never the "Something else" text | Account service, only while sync consent is granted | Sync is turned off (deleted immediately), or the account is deleted | `packages/launchpad_data/test/account_contract_test.dart` (`turning sync off deletes the copy`, `the "Something else" text never leaves the device`) |
| The sign-in token on the device | Memory; device store only while "Save on this device" is on | Sign-out, expiry, saving turned off, or everything on the device deleted | `account_contract_test.dart` (`the sign-in on the device`) |
| The passphrase | Nowhere. It is sent to the service over TLS and discarded | — | `the passphrase is never written to the device` |
| Client network address | Service memory only, for rate limiting; never logged or stored | The rate-limit window, or a restart | `services/launchpad_server/test/http_test.dart` |

### Rules

- **No email address, no name.** An account cannot be tied to a person by anything it
  holds, which is also why a forgotten passphrase cannot be reset.
- **Sync is explicit.** There is no background sync. A copy is sent when "Sync now" is
  pressed and at no other time.
- **No silent overwrite.** If the service holds a copy this device has not seen, the
  person chooses which to keep.
- **Export and deletion are in the app**, next to the thing they apply to. Deleting an
  account needs the passphrase again.
- **Deleting everything on the device does not delete the account**, and the interface
  says so in both places.
- **The request log holds a method, a route template, a status and a duration.** No
  address, handle, token or content. A test sends all of them and checks the log.
- **Published catalogues are fetched with a plain public GET** carrying no credentials and
  nothing about the person. It does disclose the device's network address to the service
  operator, as any request does.

Backups of the service's data file are the operator's responsibility and are outside what
this code can erase. An operator's retention schedule has to cover them before any real
deployment.

## What is outside the app's control

Browser and operating-system backups can copy the device store (for example a phone backup
that includes app data). The app cannot see or erase those copies. The interface does not
claim otherwise.

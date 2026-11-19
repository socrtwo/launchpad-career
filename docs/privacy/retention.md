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

Nothing. This build has no backend and transmits nothing the person enters. When account
sync ships (Phase 5) its retention rules are added here before it is switched on.

## What is outside the app's control

Browser and operating-system backups can copy the device store (for example a phone backup
that includes app data). The app cannot see or erase those copies. The interface does not
claim otherwise.

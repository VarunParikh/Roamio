# Code review — October 2026 (Task 43)

**Date:** 2026-10-30 · **Branch:** `task-43-security-review` · **Reviewers:** code-reviewer persona (read-only pass), then checked by hand and fixed in this PR. Privacy and security findings are in [security-2026-10.md](security-2026-10.md).

**Scope**
- The Cloud Functions (`firebase/functions/src/`).
- The app's money code: splits, exchange rates, settlements and balances.
- Consent, offline photo uploads, and sign-out after an account is deleted.

**Overall**
- **The money maths is sound.** Splits, exchange rates and transfers use whole numbers (or BigInt) throughout, round half to even, and hand out leftover units in list order, as spec §6 says. The app and the server use the same conversion.
- **The problems are around the maths:** deleting children's accounts, recovering a daily job that fails part-way, one rules hole, and which day's exchange rate a tab keeps.

| # | Severity | What | Where | Status |
|---|---|---|---|---|
| C1 | High | Deleting a child left them in their squads | `consent/consent.ts` | **Fixed** (same as S2) |
| C2 | High | The consent sweep never retried a deletion that failed | `consent/sweep.ts`, `consent/consent.ts` | **Fixed** |
| C3 | High | A tab's creator could delete their own tab, or undo a lead's delete, without it showing anywhere | `firestore.rules` (tabs update) | **Fixed** |
| C4 | Medium (reviewer said High) | A tab's exchange rate can change once a missing day's rates arrive | `app/lib/features/tabs/domain/new_tab.dart`, `splits/data/fx_repository.dart` | **Fixed** (owner decision) |
| C5 | Medium | No upper limit on amounts in the rules | `firestore.rules` | **Fixed** (rules, then app in the follow-ups PR) |
| C6 | Medium | Account deletion checked "leader must hand over" outside the transaction | `privacy/deleteAccount.ts` | **Fixed** |
| C7 | Medium | After settling exactly, people who view in another currency may still see a few cents owed | `app/lib/features/splits/domain/split_report.dart` | **Fixed** (follow-ups PR) |
| C8 | Medium | Photo uploads that fail for good are retried forever; the queue outlives sign-out | `app/lib/core/images/upload_queue.dart` | **Fixed** (follow-ups PR) |
| C9 | Medium | Leaving right after the first tab can drop the "Left" record | `squad/roles.ts` (`hasTabHistory`) | **Fixed** (follow-ups PR) |
| C10 | Low | `dailyFxRates` swallows errors, so its 3 retries never run | `fx/rates.ts` | **Fixed** (follow-ups PR) |
| C11 | Low | `signOutIfDeleted` might reload in a loop for a brand-new sign-up (unconfirmed) | `app/lib/features/auth/data/firebase_auth_service.dart` | **Fixed** (follow-ups PR) |
| C12 | Low | An invite revoked during a join still lets that join through | `invites/join.ts` | **Fixed** (follow-ups PR) |
| C13 | Low | The spreadsheet export turns money text into a `double` | `app/lib/features/splits/data/export_service.dart` | Checked: exact up to the largest tab; test added |
| C14 | Low | The app sets `fxDate` and the server doesn't check it, so a member could backdate a rate | `firestore.rules`, `checkTab.ts` | **Fixed** |

### C2 — The consent sweep could lose a deletion (High, fixed)
**Problem.** The daily sweep marked a request `expired` or `closed` *before* deleting the child. The "decline" button did the same. The sweep only looks at open requests, so if a deletion failed half-way (a timeout, or Storage being down) that child was never deleted. Also, one failing request stopped the whole sweep, including the audit-log clean-up.

**Fix.**
- Deleting now comes first and the closing status last, so the next day's sweep finishes the job.
- Each request runs on its own, so a failure is logged and the rest carry on.
- A parent's "decline" deletes first, then records the answer. If the deletion fails, the request stays open and the parent can answer again.

**Test.** `consent.test.ts`: "tries again the next day if a deletion fails part-way".

### C3 — A creator could hide or restore a tab (High, fixed)
**Problem.** The rule for a creator editing their own tab let `deleted` change. So:
- the creator could flip `deleted` to true, hiding the tab from everyone's balances with no activity entry;
- after a lead deleted it, the creator could remove `deletedBy` and set `deleted` back to false, quietly putting it back.

**Fix.** A creator's edit must keep `deleted` as it was. Deleting stays with leads, who must say who did it, and that shows in the activity.

**Tests.** "a tab's creator can't delete or bring back their own tab by editing it", plus the existing lead tests.

### C5 — Amount limit (Medium, fixed in rules)
**Problem.** The rules only required amounts above zero. A crafted tab of 9 × 10¹⁸ would overflow the sums in Dart and lose precision in JavaScript, and break the split screen for the whole squad.

**Fix.** Tab and transfer amounts must be at most 10,000,000,000 minor units. That is the app's own `maxTabMinor` for a 3-decimal currency.

**Test.** "amounts have an upper limit".

**Follow-up (app):** the split report should skip a broken tab, not stop working. Today a broken tab can still sit in the offline cache for a few seconds before `checkTab` removes it.

### C6 — Leader check in the transaction (Medium, fixed)
**Problem.** "Delete my account" checked "you lead a squad with others: hand over first" before the transaction. If someone joined in between, the squad was archived with members still in it.

**Fix.** The check runs again inside the transaction. For children being deleted, leadership passes to a co-lead or the next member (C1).

### C4 — Exchange-rate day (Medium, follow-up)
**Problem.**
- A tab stores `fxDate` as its own date, and conversion uses "the latest rates on or before that day".
- Rates for a day arrive at 06:00 India time, and not at all when the provider is down. So a foreign-currency tab entered early in the morning first converts with yesterday's rates.
- Once today's rates arrive, the same tab converts slightly differently, and balances move by that day's change in the rate. Spec §9.1 promises old totals never change.

**Why not high.** The shift is one day's currency movement on the affected tabs. Only tabs entered before 06:00 India time, or on a day the provider is down, are affected.

**Why not fixed here.** The fix is to save the rates day actually used as `fxDate` (and show "rate from <date>"). That changes how the app saves tabs, including offline, and should be tested on a device.

### Other follow-ups
- **C7:** work out balances and transfers in the base currency, and convert only the final balances for display, so settling exactly shows "all square" in every currency.
- **C8:**
  - remember the uploaded link so a retry only re-attaches it;
  - treat "permission denied" as final;
  - cap the attempts, and clear the queue on sign-out.
- **C9:** always scan the tabs when someone leaves, not only once `hasTabs` is set (it is set a moment after the first tab).
- **C10:** rethrow from the scheduled `dailyFxRates` so its retries happen.
- **C11:** check on a device whether `user.reload()` triggers another `userChanges` event, and if so, reload once per uid.
- **C12:** check the invite inside the join transaction.
- **C13:** build spreadsheet numbers from the whole-number amount and a number format, not `double.parse`.
- **C14:** require `fxDate == date` in the rules, or set it on the server (this ties in with C4).

## Follow-ups fixed later (follow-ups PR)
Each has a test that failed first, except C12 (a race; the existing join tests cover it).
- **C5 (app):** the split report leaves out a tab the server will reject (amounts that don't add up, or over the limit) instead of failing, so one bad tab in the offline cache can't break the split screen.
- **C7:** anyone square in the trip's currency shows square in every currency. The few cents left over by converting each item at its own day go to whoever has the largest balance, so the total stays exactly zero. One older test expected the old behaviour (₹0 shown as ฿0.01 owed) and now expects square.
- **C8:** the queue remembers a photo's link once it's uploaded, so a retry only writes the link (Storage refuses an upload over an existing file, so before this such a photo was stuck for good). A refused upload or link is dropped. The queue is cleared when someone signs out. There is deliberately no cap on attempts: a long offline trip must not lose its photos, and the jobs that can never work are now the refused ones.
- **C9:** leaving always checks the tabs, so someone on the very first tab is kept as Left even before `hasTabs` is set.
- **C10:** the scheduled `dailyFxRates` throws when the refresh fails, so its 3 retries run.
- **C11:** a missing account record is checked once each time it goes missing, so a new sign-up with no record yet can't reload in a loop.
- **C12:** `joinAdventure` checks the invite again inside its transaction.
- **C13:** spreadsheet cells are binary numbers by nature. A test shows the largest allowed tab, and a third share of it, come out exact to the paisa, so the one conversion at the file's edge loses nothing.

**C4 + C14, fixed (owner decision 2026-10-30):** a tab saves as `fxDate` the day of the latest rates known for its date, so it no longer shifts once that day's rates arrive. Edits keep it unless the date changes, and the tab screen says which day's rates convert it. The rules refuse an `fxDate` after the tab's date, and `checkTab` rejects one more than 7 days earlier (only when it changes), so nobody can backdate to a better rate.

## What's done well
- **Exact exchange rates end to end.** The rates response is read as text and never becomes a floating-point number. BigInt is used on the server and in Dart, and rounding matches on both sides.
- **Budget alerts are safe.** They fire once per threshold, inside a transaction, and re-check the budget amount and currency.
- **Push never undoes anything.** A failed push never undoes what triggered it, and dead device tokens are removed.
- **Transfers are tightly checked:**
  - the currency must be the base currency;
  - the amount must be a positive whole number;
  - `from` must differ from `to`;
  - the person recording it must be who they say.

## Checks run
| Check | Result |
|---|---|
| `cd firebase && npm test` (all emulators, incl. Storage) | 216 tests, all pass |
| `npm run lint` (`firebase/functions`) | pass |
| `cd app && dart format --set-exit-if-changed . && flutter analyze && flutter test` | 438 tests, all pass |

Every fix had a test that failed first.

The app's journey tests (`tool/e2e.sh`) were not re-run, because no app code changed. The nightly e2e workflow will cover the new rules.

## Not covered (needs a human)
- On a phone:
  - a teen/parent consent journey ending in "withdraw" (wait 48 h, or run the sweep), then check the squad shows "Deleted user" and has a new leader;
  - after deleting an account, nothing about the person reappears.
- On the deployed dev project: deploy the rules and functions, then repeat a normal day of use (add tabs with photos, settle up) to be sure the new photo-link and amount checks don't refuse real writes.
- Owner decisions:
  - C4 (exchange-rate day);
  - S7 (removed members rejoining);
  - S8 (whether a person's tab photos are deleted with their account).

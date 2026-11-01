# Test Plan: Roamio

Status: DRAFT, written 2026-11-01 from [spec §14 and §15](../requirements/product-spec.md#14-testing-strategy) and [SETUP.md](../../../SETUP.md).

## Levels

| Level | Where | Runs |
|---|---|---|
| Unit and widget | `app/test/` | Every PR |
| Security rules | `firebase/test/rules/` | Every PR, against emulators |
| Cloud Functions | `firebase/test/functions/` | Every PR, against emulators |
| Journeys | `app/integration_test/journeys/`, through `tool/e2e.sh` | Nightly on `main`, and before merging behaviour changes |
| Bill reading | `app/integration_test/receipt_ocr_test.dart` | With the journeys, on an emulator |
| Manual | Real phones, [`tasks/HANDOVER.md`](../../../../tasks/HANDOVER.md) | Owner |

## Journeys

| Journey | Covers |
|---|---|
| A | Leader: sign up, create, invite, promote, add a pal |
| B | Invitee joins from a link |
| C | Mixed-currency tabs, approved, split correctly and settled |
| D | Offline tabs sync for the squad |
| E (two tests) | Minor with parent's consent, and a declined minor's account deleted. Runs with under-18 features switched on. |
| F | Private budget alert, export, delete |
| G | Approve, reject, resubmit |

## Latest results (2026-11-01)

| Check | Result | On |
|---|---|---|
| App tests, format and analyze | 921 pass, clean | Combined code before #121 merged, and at #122 |
| Journeys plus bill-reading tests | 10 of 10 pass | `ad2cde0` (#121 updated from `main`) |
| GitHub's app and backend checks | Pass | `main` through #125, on each PR |
| Three real bill photos through real text reading | Right amount on all three | The fix was shaped by these bills, so this doesn't measure accuracy |
| Real scanner on an emulator | Opens, cancels cleanly, reaches review | A finished scan coming back is unproven |
| Real place names on an emulator | Work online; offline falls back to coordinates | One emulator |
| `v0.1.0-rc1` on a real phone | Installs, and Google sign-in works on prod | Owner's report |

## Rules
- A test that fails is reported as failed, even if a re-run passes.
- Failing tests are never skipped or deleted.
- Security rule changes need allow and deny tests.

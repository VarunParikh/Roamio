# Handover — 2026-10-29 (end of session)

Read this first, then `CLAUDE.md`, `docs/SPEC.md`, `tasks/todo.md`.
The owner works from a phone: never ask them to do device checks; add them to the list below instead. Ask before merging into `main` (approval covers the named PR only), before adding a dependency, and before anything that adds Firebase cost or changes the data model.

## Where things stand

**Merged into `main` this session:** #30 Task 32 budget · #31 Task 33 part 1 (offline banner, Sync button, online-only guards) · #32 UC-32 conflict log (`baseUpdatedAt` + `tab_edit_replaced`) · #33 Task 34 You page · #34 Add-tab location follows the Location switch · #35 Task 35 part 1, `deleteMyAccount` (both merged late in the session by the owner, not by Claude).

**Open, waiting on the owner's "merge":**
| PR | What | Branch |
|---|---|---|
| #36 | This handover (docs only) | `handover-2026-10-29` |

Before starting new work, check on GitHub (`mcp__github__pull_request_read`) whether #36 has merged, then branch from the latest `main`. `deleteMyAccount` is already on `main`, so nothing needs stacking.

**Task status**
- Task 33 — **not ticked.** Done: connectivity monitor, sync state machine, banner + Sync button on Home and the adventure page, online-only actions disabled with a reason, Sync retries photos regardless of backoff, UC-32 server log. Open: the `disableNetwork`/`enableNetwork` spike and the airplane-mode Journey D test (device only), an activity-feed screen (nothing in the app shows `tab_edit_replaced` yet), guard on the join-card Remove button, account-deletion guard (arrives with the Privacy centre).
- Task 34 — ticked (#33).
- Task 35 — **in progress.** Done (#35, merged): `deleteMyAccount` callable. Left: see "Next steps".
- Tasks 36–44 untouched.

## Next steps (in order)
1. Get #36 merged on the owner's word (`enable_pr_auto_merge`, method SQUASH; if the branch is updated afterwards auto-merge may be reset — check and use `merge_pull_request` only with the owner's approval).
2. **Task 35 remainder**, as separate small PRs:
   - Data export function (JSON + photos zip) and the same for a parent's linked children (`todo.md` Task 35; deferred from Task 12). Keep cost low: on-demand callable only, modest memory, short-lived output.
   - Privacy centre screen (`app/lib/features/profile/ui/privacy_centre.dart`): download my data, delete account (calls `deleteMyAccount`; pass `confirmLinkedChildren: true` only after the parent confirms; a leader gets the "hand over first" message), per-purpose consent toggles (location/camera/notifications), nominate a person, grievance contact.
   - Show **"Deleted user"** where a name can't be read (squad names fall back to `…` today; `squadNamesProvider` and tab/split displays).
   - Scheduled cleanup of `auditLog` entries older than 1 year (a schedule adds cost: ask first).
3. Task 33 leftovers above; then Task 36 onward in order.

## Decisions waiting on the owner
1. Merge #36 (this handover)?
2. **Nominee storage** (Task 35 "nominate a person"): needs a new field; data-model change, ask before adding. Not yet approved.
3. **Grievance contact email** (owner picks, Task 40): use a clearly marked placeholder until then.
4. Whether to build an **activity feed** screen (none exists; needed for UC-32 to be visible to people).

## Hands-on checks for the owner (nothing here has run on a device or real Firebase)
- Airplane mode: add a tab, reconnect, press Sync, confirm a second phone sees it (Journey D; also the `disableNetwork`/`enableNetwork` spike).
- A photo queued while offline must not freeze the photo queue (a Firestore write made while its network is off may never finish).
- Offline banner and the disabled buttons' reason text read well.
- You page: change avatar, name, currency; toggles behave; the avatar uploads and appears.
- Location switch: off hides "Add location"; on shows it; under-18 never sees it.
- Open a real exported PDF (Task 31, still outstanding).
- Account deletion on the dev project once the Privacy centre exists.

## Facts and traps learned
- **This repo was edited from a cloud container**; local path on the owner's Mac is `/Users/varunparikh/Projects/Roamio-travel-partner`. The old brief mentioned `tasks/HANDOVER.md` which did not exist; this file replaces it.
- **Toolchain in a fresh container:** Flutter is not installed. Install the pinned SDK (`app/.fvmrc`, 3.47.8) from `storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.47.8-stable.tar.xz` (reachable); `pub.dev` is reachable; `github.com` over git is not (use the GitHub tools). Run `dart format --set-exit-if-changed . && flutter analyze && flutter test` in `app/` (fvm is not available; call `flutter` directly).
- **Backend tests in a container:** `npm i -g firebase-tools`, `npm ci` in `firebase/` and `firebase/functions/`, Java 21 present. The sandbox proxy breaks the Functions emulator's local calls: run `firebase emulators:exec` with the `*_PROXY` env vars unset. The **Storage emulator can't be downloaded here**, so `test/rules/storage.test.ts`, `default-deny.test.ts` and the Cloud Storage deletion test fail or skip locally; CI runs them. Run only the emulators you need: `--only auth,firestore,functions`, then `npx vitest run <files>`.
- **CI lint is stricter than tests:** `npm run lint` in `firebase/functions` (eslint + `prettier --check src`) failed PR #32 once because I skipped it. Always run it before pushing backend changes. App CI is format + analyze + test.
- **Widget-test gotchas:** the theme gives buttons infinite minimum width, which crashes inside a `Row` (give them `minimumSize`); long `ListView`s build lazily, so `scrollUntilVisible(..., scrollable: find.byType(Scrollable).first)` before asserting; open dropdown menus start at the selected item.
- **Test helpers:** `pumpRoamio` (in `app/test/support/fake_auth_service.dart`) takes fakes for most services, including `connectivity`, `network`, `profile`. `connectivityMonitorProvider` defaults to always-online so existing screens need no wiring.
- **Offline design:** writes are not awaited (queued by Firestore); `SyncController` (`app/lib/features/sync/`) is the single source of "offline"; `isOfflineProvider` disables online-only actions; `UploadQueue.runDue(ignoreBackoff: true)` is what Sync calls.
- **Account deletion design:** `eraseAccount` (`firebase/functions/src/privacy/deleteAccount.ts`) leaves every squad via `dropMember` (now also deletes that member's budget), then removes profile, avatars, audit-logs the deletion, and deletes the sign-in. Tabs keep the person's id so balances never change.
- **GitHub:** the GitHub MCP tools work in this environment; `gh` does not. PR bodies end with the attribution lines from the session reminder. Squash merge is the repo convention.
- Merge approvals are per PR. "Yes merge" for one PR is not approval for the next.

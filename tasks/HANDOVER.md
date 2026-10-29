# Handover — 2026-10-29 (late, end of session)

Read this first, then `CLAUDE.md`, `docs/SPEC.md`, `tasks/todo.md`.
The owner works from a phone: never ask them to do device checks; add them to the list below instead. Ask before merging into `main` (approval covers the named PRs only), before adding a dependency, and before anything that adds Firebase cost or changes the data model.

## Where things stand

**Merged into `main` this session** (owner: "Merge all, in order"): #34 location picker · #35 `deleteMyAccount` · #36 previous handover · #37 `exportMyData` · #38 Privacy centre screen · #39 "Deleted user" and names of people who left · #40 audit log purged after a year inside the daily `consentSweep`.

**Open, CI green or running, waiting on the owner's "merge"** (all branched from `main`, independent; they touch different lines of `tasks/todo.md`):
| PR | What | Branch |
|---|---|---|
| #41 | Data download includes adventures the person left (`adventures.leftUids`, server-only) | `task-35f-export-left` |
| #42 | Nominate a person (`account.nominee`, adults only) + **ticks Task 35** | `task-35g-nominee` |
| #43 | Join-card Make co-lead / Remove off while offline (Task 33 follow-up) | `task-33b-offline-guards` |
| #44 | Weather on the Hero card + **ticks Task 36** | `task-36-weather` |
| (this) | This handover | `handover-2026-10-29b` |

**Task status**
- Task 33 — not ticked. Left: the `disableNetwork`/`enableNetwork` spike and the airplane-mode Journey D test (device/emulator), and an activity-feed screen for `tab_edit_replaced` (owner hasn't decided whether to build it).
- Task 35 — ticked in #42 (all parts #35–#42). Grievance email stays a placeholder `grievance@roamio.example`: **owner moved it to the next phase** (Task 40).
- Task 36 — ticked in #44.
- Tasks 37–44 untouched.

## Next steps (in order)
1. Merge #41–#44 and this PR only on the owner's word, one at a time (update the next branch after each merge).
2. **Task 37 Remote config** needs the new dependency `firebase_remote_config`: **ask first** (not yet approved). Wire the in-app defaults already in code: `ocrEnabledProvider`, `exportEnabledProvider`, `weatherEnabledProvider` (app), `BUDGET_THRESHOLDS` (functions/src/budget); keys `ocr_enabled`, `export_enabled`, `weather_enabled`, `budget_alert_thresholds`, plus the rest in spec §11.
3. Task 38 Update popup (depends on 37), then 39 onward.
4. Task 33 leftovers when a device/emulator run is possible.

## Decisions waiting on the owner
1. Merge #41, #42, #43, #44 and this handover?
2. Approve `firebase_remote_config` for Task 37?
3. Build an activity-feed screen (makes UC-32's `tab_edit_replaced` visible)?
4. Grievance email: next phase (Task 40), already decided.

## Hands-on checks for the owner (nothing here has run on a device or real Firebase)
- Real camera photo ≤ 400 KB; a real push arrives; adventure sheet scroll feel; scan a real bill; open an exported PDF; Google sign-in; Checkpoint 3 journeys; teen/parent consent journey.
- Airplane mode: add a tab, reconnect, press Sync, a second phone sees it (Journey D); an offline-queued photo doesn't freeze the queue; offline banner wording.
- You page: avatar, name, currency, switches; Location off hides "Add location", under-18 never sees it.
- Privacy centre: Download my data opens the share sheet with real JSON + photo zips (also a parent's child download); Delete my account on the dev project (leader message, parent confirm, signs out); Camera off hides "Take a photo"; nominate, change and remove a person.
- Tabs show "Deleted user" after a real deletion, and a left member's real name.
- Hero card weather appears (and uses the trip city with Location off).

## Facts and traps learned
- **This repo was edited from a cloud container**; local path on the owner's Mac is `/Users/varunparikh/Projects/Roamio-travel-partner`. The old brief mentioned `tasks/HANDOVER.md` which did not exist; this file replaces it.
- **Toolchain in a fresh container:** Flutter is not installed. Install the pinned SDK (`app/.fvmrc`, 3.47.8) from `storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.47.8-stable.tar.xz` (reachable); `pub.dev` is reachable; `github.com` over git is not (use the GitHub tools). Run `dart format --set-exit-if-changed . && flutter analyze && flutter test` in `app/` (fvm is not available; call `flutter` directly).
- **Backend tests in a container:** `npm i -g firebase-tools`, `npm ci` in `firebase/` and `firebase/functions/`, Java 21 present. The sandbox proxy breaks the Functions emulator's local calls: run `firebase emulators:exec` with the `*_PROXY` env vars unset. The **Storage emulator can't be downloaded here**, so `test/rules/storage.test.ts`, `default-deny.test.ts` and the Cloud Storage deletion test fail or skip locally; CI runs them. Run only the emulators you need: `--only auth,firestore,functions`, then `npx vitest run <files>`.
- **CI lint is stricter than tests:** `npm run lint` in `firebase/functions` (eslint + `prettier --check src`) failed PR #32 once because I skipped it. Always run it before pushing backend changes. App CI is format + analyze + test.
- **Widget-test gotchas:** the theme gives buttons infinite minimum width, which crashes inside a `Row` (give them `minimumSize`); long `ListView`s build lazily, so `scrollUntilVisible(..., scrollable: find.byType(Scrollable).first)` before asserting; open dropdown menus start at the selected item.
- **Test helpers:** `pumpRoamio` (in `app/test/support/fake_auth_service.dart`) takes fakes for most services, including `connectivity`, `network`, `profile`. `connectivityMonitorProvider` defaults to always-online so existing screens need no wiring.
- **Offline design:** writes are not awaited (queued by Firestore); `SyncController` (`app/lib/features/sync/`) is the single source of "offline"; `isOfflineProvider` disables online-only actions; `UploadQueue.runDue(ignoreBackoff: true)` is what Sync calls.
- **Account deletion design:** `eraseAccount` (`firebase/functions/src/privacy/deleteAccount.ts`) leaves every squad via `dropMember` (now also deletes that member's budget), then removes profile, avatars, audit-logs the deletion, and deletes the sign-in. Tabs keep the person's id so balances never change.
- **GitHub:** in the cloud container the GitHub MCP tools work and `gh` does not; on the owner's Mac it's the reverse (`gh` is logged in, the GitHub MCP server failed to connect). PR bodies end with the attribution lines from the session reminder. Squash merge is the repo convention.
- Merge approvals are per PR. "Yes merge" for one PR is not approval for the next.
- **On the owner's Mac** (2026-10-29 session): `fvm flutter …` in `app/`; backend tests with `JAVA_HOME=/opt/homebrew/opt/openjdk@21 PATH=/opt/homebrew/opt/openjdk@21/bin:$PATH npm test` in `firebase/` (the Storage emulator works here, so the whole suite runs).
- **Merging a run of PRs:** branch protection needs each branch up to date, so after every merge run `gh pr update-branch N` on the next and wait for its CI. `gh pr merge --auto` sometimes didn't fire on a green PR; a plain `gh pr merge N --squash` (with the owner's OK) works.
- **Widget tests on pushed routes:** a screen pushed over the bottom-tab shell leaves the shell's list mounted underneath, so scroll `find.byType(Scrollable).last`; `scrollUntilVisible` stops when a widget is *built*, which can still be off-screen, so `ensureVisible` before tapping; `find.widgetWithText(ButtonStyleButton, …)` matches nothing (byType is exact), use `OutlinedButton` etc.
- **Location fake:** `FakeLocationService.calls` is the user-facing flow only; the Home weather's `currentIfAllowed` reads are counted in `backgroundReads`.
- **`pumpRoamio`** never reaches the real network: weather answers only when a test passes `weatherFetch`.


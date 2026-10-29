# Handover — 2026-10-30

Read this first, then `CLAUDE.md`, `docs/SPEC.md`, `tasks/todo.md`.
The owner works from a phone and will do **one manual test session at the end**: never ask for device checks, add them to the list below. Ask before merging (the owner must name the PR numbers), before adding a dependency, and before anything that adds Firebase cost or changes the data model.

## Where things stand

**Merged into `main`:** everything through #50.
- #41 export includes left adventures
- #42 nominee, ticking Task 35
- #43 join-card offline guard
- #44 weather, ticking Task 36
- #45 the previous handover
- #46 Remote Config, ticking Task 37
- #47 activity screen
- #48 update popup, ticking Task 38
- #49 compliance docs, ticking Task 40
- #50 release pipeline (Task 42 progress)

**Open:** #51 Task 39 UX pass (CI green, waiting for the owner to approve "merge #51").

**The owner's working plan:** finish everything that doesn't need a manual test, running independent tasks in parallel and dependent ones in sequence. The owner then tests everything by hand in one session and raises issues.

**Task status**
- Done (ticked): 1–32, 34–38, 40. Task 39 is ticked in #51.
- Task 33: only device checks left (the `disableNetwork`/`enableNetwork` spike and the airplane-mode Journey D test).
- Task 42: code done (#50). Owner steps left: create and back up the upload keystore, add the GitHub secrets, push the first `v*` tag (see `docs/RELEASING.md`).
- Tasks 41, 43: not started. Task 44 (pilot): owner.
- Grievance email: placeholder `grievance@roamio.example` until the next phase (owner's decision). The Hosting privacy page is written but not deployed.

## Next steps (in order; each starts only after the previous PR merges)
1. Merge #51 (needs the owner's "merge #51").
2. **Task 41, end-to-end journey tests:**
   - `app/integration_test/` covers Journeys A–F (spec §15) against the Firebase emulators on the Android emulator (`Roamio_Pixel_API36`; commands in `docs/SETUP.md`).
   - Simulate other people via Admin/REST calls against the emulators.
   - The nightly `.github/workflows/e2e.yml` is a CI change: flag it in the PR. If it needs a third-party Action (e.g. an Android emulator runner), ask first.
3. **Task 43, security, privacy and code review:** rules, functions, the app's privacy guards, secrets; fix what's found, with allow and deny tests.
4. Then hand over for the owner's manual session and Task 44.

## Decisions waiting on the owner
1. "Merge #51".
2. Task 42 owner steps (signing key and secrets).
3. Grievance email (next phase).

## Hands-on checks for the owner (nothing here has run on a device or real Firebase)
- Photos and push:
  - a real camera photo compresses to ≤ 400 KB;
  - a real push notification arrives;
  - scan a real bill;
  - open an exported PDF.
- Sign-in and journeys: Google sign-in; the Checkpoint 3 journeys; the teen/parent consent journey.
- Offline:
  - airplane mode, then Sync, then a second phone sees the change (Journey D);
  - a photo queued offline doesn't freeze the queue;
  - the offline banner's wording.
- You page: photo, name, currency, switches; the Location switch; the Camera switch hides "Take a photo".
- Privacy centre:
  - download my data (real JSON and zips; also a parent's download for a child);
  - delete my account on the dev project (leader message, parent confirmation, sign-out);
  - nominate, change and remove a person;
  - the privacy notice link.
- Names and activity: "Deleted user" and a left member's name on real tabs; the activity screen.
- Hero card: the weather pill; text readable over real banner photos.
- UX: TalkBack reading order and wording; the pulse's feel.
- Remote Config: set the keys in the console and see the flags change.
- Releases: the release workflow on the first tag; the update popup on the previous version.

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
- **Permission classifier:** merges need the owner to name the PR numbers in chat ("merge #51"); a blanket "merge all" or a long background merge loop has been refused. Merge one PR per command.
- **Stacked PRs squash-merged:** when a base PR is squash-merged, its child conflicts on the same lines. Merge `origin/main` into the child, keep the child's side (it's a superset), rerun both suites.
- **Sessions can only be started on the owner's own message**, not from a background-task or child-session event.
- **Screen-state rules:** `tasks/screen_states.md`; text colours `coralText`/`mintText` for words (coral/mint only for fills); accessibility guideline tests in `app/test/features/ux/`.


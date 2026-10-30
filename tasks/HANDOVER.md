# Handover — 2026-10-30 (night)

Read this first, then `CLAUDE.md`, `docs/SPEC.md`, `tasks/todo.md`, `docs/ROADMAP.md`.
The owner works **remotely from a phone** (Remote Control) and does **one manual test session at the end**: never ask for device checks; add them to the list below. Ask before merging (**the owner must name the PR numbers**, e.g. "merge #66"; blanket approvals are refused by the permission check), before adding a dependency, before anything that adds Firebase cost, and before changing the data model.

## Where things stand

**Merged into `main`: everything through #65. No open PRs** (apart from the PR carrying this handover). CI and the nightly journey tests are green.

Since the previous handover:
- #58 the owner's review decisions:
  - each tab keeps its exchange-rate day;
  - profiles visible only to squadmates;
  - old emails deleted after 30 days.
- #59 CI hardening: pinned Actions, and a `release` environment that needs the owner's approval.
- #60 App Check, set up but not enforced.
- #61 handover.
- #62 a failed nightly run opens a `nightly-failure` issue.
- #63 offline-restart fix: reopening the app online after it was offline no longer leaves Firestore's network off.
- #64 **pilot scope, the owner's decision (option B)**:
  - sign-up asks **no date of birth** and refuses no one; the tick reads **"I'm 18 or older and I've read the privacy notice"** (`adultDeclared: true`, and the server sets the account adult);
  - **under-18 screens and Nominate a person are hidden** by two switches in `app/lib/core/config/phase2.dart`, for a separate DPDP-compliant Phase 2 version;
  - the code, rules and tests stay, and Journey E runs with `launch(phase2: true)`;
  - see `docs/ROADMAP.md`.
- #65 **app icon**: the split pin ("paid + owed"); master `design/app-icon/roamio-icon-split-pin.svg`; adaptive, themed, round and PNG versions in `app/android/app/src/main/res`.

**Task status**
- Done: 1–32, 34–41, 43.
- **Task 33:** device checks only.
- **Task 42:** owner steps. Create and back up the upload key, add the secrets to the `release` environment (`docs/RELEASING.md`), push `v0.1.0-rc1`, and approve the run.
- **Task 44, pilot:** owner. The checklist is in `docs/PILOT_GUIDE.md` part 2.

## Test APK for the owner (2026-10-30)
- `Roamio-dev-2026-10-30.apk`: dev flavor, release mode, signed with the debug key, 97 MB, built from `main` at #65.
- Shared through a **private draft GitHub release**, `test-build-2026-10-30` (no tag, so the release workflow didn't run). Delete the draft once it's no longer needed: `gh release delete test-build-2026-10-30`.
- **It talks to the real dev Firebase project (`roamio-dev-varun`).** As of 2026-10-30 the dev backend may not be deployed (`firebase functions:list -P dev` failed). Until the owner deploys, sign-up may stall: no server function sets the account status, and the rules may not be published. Deploy dev with:
  - `firebase deploy --only firestore,functions,storage -P dev`;
  - Hosting is optional.

  Both need the Blaze plan.
- Files over 30 MB can't be sent to the owner's phone through Remote Control; use a private draft release.

## Paused schedules (owner, 2026-10-31)
Held until the pilot redesign (Tasks 46-62) is finished. Turn these back on then:
- GitHub nightly journeys: `gh workflow enable "E2E journeys" --repo VarunParikh/Roamio`. While it's off, it can't be started by hand on GitHub either; `tool/e2e.sh` still runs journeys locally.
- Claude routine "Roamio nightly journey check" (`trig_01R2owk9VvzgSEVEXcTfDRtL`): set it enabled again, after the workflow, so it doesn't report a missing run.
- Firebase has nothing to pause: functions aren't deployed on dev or prod, so the three scheduled functions (`dailyFxRates`, `consentSweep`, `birthdaySweep`) don't run yet. They start with the first deploy.

## Waiting on the owner
1. **Deploy** dev (for the APK test) and later prod: `firebase deploy --only firestore,functions,storage[,hosting] -P dev|prod`.
2. **The manual test session** (list below), then report issues.
3. **The phone load test** on a spare older Samsung: proposed, **not approved**. The plan:
   - seed heavy data into the emulators;
   - point the phone at them over `adb reverse` (this needs an emulator-host build option, because `firebase_setup.dart` hard-codes `10.0.2.2`);
   - profile memory and jank, plus an optional burst test.

   The known risks:
   - the functions cap is `maxInstances: 5`;
   - tab lists aren't paged.
4. Task 42 owner steps; then the pilot.
5. The grievance email (next phase).

## Local-only notes (the owner's Mac)
- `firebase/functions/.env.local` (untracked; created during the screenshot run) overrides `UNSPLASH_API_BASE`, so **3 banner tests fail locally only**. CI is fine. Deleting it fixes local runs. It's treated as possibly holding credentials, so don't print it.
- `screenshots/` is git-excluded:
  - app screenshots (`screenshots/2026-10-30/`, 54 images);
  - icon option files (`screenshots/icon-options/`);
  - the APK copy.

## Hands-on checks for the owner (nothing here has run on a device or real Firebase)
- Photos and push:
  - a real camera photo compresses to ≤ 400 KB;
  - a real push notification arrives;
  - scan a real bill;
  - open an exported PDF.
- Sign-in and journeys: Google sign-in and email sign-up with the **"I'm 18 or older" tick (no date of birth)**; the Checkpoint 3 journeys. (The teen/parent consent journey is Phase 2.)
- Offline:
  - airplane mode, then Sync, then a second phone sees the change (Journey D);
  - a photo queued offline doesn't freeze the queue;
  - the offline banner's wording.
- You page: photo, name, currency, switches; the Location switch; the Camera switch hides "Take a photo".
- Privacy centre:
  - download my data (real JSON and zips);
  - delete my account on the dev project (leader message, sign-out);
  - no Nominate section and no Linked children (hidden for the pilot);
  - the privacy notice link.
- Approval notifications (two phones, notifications on):
  - a member's tab pushes to each admin but not the creator, and Home shows "1 tab to approve", which opens the adventure;
  - one admin approves: the card goes from both admins' Home within a moment;
  - rejecting pushes to the creator, and Home's card opens the tab;
  - with notifications off, the card still appears and no push arrives;
  - tapping a push opens the app, not the adventure: nothing routes pushes yet.
- Names and activity: "Deleted user" and a left member's name on real tabs; the activity screen.
- Hero card: the weather pill; text readable over real banner photos.
- UX: TalkBack reading order and wording; the pulse's feel.
- Remote Config: set the keys in the console and see the flags change.
- Releases: the release workflow on the first tag; the update popup on the previous version.
- **Added 2026-10-31, characters:** a new account shows its default character and the Home card offers a change; pick one on You; pictures look sharp and on white on a real screen; a squadmate sees yours in the squad list and Activity; a deleted account shows the grey icon; Google sign-up doesn't bring your Google photo.
- **Added 2026-10-31, rejected tabs and personal tabs:** a rejected tab shows its reason to its creator and the admins only; Edit and resubmit sends it back to waiting; changing an approved tab's amount sends it back, changing its description doesn't; a personal tab is invisible on a second phone and its creator can delete it.
- **Added 2026-10-31, approvals:** a member's tab shows Waiting for approval and an admin's Approve puts it in the split; Reject asks first; a leader with no co-lead has their tab counted at once; two admins pressing at once, the second is told it's decided.
- **Added 2026-10-30:**
  - Exchange-rate day: a foreign-currency tab added before 06:00 India time keeps its total after that day's rates arrive. The tab screen shows *Converted at exchange rates from …*.
  - Profiles are private: a new member sees the squad's names right after joining; someone outside the squad can't see them.
  - Offline photos: a photo whose link failed to save uploads on the next Sync; signing out clears the queue.
  - Releases: the first tag waits for your **Approve** in Actions, then publishes the APK.
  - App Check: after installing the prod APK, the Firebase console → App Check shows requests (not enforced).
  - Offline restart (#63): go offline, press Back to leave the app, reopen when online, add a tab, and see it on the second phone.
  - App icon (#65): the split pin on the home screen and app list, on a Samsung (rounded-square icons) and with themed icons on (Android 13+).

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
- **Journey tests:** `tool/e2e.sh` runs everything (Firebase + Android emulators, `flutter test integration_test`), then stops what it started; docs in `docs/SETUP.md`. Other people are simulated over the emulators' REST APIs (`app/integration_test/support/emulators.dart`). About 4 min on the Mac, 13 min on GitHub.
- **On GitHub's runners:**
  - set `ANDROID_AVD_HOME`, or the emulator can't find the AVD;
  - a fresh checkout has no `app/android/app/src/dev/` folder;
  - the script writes a stand-in `google-services.json` (no secrets needed).
- **Local `firebase/functions/.env.local`** (git-ignored, only on the owner's Mac) makes the 3 banner tests fail. Move it aside for `npm test`, then put it back.
- **Merges were refused** when the owner said "merge and continue" without numbers, for PRs created after that message. Always ask for the numbers.


# Handover — 2026-10-30 (evening)

Read this first, then `CLAUDE.md`, `docs/SPEC.md`, `tasks/todo.md`.
The owner works from a phone and will do **one manual test session at the end**: never ask for device checks, add them to the list below. Ask before merging (the owner must name the PR numbers), before adding a dependency, and before anything that adds Firebase cost or changes the data model.

## Where things stand

**Merged into `main`:** everything through #57.
- #51 UX pass (Task 39)
- #52 the previous handover
- #53 end-to-end journey tests A–F (Task 41), plus the deleted-account sign-out fix
- #54 pilot guide draft (`docs/PILOT_GUIDE.md`, part of Task 44)
- #55 security, privacy and code review (Task 43): reports in `docs/reviews/`
- #56 Task 43 follow-ups
- #57 nightly journey tests fixed for GitHub's runners (they now pass there in about 13 min)

**Open, waiting for the owner to name them** (all CI-green or running):
- #58 the owner's decisions:
  - C4/C14: each tab keeps its exchange-rate day;
  - S3b: profiles visible only to squadmates;
  - S12: old emails deleted after 30 days;
  - S7 and S8 recorded.

  Data-model changes, approved.
- #59 CI hardening (S14): pinned Actions; releases need the owner's approval in the new `release` environment (already created on GitHub with the owner as reviewer); the publish job alone can write. CI change, approved.
- #60 App Check (S15): set up with Play Integrity in the prod app, **not enforced**. New package `firebase_app_check`, approved.

Merge order: #58, then #59 and #60 in either order. After each merge, run `gh pr update-branch` on the next and wait for its CI.

**Task status**
- Done (ticked): 1–32, 34–41, 43.
- **Task 33:** only device checks are left (airplane mode, Sync, a second phone). The automated Journey D covers the app side.
- **Task 42:** code done. Owner steps left:
  - create and back up the upload keystore;
  - add the three secrets **to the `release` environment** (after #59; the commands are in `docs/RELEASING.md`);
  - push the first `v0.1.0-rc1` tag and approve the run.
- **Task 44 (pilot):** owner. The guide is drafted. Before inviting anyone, see the checklist in `docs/PILOT_GUIDE.md` part 2:
  - deploy Hosting;
  - install the Trigger Email extension on prod;
  - set up the feedback form.
- **Checkpoints 0–6:** the owner's manual journeys and sign-off.

**Nothing left for an agent except:** follow-ups from the owner's manual session, and keeping the nightly journey workflow green.

## Owner decisions (2026-10-30)
- **S7:** a removed member can still rejoin with the old link (left as is).
- **S8:** photos added to tabs stay with the squad when an account is deleted.
- **C4:** lock each tab's rate day (built in #58).
- **S3b, S12, S14, S15:** approved and built (#58–#60).
- **App Check:** don't enforce during the pilot. Enforce after the app is on the Play Store (`docs/SETUP.md` → App Check).
- **Grievance email:** placeholder until the next phase.

## Owner deploy steps once #58–#60 are merged
- `firebase deploy --only firestore -P prod`: rules, indexes, and the 30-day TTL on `mail.expiresAt`.
- `firebase deploy --only functions -P prod`: includes `profileReadersOnAdventure`.
- `firebase deploy --only hosting -P prod`: invite links and the privacy page.

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
- **Added 2026-10-30:**
  - Exchange-rate day: a foreign-currency tab added before 06:00 India time keeps its total after that day's rates arrive. The tab screen shows *Converted at exchange rates from …*.
  - Profiles are private: a new member sees the squad's names right after joining; someone outside the squad can't see them.
  - Offline photos: a photo whose link failed to save uploads on the next Sync; signing out clears the queue.
  - Releases: the first tag waits for your **Approve** in Actions, then publishes the APK.
  - App Check: after installing the prod APK, the Firebase console → App Check shows requests (not enforced).

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


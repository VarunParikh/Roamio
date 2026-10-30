# Security and privacy review — October 2026 (Task 43)

**Date:** 2026-10-30 · **Branch:** `task-43-security-review` · **Reviewers:** security-auditor persona (read-only pass), then checked by hand and fixed in this PR.

**What was looked at**
- The privacy boundary: `firebase/firestore.rules` and `firebase/storage.rules`.
- Every Cloud Function in `firebase/functions/src/`: sign-in checks, input checks, under-18 handling, account deletion and data download.
- The app's privacy guards: `privacyPolicyProvider` for analytics, Crashlytics and location for under-18s, and places where only the app's screens protect private data.
- Secrets and config: what is committed, `.gitignore`, and the CI workflows (`ci.yml`, `e2e.yml`, `release.yml`).
- Dependency audits (below).

**Summary:** no critical findings. There were 5 high findings, all fixed here with tests. 9 medium and low findings were left as follow-ups; the follow-ups PR fixed S9, S10, S11 and S13 (see "Follow-ups fixed later").

Severity means:
- **High:** someone's private data leaks, or a promise in the privacy notice is broken.
- **Medium:** a real weakness that is harder to use or does less harm.
- **Low:** hardening.

## Findings

| # | Severity | What | Where | Status |
|---|---|---|---|---|
| S1 | High | A deleted account could come back for up to an hour | `functions/src/auth/setAgeStatus.ts` | **Fixed** |
| S2 | High | Deleting a child's account left them in their squads | `functions/src/consent/consent.ts` (`deleteChild`) | **Fixed** |
| S3 | High | Anyone active could list every user's profile, children's included | `firestore.rules` (`users/{uid}`) | **Fixed** |
| S4 | Medium | Tab photo links could be any web address, so they could be used to track members | `firestore.rules` (tabs `memories`) | **Fixed** |
| S5 | Medium | Frozen or unconfirmed accounts could still manage squads and invites | `functions/src/squad/roles.ts`, `invites/invites.ts` | **Fixed** |
| S6 | Medium | The child's name went into consent emails unchecked (phishing) | `functions/src/consent/consent.ts` | **Fixed** |
| S7 | Medium | A removed member can rejoin with the same invite link | `squad/roles.ts`, `invites/join.ts` | Follow-up |
| S8 | Medium | Account deletion keeps photos the person added to tabs | `privacy/deleteAccount.ts` | Follow-up (owner decision) |
| S9 | Low | Photo-link checks accept any Firebase bucket, and emulator addresses in production | `firestore.rules` (`isStoredPhoto`) | **Fixed** (bucket and folder; emulator addresses remain, see below) |
| S10 | Low | Profile photo uploads need no account record and have no cap | `storage.rules` (avatars) | **Fixed** (record + file name; no count cap) |
| S11 | Low | Some adventure and tab fields have no type or length check | `firestore.rules` | **Fixed** |
| S12 | Low | Sent-mail records (parent emails) are never deleted | `functions/src/mail.ts` | Follow-up |
| S13 | Low | A parent's download of a child's data includes other adults' tab locations | `privacy/exportData.ts` | **Fixed** |
| S14 | Low | CI actions are pinned by tag, not commit; releases have no protected environment | `.github/workflows/*.yml` | Follow-up (CI change, needs owner OK) |
| S15 | Info | No App Check, so anyone can call the functions and use up the 5-instance cap | `functions/src/index.ts` | Follow-up (cost) |
| S16 | Info | Ages and parent identity are self-declared | spec §7.1 | Known; DigiLocker is planned before public launch |

### S1 — A deleted account could come back (High, fixed)
**Problem.** Deleting an account removes the sign-in. But the phone's sign-in token keeps working with Firestore for up to an hour, and the rules can't tell it was revoked. Journey E found this.

In that hour the old app, or someone holding the token, could:
1. write a new `users/{uid}` and `users/{uid}/private/account` with an adult date of birth;
2. let `setAgeStatus` mark it `adult`;
3. then rejoin squads with a remembered invite code.

Everything written this way would have no sign-in behind it, so it could never be deleted or downloaded later. A child whose parent said no could come back as an "adult" the same way.

**Fix.** `setAgeStatus` now checks that the sign-in still exists. If it doesn't, it removes everything under `users/{uid}`, so the account never becomes active.

**Test.** `test/functions/age-status.test.ts`: "removes records written by a deleted account…". It failed before the fix.

### S2 — Deleting a child left them in their squads (High, fixed)
**Problem.** A child is deleted when their parent says no, doesn't answer in 7 days, or withdraws consent. Deletion went through `deleteUserCompletely`, which only removes the profile and the sign-in. After a withdrawal (the child had been active in squads) this left behind:
- their id in each squad's member list;
- their budgets;
- their profile photos;
- the leads' "joined" cards.

A squad the child led was left with a deleted leader that nobody could replace. This breaks spec §8 ("removes profile, photos, budgets") and §7.3.

**Fix.** `deleteChild` now uses the same `eraseAccount` as "Delete my account":
- the child leaves every squad, and stays as "Deleted user" on tabs;
- budgets and profile photos are removed;
- the deletion goes in the audit log.

A squad the child leads passes to a co-lead, or else the next member, and the change shows in the activity.

**Test.** `test/functions/consent.test.ts`: "hands over a squad they lead and leaves every squad".

### S3 — Every profile could be listed (High, fixed)
**Problem.** `users/{uid}` allowed `read` to any active user. In Firestore, `read` includes *listing* the whole collection. So any adult could download every user's name, bio and Google photo, including children still waiting for consent.

**Fix.** The rule now allows `get` (one profile by id) and no listing. The app only ever reads profiles one at a time, so nothing in the app changes.

**Test.** `test/rules/firestore.test.ts`: "nobody can list every profile". The existing allow tests still pass.

Seeing a profile still needs only the person's id. Limiting it to squadmates would need a data-model change, so that is listed as a follow-up under S3b below.

### S4 — Tab photo links could track members (Medium, fixed)
**Problem.** A tab's `memories` could hold any web address. The app loads them when someone opens the tab. A member could add `https://tracker.example/pixel?…` and learn the IP address of everyone who opens it, children included. The banner already blocked this; tab photos didn't.

**Fix.** Each of the up to 4 memories must now be one of our own Firebase Storage links, the same check as banners (`isStoredPhoto`).

**Test.** "memories are only our own stored photos" covers create and edit, including a bad link hidden after three good ones.

### S5 — Frozen accounts could still manage squads (Medium, fixed)
**Problem.** The rules lock out accounts that are frozen (parent withdrew consent), still waiting for consent, or waiting for the adult notice. The squad and invite callables didn't check this. A frozen child who leads a squad could still:
- remove members;
- promote or hand over leadership;
- create and revoke invite links.

**Fix.** A new `activeUidOf` check is used by every squad action and by `createInvite`/`revokeInvite`. Downloading data and deleting an account stay open to everyone.

**Test.** `test/functions/roles.test.ts`: "a frozen or unconfirmed lead can't manage the squad or its invite".

### S6 — Phishing through consent emails (Medium, fixed)
**Problem.** The consent email's subject and body start with the child's first name, which the user types. A name like `verify-at-evil.example/login` would land in a real parent's inbox, sent from Roamio.

**Fix.** Only a first name made of letters, apostrophes and hyphens is used. Anything else becomes "Your child".

**Test.** "never put a link-like name in front of the parent".

### Follow-ups (not fixed here)
- **S3b, Medium:** profiles are visible to any active user who knows an id. Showing only squadmates needs a server-kept list (data-model change, ask the owner).
- **S7, Medium:** a lead removes someone, but the invite link still works, so they can rejoin straight away. Fix by rotating the invite code on removal, or keeping a "removed" list that `joinAdventure` refuses. This is a product decision.
- **S8, Medium:** account deletion removes profile photos but not photos the person added to tabs. Spec §8 says "photos". The download links also carry tokens that skip the Storage rules. The owner should decide whether tab photos belong to the person or the squad.
- **S9, Low:** pin photo links to this project's own bucket and path. Keep the emulator addresses out of production rules (for example, a rules file per environment).
- **S10, Low:** require an account record before an avatar upload, and limit file names, so a signed-in stranger can't fill Storage.
- **S11, Low:** check `countryCode` (2 capital letters), `city` (≤ 80 characters) and `category` (known values) in the rules.
- **S12, Low:** give the `mail` collection a time-to-live (needs `createdAt` as a timestamp).
- **S13, Low:** leave `location` out of exported tabs the person didn't add.
- **S14, Low (CI change):**
  - pin actions to commit SHAs and pin the `firebase-tools` version;
  - put release signing behind a protected `environment` with a required reviewer;
  - give `contents: write` only to the publish step.
- **S15, Info (cost):** turn on App Check for the functions.
- Also noted: `fcmTokens` aren't validated (someone could add another phone's id to their own list; low risk). The `decline` path of consent and the consent sweep are now safe to retry; see the code review (C2).

## Follow-ups fixed later (follow-ups PR)
Each has a test that failed first.
- **S9:** photo links must be in one of our own buckets (`roamio-dev-varun` or `roamio-prod-varun`), inside the same adventure and the right folder: tab photos under `tabs/`, the banner under `banner/`. Links from another project, another adventure or a profile photo are refused. Emulator addresses are still accepted (pinned to the same adventure and folder). Taking them out of production needs a rules file per environment (a deploy-config change), so that part is still open.
- **S10:** an avatar upload needs the person's account record and a plain file name like the app's own (`0123456789abcdef.webp`). Storage rules can't count files, so there is still no cap on how many.
- **S11:** an adventure's `countryCode` must be 2 capital letters and `city` at most 80 characters; a tab's `category` must be one of the 10 in `app/assets/data/categories.json`.
- **S13:** a data download keeps `location` only on tabs the person added themselves.

Still open, waiting on the owner: S3b (data model), S7 (product), S8 (product), S12 (data model), S14 (CI change), S15 (cost).

## App privacy guards (checked, nothing to fix)
- **No analytics or Crashlytics.** Neither package is installed (`app/pubspec.yaml`), so nothing can report about under-18s.
- **Under-18s are the default.** `PrivacyPolicy.forAgeStatus` treats anyone not confirmed as `adult` as a minor, so a new or unknown status keeps the protections on.
- **Location is checked in the app and on the server:**
  - the tab location picker and the Home weather both check `privacyPolicyProvider.allowsLocation`;
  - the rules also refuse a tab `location` unless the writer is an adult (`isAdult()`).
- **The app is never the only guard.** Budgets (owner only), consent records, roles, `ageStatus` and `dob` are all enforced in the rules or functions.

## Secrets and config (checked, nothing to fix)
- **Nothing secret is committed.** No secret, `google-services.json`, keystore or `.env` file is tracked, now or in history. The only key-shaped string is the made-up stand-in in `tool/e2e.sh`.
- **`.gitignore` covers them:** `google-services.json`, `GoogleService-Info.plist`, `*.jks`, `*.keystore`, `key.properties`, `.env*` and `.secret.local`. The one exception is `.env.demo-roamio`, which points tests at a local stand-in.
- **CI and nightly e2e:**
  - they run on `pull_request` or a schedule (never `pull_request_target`), with read-only permissions and no secrets;
  - no untrusted text (PR titles, branch names) goes into `run:` steps.
- **Release workflow:** it only runs on `v*` tags, uses secrets only in the build step, and deletes the keystore and config afterwards.

## Dependency audit
| Where | Result |
|---|---|
| `firebase/functions` (deployed code) | `npm audit`: **0 vulnerabilities** |
| `firebase/` (test tools only) | `npm audit`: 5 "high", all the same issue (explained exception below) |
| `app/` | `flutter pub get` shows no security advisories; `pub outdated` shows only minor updates (below) |

**Explained exception: the `firebase/` test tools.**
- The 5 "high" results are one problem: `@grpc/grpc-js` 1.9.16, pulled in by the `firebase` 13.1.0 web SDK. Even the latest `@firebase/firestore` pins `~1.9.0`, so there is no upstream fix yet. npm's suggested fix (downgrading to firebase 9) is a breaking change.
- The two advisories are about a gRPC *server* trusting bad TLS certificates, and about server error text reaching clients.
- Here the library is used only by the test runner, which talks to the local emulators. It is never shipped in the app or deployed.
- **Risk:** none for users.
- **Action:** take the fix when the Firebase JS SDK moves to grpc-js ≥ 1.14.

**App packages behind the latest:**
- `cached_network_image` 4.0.5 → 4.0.6, `go_router` 18.1.1 → 18.1.2 and `pdf` 3.12.0 → 3.13.1, plus a few transitive packages.
- None has a published advisory.
- Upgrade them in a normal maintenance PR.

## Not covered (needs a human)
- **Real Firebase project:** these rules and functions were tested only on the emulators, not on the deployed dev project. After deploying, check that Storage can read Firestore (the rules use `firestore.get`).
- **Real Google sign-in:** check that a Google profile photo still shows on the You page.
- **A deleted account on a real phone:** the app signs out, and nothing reappears in the squad.
- **Legal review:** the privacy notice and the DPDP checklist (spec §8 says this is not legal advice).
- **Penetration testing:** none was done against a deployed environment.

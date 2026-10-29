# Roamio Phase 1 — Task List

Plan: [plan.md](plan.md) · Spec: [../docs/SPEC.md](../docs/SPEC.md)
Sizes: XS 1 file · S 1–2 · M 3–5 · L 5–8 (none larger). "UC-n" refers to spec use cases.

Common verification commands:
- App: `cd app && dart format --set-exit-if-changed . && flutter analyze && flutter test`
- Backend: `cd firebase && npm test` (rules + functions against emulators)

---

## Phase 0 — Setup

- [x] **Task 1: Install the development toolchain** — S · Deps: none · 👤 owner approves downloads
  - Acceptance: Homebrew, FVM + pinned Flutter stable, JDK 17, Android Studio with an Android emulator (API 36, Pixel 8), Node LTS, Firebase CLI installed.
  - Verify: `flutter doctor` shows no errors for Android; emulator boots; `firebase --version` works.
  - Files: `docs/SETUP.md`

- [x] **Task 2: Restructure repo, add docs skeleton, first push** — S · Deps: none · 👤 owner approves push
  - Acceptance: `stitch_android_app_ui_replica/` → `design/`, `Data/` → `data/`, vision RTF → `docs/vision/`; `README.md`, `CLAUDE.md` (project rules for agents) added; pushed to `main` on GitHub.
  - Verify: `git status` clean; repo page shows README.
  - Files: `README.md`, `CLAUDE.md`, moved folders

- [x] **Task 3: Create Firebase projects (guided)** — S · Deps: 1 · 👤 owner creates accounts
  - Acceptance: `roamio-dev` and `roamio-prod` exist on Blaze with a ₹500/month budget alert; Firestore + Storage in asia-south1; Google and email/password sign-in enabled; Android apps registered as `app.roamio.android` (+ `.dev`); Unsplash developer app created; keys stored as GitHub Actions secrets, never in the repo.
  - Verify: `firebase projects:list` shows both; Firestore location reads asia-south1.
  - Files: `docs/SETUP.md`, `firebase/.firebaserc`

- [x] **Task 4: Scaffold the Flutter app** — M · Deps: 1, 3
  - Acceptance: `app/` with dev/prod flavors, package `app.roamio.android`, minSdk 26; Roamio theme from `design/DESIGN.md` (colours, Plus Jakarta Sans, radii); go_router shell with floating Home · Split · You bottom bar and placeholder screens; Riverpod; lints configured.
  - Verify: `flutter run --flavor dev` shows the bottom bar on the emulator; analyze + test clean.
  - Files: `app/pubspec.yaml`, `app/lib/main.dart`, `app/lib/core/theme/roamio_theme.dart`, `app/lib/core/router/app_router.dart`, `app/lib/core/ui/bottom_bar.dart`

- [x] **Task 5: Scaffold the Firebase backend** — M · Deps: 1, 3
  - Acceptance: `firebase/` with default-deny Firestore and Storage rules, TypeScript functions (asia-south1) with one health function, emulator config, rules-test harness with one passing deny test.
  - Verify: `cd firebase && npm test` passes; `firebase emulators:start` runs.
  - Files: `firebase/firebase.json`, `firebase/firestore.rules`, `firebase/storage.rules`, `firebase/functions/src/index.ts`, `firebase/test/rules.test.ts`

- [x] **Task 6: CI pipeline** — S · Deps: 4, 5
  - Acceptance: GitHub Actions runs format, analyze, Flutter tests and backend tests on every PR and push to `main`; branch protection requires it.
  - Verify: a test PR shows all checks green.
  - Files: `.github/workflows/ci.yml`

### ✅ Checkpoint 0
- [ ] App skeleton runs on the emulator · [ ] CI green · [ ] Owner has tried the app shell and approved

---

## Phase 1 — Core logic (highest risk first)

- [x] **Task 7: Money, currency and FX conversion** — S · Deps: 4
  - Acceptance: `Money` (minor units + ISO code, per-currency decimals, e.g. JPY 0, KWD 3); conversion via a USD-based rate table with half-even rounding; formatting with symbol from the countries data.
  - Verify: unit tests incl. 0-decimal and 3-decimal currencies; 100% coverage of `domain/money`.
  - Files: `app/lib/features/splits/domain/money.dart`, `fx_converter.dart`, tests

- [x] **Task 8: Split engine** — M · Deps: 7
  - Acceptance: equal and custom-% (basis points) shares with deterministic remainder distribution; multiple payers validated to total the amount; settlements; per-person balances in base currency; minimum-transfer suggestions (≤ n−1). Spec §6 worked example passes.
  - Verify: unit tests + property test (random tabs ⇒ balances sum to 0, shares sum to amount); 100% line coverage of `domain/splits`.
  - Files: `app/lib/features/splits/domain/split_engine.dart`, `tab_models.dart`, `settlement_planner.dart`, tests

- [x] **Task 9: Data model and security rules** — M · Deps: 5
  - Acceptance: `docs/DATA_MODEL.md` (collections: users, adventures, members, pals, tabs, settlements, budgets, activity, invites, fx_rates, banners, parentalConsents, auditLog); rules: only members read an adventure; only leads manage squad/adventure; budgets readable only by owner; pals can't exist as auth users; minors in `pending_parental_consent` can read nothing but their own profile; tab writes validated (amount > 0, ≤ 4 memories). ADR-001 (Firebase) and ADR-002 (offline model) written.
  - Verify: rules tests with allow + deny cases for every collection pass.
  - Files: `docs/DATA_MODEL.md`, `docs/adr/001-*.md`, `docs/adr/002-*.md`, `firebase/firestore.rules`, `firebase/test/rules/*.test.ts`

### ✅ Checkpoint 1
- [ ] Split engine 100% covered, property test green · [ ] Rules tests green · [ ] Owner reviews data model summary

---

## Phase 2 — Identity & parental consent

- [x] **Task 10: Splash, sign in, create account, age gate** — M · Deps: 4, 9 · UC-1–4
  - Acceptance: splash routes by auth/consent state; Google + email sign-in; email verification screen with 60 s resend; sign-up collects name, email, password, DOB, notice acceptance (Google users asked DOB once); under-13 refused; 13–17 → consent-pending; 18+ → Home.
  - Verify: widget tests for each route; manual sign-up on emulator against dev project.
  - Files: `app/lib/features/auth/**`, `app/lib/features/splash/**`, tests

- [x] **Task 11: Parental consent backend** — M · Deps: 9, 10 · 👤 owner picks email provider · Spec §7.1
  - Acceptance: functions `requestParentalConsent`, `decideParentalConsent`, scheduled expiry/reminders (day 3, 6, expire day 7 → delete child); signed single-use tokens; guardian must be a verified 18+ account and not the child; consent record immutable to the child; resend limited to 3/day.
  - Verify: functions tests for consent, decline, expiry, under-18 guardian, self-as-guardian, rate limit.
  - Files: `firebase/functions/src/consent/*.ts`, `firebase/firestore.rules`, tests

- [x] **Task 12: Parental consent UI** — M · Deps: 11 · Spec §7.1, §7.3
  - Acceptance: child waiting screen (parent email, resend, change email); consent page on Hosting + in-app deep link with child notice and Give/Decline; parent "Linked children" list with withdraw (48 h freeze-then-delete) and data download.
  - Verify: widget tests; manual run of consent and decline paths with two emulator accounts.
  - Files: `app/lib/features/consent/**`, `firebase/hosting/consent/index.html`, tests

- [x] **Task 13: Minor protections and turning 18** — S · Deps: 12 · Spec §7.2, §7.4
  - Acceptance: Crashlytics/analytics disabled for under-18 accounts; location features hidden; on 18th birthday user must accept the adult notice, parent link removed and parent notified.
  - Verify: unit tests for age logic (incl. 29 Feb birthdays); functions test for the birthday job.
  - Files: `app/lib/core/privacy/minor_policy.dart`, `firebase/functions/src/consent/turn18.ts`, tests

> **Deferred owner check (from Task 10):** sign in with Google on the emulator against the real `roamio-dev-varun` project, using the owner's own Google account. Needs the owner at the Mac.

### ✅ Checkpoint 2 — Journey E passes manually
- [ ] 16-year-old signs up → parent consents → child reaches Home · [ ] Decline deletes the child · [ ] Owner approves

---

## Phase 3 — Adventures & squad

- [x] **Task 14: Countries and categories data** — S · Deps: 4
  - Acceptance: `app/tool/import_data.dart` converts `data/world_countries_dataset.md` and `data/travel_expense_categories_table.md` into bundled JSON (195 countries with code, flag, currency, symbol, landmark; 10 categories with icons).
  - Verify: test asserts 195 countries and every currency code is valid ISO 4217.
  - Files: `tools/import_data.dart`, `app/assets/data/*.json`, test

- [x] **Task 15: Create adventure and Home** — M · Deps: 10, 14 · UC-5, 6, 8
  - Acceptance: 3-step create flow (country/city → name/description → dates; base currency auto-filled, editable); creator becomes Squad Leader; Home shows greeting, Hero, upcoming, past (collapsed), invites; empty state with one pulsing New Adventure button.
  - Verify: widget tests for empty/populated Home and each create step's validation (end ≥ start).
  - Files: `app/lib/features/adventures/**`, `app/lib/features/home/**`, tests

- [x] **Task 16: Country banners** — M · Deps: 15 · Spec §9.2
  - Acceptance: `getBanner` function searches Unsplash by landmark and caches Unsplash's resized WebP link (1600 px) + photographer credit in `banners/{country}` (re-hosting would break Unsplash's terms); app caches on device; gradient + flag fallback. Not done: pre-warming popular countries. Own-photo banners moved to Task 21.
  - Verify: functions test with mocked Unsplash (hit, miss, API failure); second creation for same country makes no API call.
  - Files: `firebase/functions/src/banners/*.ts`, `app/lib/features/adventures/ui/banner.dart`, tests

- [x] **Task 17: Invite links** — M · Deps: 15 · UC-9, 12
  - Acceptance: leads generate/revoke 8-char codes valid 14 days; Share invite opens the share sheet; Hosting landing page `/i/<code>` shows adventure name, copy-code and Download APK; Android App Link opens the app; clipboard check on first launch and "Have an invite code?" field on Home.
  - Verify: functions tests (expired, revoked, unknown code); manual: link opens app on emulator.
  - Files: `firebase/functions/src/invites/*.ts`, `firebase/hosting/i/index.html`, `app/lib/features/invites/**`, `app/android/app/src/main/AndroidManifest.xml`

- [x] **Task 18: Join a squad** — S · Deps: 17 · UC-13, 14
  - Acceptance: invites list on Home; Join squad calls `joinAdventure` (adds member server-side); leads get a push + in-app card with Make co-lead / Remove.
  - Done: join, lead cards, `makeCoLead`/`removeMember` (card actions; Task 19 adds demote/leave/hand-over). **Push not yet sent**: it needs the `firebase_messaging` package (new dependency, owner OK pending); the card data in `users/{uid}/notifications` is ready to drive it.
  - Verify: functions test for join (already member, adventure archived, minor pending consent refused); widget test for the card.
  - Files: `firebase/functions/src/invites/join.ts`, `app/lib/features/invites/ui/*`, tests

- [x] **Task 19: Squad roles** — M · Deps: 18 · UC-15–17
  - Acceptance: leader promotes/demotes co-leads; leads remove members (marked Left if they have tab history); leader must hand over before leaving; 🎩 on lead avatars.
  - Verify: functions + rules tests for each role change and forbidden case (co-lead demoting leader, member removing anyone).
  - Files: `firebase/functions/src/squad/*.ts`, `app/lib/features/squad/**`, tests

- [x] **Task 20: Pals** — S · Deps: 19 · UC-18
  - Acceptance: leads add a pal by nickname only; remove (marked Left if in tabs); pals listed in the squad with a "Pal" badge.
  - Verify: rules tests (member can't add pal); widget test.
  - Done: Remove marks a pal Left (never deleted, per DATA_MODEL) and hides them from the squad; tabs keep their history.
  - Files: `app/lib/features/squad/ui/pals.dart`, `firebase/firestore.rules`, tests

- [x] **Task 21: Edit and archive adventures** — S · Deps: 19 · UC-10, 11
  - Acceptance: leads edit name, description, dates, banner (including replacing it with their own photo, moved from Task 16); base currency locked once a tab exists; adventures move to Past the day after end date; tabs allowed for 7 more days.
  - Verify: rules tests for currency lock; unit tests for status by date.
  - Files: `app/lib/features/adventures/ui/edit_adventure.dart`, `firebase/firestore.rules`, tests
  - Done: edit name, description, city, dates, currency (locked with tabs); country fixed; `tabsOpenOn` (end + 7 days) ready for Task 23. Own-photo banner split out below.

- [ ] **Task 21b: Lead replaces the banner with their own photo** — S · Deps: 21 · UC-10
  - Acceptance: leads pick a photo; it's compressed and EXIF-stripped on device, uploaded to Storage, and replaces `bannerUrl`; "Use country photo" resets it.
  - Needs owner OK: new dependencies (photo picker, image compression) and Storage use (cost).
  - Verify: storage rules allow + deny tests (leads only, image type, size cap); widget test.

### ✅ Checkpoint 3 — Journeys A and B pass manually
- [ ] Create → share → join (fresh install) → promote co-lead → add pal · [ ] Owner approves

---

## Phase 4 — Tabs & splits

- [ ] **Task 22: Image pipeline** — S · Deps: 4 · Spec §10
  - Acceptance: camera/gallery picker; compress to ≤ 1600 px (2048 for bills) WebP q80; EXIF stripped; upload queue that survives offline and app restarts; Storage rules reject > 1 MB or non-WebP.
  - Verify: test with a 12 MB sample photo → ≤ 400 KB, no EXIF; storage rules tests.
  - Files: `app/lib/core/images/*.dart`, `firebase/storage.rules`, tests

- [ ] **Task 23: Add tab (basic)** — M · Deps: 8, 20 · UC-21
  - Acceptance: amount, currency (default base), date (≤ today), category, description, single payer "You", equal split across ticked participants; writes tab with `fxDate`.
  - Verify: widget tests for validation; manual add on emulator appears for another member.
  - Files: `app/lib/features/tabs/**`, tests

- [ ] **Task 24: Multiple payers, custom % and inline pal** — M · Deps: 23 · UC-21, 22
  - Acceptance: "Split payment" reveals payers (must total amount); Custom % (creator only) with live "x% of 100%" counter, Save disabled until 100.00%; unticking in % mode resets to Equal with a notice; leads see + Add pal.
  - Verify: widget tests for each validation path.
  - Files: `app/lib/features/tabs/ui/payers_editor.dart`, `percent_editor.dart`, tests

- [ ] **Task 25: Memories and location on tabs** — S · Deps: 22, 23
  - Acceptance: up to 4 memories per tab; optional location with permission (never for minors).
  - Verify: widget test (5th photo blocked; location hidden for minor).
  - Files: `app/lib/features/tabs/ui/memories.dart`, `location_picker.dart`, tests

- [ ] **Task 26: Scan bill (OCR)** — S · Deps: 22, 23
  - Acceptance: ML Kit on-device text recognition prefills amount, date and merchant; user confirms; behind `ocr_enabled` flag.
  - Verify: unit tests of the parser with 10 sample receipt texts (₹, €, $, ฿ formats).
  - Files: `app/lib/features/tabs/data/receipt_parser.dart`, `ui/scan_bill.dart`, tests

- [ ] **Task 27: Adventure page** — M · Deps: 23 · UC-23
  - Acceptance: banner header with tab sheet scrolling over it; tabs grouped by day; row shows your share; tab detail (payers, shares, memories, map); creator edits, leads delete (soft).
  - Verify: widget tests (empty, populated, deleted tab); manual scroll check.
  - Files: `app/lib/features/adventures/ui/adventure_page.dart`, `app/lib/features/tabs/ui/tab_detail.dart`, tests

- [ ] **Task 28: Daily FX rates** — S · Deps: 5, 7 · Spec §9.1
  - Acceptance: scheduled function stores `fx_rates/{date}` from open.er-api.com; fallback to last available day; app reads and caches rates offline.
  - Verify: functions test with mocked API (success, outage).
  - Files: `firebase/functions/src/fx/*.ts`, `app/lib/features/splits/data/fx_repository.dart`, tests

- [ ] **Task 29: Split screen** — M · Deps: 8, 27, 28 · UC-24–26
  - Acceptance: defaults to active adventure else Overall; headline first (owed / owe / all square); on tap: who pays whom, per-person balances incl. pals, by category, by day; all in viewer's profile currency.
  - Verify: widget tests with fixture data matching spec §6 example.
  - Files: `app/lib/features/splits/ui/*.dart`, tests

- [ ] **Task 30: Mark as settled** — S · Deps: 29 · UC-26a
  - Acceptance: record full/partial settlement from a suggested transfer; members in the transfer (or any lead for pal transfers) can record/undo; other party notified; activity entry.
  - Verify: rules tests (who may record); split-engine test that settling all transfers gives all square.
  - Files: `app/lib/features/splits/ui/settle_sheet.dart`, `firebase/firestore.rules`, tests

- [ ] **Task 31: Export PDF and Excel** — S · Deps: 29 · UC-27
  - Acceptance: PDF and XLSX with summary, transfers, full tab list; shared via share sheet; no location in a minor's export.
  - Verify: unit test opens generated XLSX and checks totals; manual open of PDF.
  - Files: `app/lib/features/splits/data/export_service.dart`, tests

### ✅ Checkpoint 4 — Journey C passes manually
- [ ] Mixed-currency, multi-payer, custom-% trip with a pal is correct and can be settled to all square · [ ] Owner approves

---

## Phase 5 — Budget, offline, profile

- [ ] **Task 32: Personal budget and alerts** — M · Deps: 29 · UC-19, 20
  - Acceptance: set budget per adventure (private); Firestore-triggered function computes the user's share and sends FCM + in-app alert once at each threshold from remote config; changing budget resets alerts.
  - Verify: rules test (others can't read); functions tests (79% no alert, 80% one alert, duplicate trigger no repeat).
  - Files: `app/lib/features/budget/**`, `firebase/functions/src/budget/*.ts`, tests

- [ ] **Task 33: Offline mode and Sync button** — M · Deps: 23, 30 · UC-30–33
  - Acceptance: spike confirms `disableNetwork`/`enableNetwork` behaviour; offline banner + Sync button with the spec's exact text; queued tabs, settlements and photos upload on Sync; online-only actions disabled with reason; overwritten edits logged in activity.
  - Verify: integration test in airplane mode on emulator (Journey D).
  - Files: `app/lib/features/sync/**`, `app/lib/core/connectivity/*.dart`, tests

- [ ] **Task 34: You page** — S · Deps: 22 · UC-28
  - Acceptance: photo, name, description, profile currency, notification and location toggles.
  - Verify: widget tests.
  - Files: `app/lib/features/profile/**`, tests

- [ ] **Task 35: Privacy centre** — M · Deps: 34, 12 · UC-29, Spec §8
  - Acceptance: download my data (JSON + photos zip via function), also offered to a parent for each linked child (deferred from Task 12); delete account (function: erase profile/photos/budgets, tabs keep "Deleted user"); nominate a person; grievance contact; per-purpose consent toggles; audit log entries kept 1 year.
  - Verify: functions tests for export and deletion (balances unchanged after deletion).
  - Files: `app/lib/features/profile/ui/privacy_centre.dart`, `firebase/functions/src/privacy/*.ts`, tests

- [ ] **Task 36: Weather** — XS · Deps: 15 · UC-7
  - Acceptance: Open-Meteo on the Hero card, cached 30 min, hidden on failure, city-based for minors or without permission.
  - Verify: unit test of the client with a mocked response and failure.
  - Files: `app/lib/features/home/data/weather_client.dart`, test

- [ ] **Task 37: Remote config** — S · Deps: 4 · Spec §11
  - Acceptance: all keys wired with in-app defaults; `docs/REMOTE_CONFIG.md` lists every key.
  - Verify: unit test that defaults load when fetch fails.
  - Files: `app/lib/core/config/remote_config.dart`, `docs/REMOTE_CONFIG.md`, test

- [ ] **Task 38: Update popup** — S · Deps: 37 · UC-34
  - Acceptance: checks GitHub latest release at most once per 24 h; dismissible popup with notes and Download; blocking when below `min_supported_version`.
  - Verify: unit tests for version comparison and throttling.
  - Files: `app/lib/features/updates/**`, tests

### ✅ Checkpoint 5 — Journeys D and F pass manually
- [ ] Offline → Sync works across two devices · [ ] Budget alert reaches only its owner · [ ] Export + delete work · [ ] Owner approves

---

## Phase 6 — Polish & ship

- [ ] **Task 39: UX pass** — M · Deps: 38
  - Acceptance: one primary chartreuse CTA per screen with 3-cycle pulse (respects reduced motion); every screen's empty/error/offline state has one next action (checklist in `tasks/screen_states.md`); TalkBack labels, 48 dp targets, 4.5:1 contrast.
  - Verify: checklist complete; widget test sweep for states.
  - Files: `app/lib/core/ui/primary_button.dart`, `tasks/screen_states.md`, screens as needed

- [ ] **Task 40: Compliance and project docs** — S · Deps: 35 · 👤 owner picks grievance email
  - Acceptance: `PRIVACY_NOTICE.md` (adult + child versions), `BREACH_RESPONSE.md`, README updated (setup, run, release), ADRs current; notice published on Hosting.
  - Verify: links work in-app and on Hosting.
  - Files: `docs/PRIVACY_NOTICE.md`, `docs/BREACH_RESPONSE.md`, `README.md`, `firebase/hosting/privacy/index.html`

- [ ] **Task 41: End-to-end journey tests** — M · Deps: 39
  - Acceptance: `integration_test` covers Journeys A–F against emulators.
  - Verify: `flutter test integration_test` passes locally and in CI (nightly).
  - Files: `app/integration_test/*.dart`, `.github/workflows/e2e.yml`

- [ ] **Task 42: Release pipeline** — S · Deps: 6 · 👤 owner backs up signing key
  - Acceptance: upload key generated and stored as CI secret; tag `vX.Y.Z` builds a signed prod APK and publishes a GitHub Release with notes.
  - Verify: tag `v0.1.0-rc1` produces a downloadable APK that installs on the emulator.
  - Files: `.github/workflows/release.yml`, `app/android/app/build.gradle.kts`

- [ ] **Task 43: Security, privacy and code review** — S · Deps: 41
  - Acceptance: security-auditor and code-reviewer passes; all high/critical findings fixed; dependency audit clean.
  - Verify: review reports saved in `docs/reviews/`.
  - Files: `docs/reviews/*.md`, fixes as needed

- [ ] **Task 44: Pilot** — S · Deps: 42, 43 · 👤 owner invites users
  - Acceptance: `v1.0.0` released; pilot guide (install APK, Play Protect note, how to report issues); 10 users onboarded; feedback form; issues triaged into GitHub Issues.
  - Verify: 10 active accounts; spec §15 criteria 1–9 ticked.
  - Files: `docs/PILOT_GUIDE.md`

### ✅ Checkpoint 6 — Ship
- [ ] All spec §15 success criteria met · [ ] Owner sign-off

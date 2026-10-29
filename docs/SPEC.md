# Spec: Roamio — Phase 1 (Android pilot)

> **Split bills. Not friendships.** · *Instant peer splits. Zero awkward math.*

Status: **APPROVED 2026-10-27** · Last updated: 2026-10-27 · Source vision: [`docs/vision/roamio-product-vision.rtf`](vision/roamio-product-vision.rtf)

---

## 1. Objective

Roamio is a travel partner app for young solo, couple and group travellers. It splits shared trip costs fairly, keeps a log of spends with receipts and photos, and tells each traveller privately when they approach their own budget.

**Phase 1 goal:** a working Android app used by a **10-person pilot**, distributed as an APK via GitHub Releases, with every use case below working end to end, online and offline.

**Success looks like:** a pilot squad can create an adventure, invite each other, log tabs in mixed currencies (with multiple payers and custom % splits), go offline and sync later, and end the trip with a split report everyone agrees with — without opening a spreadsheet.

### 1.1 Glossary (app dictionary)

| Term | Meaning |
|---|---|
| **Adventure** | A trip. Has a country, dates, base currency and banner. |
| **Squad** | Everyone in an adventure: members (app users) and pals. |
| **Squad Leader** 🎩 | The member who created the adventure. Exactly one per adventure. |
| **Co-squad Lead** 🎩 | A member promoted by the Squad Leader. Same rights as the leader except managing leadership. |
| **Member** | An app user in the squad. |
| **Pal** | A person on the trip without the app. Added by a lead; nickname only; has their own balance. |
| **Tab** | One expense inside an adventure. |
| **Payer** | A squad member who paid (part of) a tab. |
| **Participant** | A member or pal whose share of a tab they owe. |
| **Split** | The calculated who-owes-whom for an adventure. |
| **Memory** | A photo attached to a tab (max 4). |

### 1.2 Out of scope for Phase 1

Payment gateway / in-app payments · Explore page · Web app (Phase 2) · iOS app (Phase 3) · Sign in with Apple (Phase 3) · Gamification · Duplicate-tab detection · Multiple languages (English only, built ready for translation).

---

## 2. Tech Stack

| Concern | Choice |
|---|---|
| App | **Flutter** (stable channel, version pinned in `app/.fvmrc` at setup), Dart, Material 3 themed to the Roamio design system |
| State / DI | Riverpod |
| Navigation | go_router (handles `roamio://` and `https://<host>/i/<code>` invite links) |
| Auth | Firebase Authentication — Google, email + password (with email verification) |
| Database | Cloud Firestore, region **asia-south1 (Mumbai)**, offline persistence on |
| Files | Cloud Storage for Firebase, asia-south1 |
| Server logic | Cloud Functions for Firebase (TypeScript, Node LTS), asia-south1 |
| Remote settings | Firebase Remote Config |
| Push | Firebase Cloud Messaging |
| Crash reporting | Firebase Crashlytics (**disabled for under-18 accounts**, see §7) |
| Hosting | Firebase Hosting — invite landing page, privacy notice, parental-consent page |
| OCR | Google ML Kit Text Recognition (on device, offline) |
| Image compression | `flutter_image_compress` |
| Exports | `pdf` + `excel` packages, generated on device |
| External APIs | open.er-api.com (FX rates, daily) · Unsplash API (banners) · Open-Meteo (weather) · GitHub Releases API (update check) · Email via a Firebase "Trigger Email" extension or SMTP provider (parental consent mails) |

Firebase **Blaze** (pay-as-you-go) plan is required for Storage and Functions. A budget alert at ₹500/month is set on day one.

---

## 3. Commands

```bash
# App (run from app/)
flutter pub get
dart format --set-exit-if-changed .
flutter analyze
flutter test --coverage
flutter test integration_test            # needs emulator + Firebase emulators
flutter run --flavor dev
flutter build apk --release --flavor prod

# Firebase (run from firebase/)
npm ci
npm run lint
npm test                                  # rules + functions tests against emulators
firebase emulators:start
firebase deploy --only firestore:rules,storage,functions,hosting --project roamio-prod
```

CI (GitHub Actions) runs format, analyze, unit/widget tests, rules tests and functions tests on every pull request. Tagging `vX.Y.Z` on `main` builds a signed release APK and attaches it to a GitHub Release.

---

## 4. Project Structure

```
README.md                  → What Roamio is, how to run it
docs/
  SPEC.md                  → This file
  adr/                     → Architecture decision records
  PRIVACY_NOTICE.md        → DPDP notice text shown in-app and on Hosting
  BREACH_RESPONSE.md       → Breach notification runbook
  REMOTE_CONFIG.md         → Every remote config key, type, default
design/                    → Stitch reference screens + DESIGN.md (visual reference only)
data/                      → Countries + expense category source data
app/                       → Flutter app
  lib/core/                → theme, router, remote config, connectivity, image compression
  lib/features/<feature>/  → auth, consent, home, adventures, squad, tabs, splits, profile, sync, updates
      data/                → Firestore repositories
      domain/              → pure Dart models + logic (no Flutter imports)
      ui/                  → screens + widgets
  test/                    → unit + widget tests, mirrors lib/
  integration_test/        → end-to-end user journeys
firebase/
  firestore.rules  storage.rules  firestore.indexes.json
  functions/src/           → TypeScript Cloud Functions
  test/                    → rules + functions tests
tasks/                     → plan.md, todo.md
.github/workflows/         → CI + release
```

---

## 5. Use Cases & Acceptance Criteria

Each item is written so it can become a test.

### 5.1 Onboarding & auth

- **UC-1 Splash:** shows logo, tagline and sub-tagline for ≤1.5 s while auth state and remote config load; routes to Login (signed out), Consent-pending (minor awaiting parent) or Home.
- **UC-2 Sign in:** Google or email + password. Email accounts must verify their email before reaching Home (a "Check your inbox" screen with Resend, max once per 60 s).
- **UC-3 Create account:** name, email, password (≥8 chars), **date of birth (required for everyone, including Google sign-ups)**, acceptance of the privacy notice. Name prefilled from Google, editable.
- **UC-4 Age check:** age < 18 → Parental consent flow (§7). Age ≥ 18 → Home. Date of birth cannot be in the future or > 120 years ago. Users under 13 are not allowed.

### 5.2 Home (bottom tab: Home)

- **UC-5** Shows "Hey <first name> 👋", then: the **Hero** card (current active adventure, or the next upcoming one), upcoming adventures, past adventures (collapsed), and **Invites** waiting to be accepted.
- **UC-6 Empty state:** with no adventures and no invites, the only prominent element is a pulsing **New Adventure** button.
- **UC-7 Weather:** the Hero card shows current weather for the user's location if location permission is granted, otherwise for the adventure's city. Hidden when unavailable — never an error state.

### 5.3 Adventures

- **UC-8 Create adventure** (any adult member or consented minor): step 1 country (searchable list of 195 from `data/`) + optional city; step 2 name (e.g. "College group's Bangkok adventure") + optional description; step 3 start/end dates. Base currency auto-filled from the country, editable. Banner auto-loaded (§9.2), replaceable with a camera/gallery photo. The creator becomes **Squad Leader**.
- **UC-9 Invite link:** after creation the user sees one button, **Share invite**, which opens the Android share sheet with `https://<host>/i/<CODE>` and a copy button. Codes are 8 characters, valid 14 days, revocable and regenerable by leads.
- **UC-10 Edit adventure** (leads only): name, description, dates, banner, base currency (base currency locked once a tab exists).
- **UC-11 Archive:** adventures end automatically the day after the end date (move to "Past") and stay readable; leads can still add tabs for 7 days after.

### 5.4 Joining via invite

- **UC-12** User B opens the link. With the app installed it opens straight to the invite. Without it, the landing page shows the adventure name, the code with a Copy button, and a Download APK button. On first launch the app checks the clipboard (with Android's paste notice) for a Roamio code and offers to use it; otherwise a "Have an invite code?" field on Home accepts it.
- **UC-13** The invite appears under **Invites** on Home. Tapping it shows the adventure name, leader and dates with one button, **Join squad**. Joining adds the user as Member.
- **UC-14** All leads get a push notification and an in-app card: "<Name> joined your squad" with two actions: **Make co-lead** and **Remove**.

### 5.5 Squad roles & pals

- **UC-15** The Squad Leader can promote a member to Co-squad Lead and demote them. Leads show a 🎩 on their avatar within that adventure.
- **UC-16** Leads can remove a member or pal. If they are a payer or participant on any tab, they are marked **Left** instead of deleted: they keep their history and balance but can't be added to new tabs.
- **UC-17** The Squad Leader can't leave without first handing leadership to another member. If they are the only member, leaving archives the adventure.
- **UC-18 Pal:** leads add a pal with a nickname only (no email, phone or photo). Pals appear in tab participant lists and have their own balance row in the split report.

### 5.6 Personal budget

- **UC-19** Each member can set a personal budget for an adventure (amount + currency, default their profile currency). **Only they can read it** — enforced by security rules, not just hidden in the UI.
- **UC-20** The budget is measured against the user's **own share** of tabs (not what they paid). A push + in-app alert fires once at 80% and once at 100% (thresholds from remote config). Changing the budget resets the alerts.

### 5.7 Tabs (expenses)

- **UC-21 Add tab** (any member, never a pal). Fields:
  - Optional **Scan bill** (camera) → OCR prefills amount, date and description; the user confirms.
  - **Amount** (required, > 0, ≤ 10,000,000 in that currency), **currency** (default adventure base currency), **date** (default today, editable, can't be later than today), **category** (10 categories from `data/`), optional **description**.
  - **Paid by:** defaults to "You · 100%". A "Split payment" link reveals the payer list; payer amounts must total the tab amount exactly.
  - **Split between:** multi-select of active members and pals (all ticked by default). Leads also see **+ Add pal** here to create a pal inline for this tab (the pal then joins the squad); members who aren't leads don't. Mode **Equal** (default) or **Custom %** (creator only); custom percentages must total exactly 100.00%. Save stays disabled with a live "x% of 100% assigned" counter until valid.
  - Optional up to **4 memories** (camera/gallery), optional **location** (only with location permission; never for under-18 users).
- **UC-22 Edit / delete tab:** the creator can edit everything; leads can delete any tab (soft delete, shown in activity). Unticking a participant while in Custom % mode resets the split to Equal with a visible notice.
- **UC-23 Adventure page:** banner header with the tab list as a sheet that scrolls up over it; tabs grouped by day, newest first; each row shows description, amount and the viewer's own share. Tapping opens tab details (payers, shares, memories, map pin).

### 5.8 Split report (bottom tab: Split)

- **UC-24** Defaults to the **active adventure** if there is one, otherwise **Overall** (the user's spend across all adventures, tap an adventure to drill in).
- **UC-25 Adventure split** shows first a single headline ("You're owed ₹1,240" / "You owe ₹560" / "All square 🎉"), then on request: **who pays whom** (minimum transfers), per-person balances (members and pals), spend by category, spend by day.
- **UC-26** All amounts appear in the **viewer's profile currency**, converted using each tab's stored FX rate date (§9.1); the base-currency figure is shown on tap.
- **UC-26a Mark as settled:** next to each suggested transfer, **Mark as settled** records that one person paid another outside the app (no money moves). Amount defaults to the suggested transfer and can be lowered for a partial payment. Either member in the transfer can record it; for a pal's transfer, the member involved or any lead records it. The other member gets a notification. Either party or a lead can undo it, and the undo appears in the activity log. Recording works offline and syncs like a tab.
- **UC-27 Export:** PDF and Excel of the adventure split (summary, transfers, full tab list), shared via the Android share sheet. A minor's export never includes location.

### 5.9 Profile (bottom tab: You)

- **UC-28** Photo (camera/gallery), name, optional description, profile currency, notification and location toggles.
- **UC-29 Privacy centre:** download my data (JSON + photos zip), correct my data, delete my account, nominate a person, raise a concern (grievance contact), withdraw individual consents. For parents: **Linked children** (§7).

### 5.10 Offline & sync

- **UC-30** The app works fully offline after first sign-in: browse adventures, add/edit tabs, attach memories (queued).
- **UC-31** When the device is offline, Roamio switches Firestore to offline mode. When connectivity returns, a **Sync** button appears on Home and the adventure page with the text *"We know the data might be of essence, click here to sync the adventure with your squad"*. Pressing it re-enables the network, uploads queued writes and photos, and shows "Synced ✓" or the error.
- **UC-32 Conflicts:** last write wins per tab. If a synced edit overwrote someone else's newer edit, both users see an activity entry ("Ari's offline edit replaced your change to *Dinner*").
- **UC-33** Joining, inviting, role changes and account deletion need a connection; their buttons are disabled offline with a short reason.

### 5.11 App updates

- **UC-34** On launch (max once per 24 h) the app compares its version with the latest GitHub Release of `VarunParikh/Roamio`. If newer, it shows a dismissible popup with release notes and **Download update**. If below `min_supported_version` (remote config), the popup can't be dismissed.

---

## 6. Split Math (rules)

- All money is stored as **integer minor units** (paise, cents) plus an ISO 4217 code. No floating point.
- Percentages are stored as **basis points** (100% = 10,000).
- Equal split: `share = floor(amount / n)`; the remainder (`amount − share × n`) goes one minor unit at a time to participants in list order. Shares always total the tab amount.
- Custom %: `share_i = floor(amount × bp_i / 10,000)`; remainder distributed the same way.
- Payer amounts must total the tab amount.
- Per tab: `net_i = paid_i − share_i`. The adventure balance is the sum of nets converted into base currency. **The sum of all balances is always exactly 0** (property-tested).
- A settlement of amount `s` from A to B adds `s` to A's balance and subtracts `s` from B's, so the zero-sum rule still holds.
- **Who pays whom:** greedy match of largest debtor to largest creditor, giving at most n−1 transfers.
- **Worked example:** ₹3,000 paid by Ari ₹2,000 + Ben ₹1,000; shares Ari 50%, Ben 25%, Pal Kiko 25% → Ari +₹500, Ben +₹250, Kiko −₹750 (sums to zero).

---

## 7. Under-18 Users — Verifiable Parental Consent (DPDP Act §9, Rules 2025 Rule 10)

Roamio may serve users aged **13–17** only after a parent or lawful guardian gives verifiable consent.

### 7.1 Flow

1. **Age detected:** at sign-up the date of birth shows the user is under 18. The account is created in state `pending_parental_consent`, storing only name, email, date of birth and auth ID.
2. **Waiting screen:** the minor sees "Almost there! A parent or guardian needs to say yes." with one field: parent/guardian email (+ relationship). It must differ from the minor's email.
3. **Consent request:** a Cloud Function emails the parent a single-use, signed link (valid **7 days**). Reminders are sent on day 3 and day 6. The minor can resend (max 3 per day) or change the parent email.
4. **Parent verification:** the link opens the app if installed; otherwise a Hosting page explains the request and offers the app. *(Pilot: the decision is always made in the app, since the parent needs a Roamio account anyway.)* The parent must **sign in or create a Roamio account** with a verified email and a date of birth showing they are **18 or older** — reliable identity and age details held by the Data Fiduciary, as Rule 10 allows. The page states that falsely claiming to be the guardian is an offence.
5. **Notice & decision:** the parent sees the child-specific notice (what's collected, why, protections below, how to withdraw) and taps **I give consent** or **Decline**.
6. **Record:** a `parentalConsents/{childUid}` record stores parent UID, child UID, notice version, verification method, timestamp and decision. It is kept for the life of the account plus 1 year and is never editable by the child.
7. **Outcome:**
   - **Consent →** the child's account becomes active; the child sees "You're in! 🎉" and any invite they arrived with.
   - **Decline or expiry after 7 days →** the child's account and data are deleted; the child is told by email.

### 7.2 Protections for under-18 accounts (DPDP §9(3))

- No behavioural tracking or monitoring: Crashlytics and any analytics are **off**; no targeted advertising (Roamio has no ads).
- Location tagging on tabs and location-based weather are **disabled**; weather uses the adventure's city.
- The personal budget stays private from the squad (the parent can see it only through a data export they request).

### 7.3 Parent controls (You → Linked children)

- See each linked child: status, date of consent.
- **Withdraw consent:** the child's account is frozen at once and deleted after a 48 h grace period (the child is notified). Tabs they were part of remain for the squad as "Deleted user".
- **Download the child's data** and **request correction** (uses the data export from Task 35).

### 7.4 Turning 18

On the child's 18th birthday (checked daily, India date) the parent link is removed and the parent notified, and the app asks them to accept the adult privacy notice themselves. Until they accept, they see only that screen (stricter than read-only, and one tap away).

### 7.5 Edge cases

| Case | Behaviour |
|---|---|
| Parent email belongs to an account that is under 18 | Consent refused: "A guardian must be 18 or older." |
| Parent is the same account as the child | Blocked at step 2. |
| One parent, several children | Supported; each child is a separate consent record. |
| Child arrived via an invite link | Invite is saved and shown after consent; no squad data is shared before it. |
| Child tries to change date of birth | Not editable in-app; changes only via the grievance contact, with manual review. |
| Under-13 sign-up | Refused with a friendly message; no account data kept. |
| Parent deletes their own Roamio account | Children's consent stays valid; parent is asked to confirm, and an email reminds them how to withdraw. |

**Before public launch (not the pilot):** add DigiLocker / authorised virtual-token age verification for parents (see Open Questions).

---

## 8. DPDP Compliance (all users)

| Duty | Implementation |
|---|---|
| Notice (§5, Rule 3) | Plain-English notice at sign-up and in the Privacy centre; versioned in `docs/PRIVACY_NOTICE.md`. |
| Consent per purpose, easy withdrawal (§6) | Separate toggles for location, camera/gallery, notifications; each revocable in one tap. |
| Minimise data | No phone number or contacts. Pals are a nickname only. **EXIF (including GPS) is stripped from every uploaded photo.** |
| Rights (§11–14) | Access/export, correction, erasure, nomination, grievance — all in the Privacy centre. Grievances acknowledged within 7 days. |
| Erasure | Account deletion removes profile, photos, budgets and tokens within 30 days; tabs keep a "Deleted user" placeholder so balances stay correct. |
| Security safeguards (§8(5), Rule 6) | TLS in transit; Google-managed encryption at rest; least-privilege security rules; audit log of data access and changes kept **1 year**. |
| Breach (§8(6), Rule 7) | `docs/BREACH_RESPONSE.md`: inform affected users and the Data Protection Board without delay, detailed report to the Board within 72 h. |
| Data location | All Firebase resources in asia-south1. |

*This is an engineering checklist, not legal advice; have the notice reviewed by a lawyer before any public launch.*

---

## 9. External Data

### 9.1 Currency
- The country → currency mapping comes from `data/world_countries_dataset.md`, imported into a bundled JSON asset.
- A scheduled function fetches daily USD-based rates from open.er-api.com into `fx_rates/{yyyy-mm-dd}`. Each tab stores its `fxDate`; all conversion uses that day's rates, so old totals never change.
- If the API is down, the last available day's rates are used and the tab is marked "rate from <date>".

### 9.2 Banner
- When an adventure is shown, the app looks up `banners/{countryCode}`. If missing, the `getBanner` function searches Unsplash for the country's landmark (from the dataset), and caches the photo link and photographer credit in `banners/{countryCode}` for everyone.
- **Unsplash's API terms require photos to stay on Unsplash's CDN**, so instead of re-hosting, Roamio stores Unsplash's link with resize and compression parameters (1600 px, WebP, quality 80). The app caches the image on the device, so it loads instantly after the first time.
- The photographer is credited on the banner with a link to their Unsplash page.
- If nothing is found or Unsplash is unreachable, a gradient banner with the flag emoji is shown and the lookup is tried again later. Leads can replace the banner with their own photo (Task 21).

### 9.3 Weather
- Open-Meteo, cached 30 minutes; hidden on failure.

---

## 10. Photos

- Every photo (profile, banner, memory, scanned bill) is compressed **on device before upload**: longest side ≤ 1600 px (2048 px for bills, to keep OCR legible), WebP quality 80, EXIF removed. Target: a 12 MB camera photo uploads at ≤ 400 KB.
- Storage rules reject files > 1 MB or not of type `image/webp`.
- Max 4 memories per tab; uploads queue offline and retry with backoff.

---

## 11. Remote Config (change without an app update)

Copy text, feature flags (`ocr_enabled`, `weather_enabled`, `export_enabled`), `budget_alert_thresholds` (default `[80, 100]`), `min_supported_version`, `invite_validity_days`, `consent_link_validity_days`, primary CTA animation on/off, and category list ordering. All keys are documented in `docs/REMOTE_CONFIG.md` with in-app defaults so the app works when remote config is unreachable.

---

## 12. UX Rules

- **One primary button per screen**, in chartreuse `#D4FF00`, with a subtle pulse (scale 1 → 1.04, 1.6 s, stops after 3 cycles or on interaction; respects Android "remove animations").
- **Progressive disclosure:** headline number first; details on tap.
- Visual language from `design/DESIGN.md`: Plus Jakarta Sans, obsidian ink, pill buttons, 1.5–2 rem card radius, floating frosted bottom bar with **Home · Split · You**.
- Sheets scroll up over hero banners (adventure page, home).
- **No dead ends:** every empty, error and offline state has exactly one clear next action. Verified by a screen-state checklist in `tasks/`.
- Accessibility: touch targets ≥ 48 dp, contrast ≥ 4.5:1 for text, TalkBack labels on all icons.

---

## 13. Code Style

Dart: `flutter_lints` + `very_good_analysis`; `dart format`; files `snake_case.dart`; one public widget per file; domain logic pure Dart with no Flutter or Firebase imports.

```dart
/// Splits [amountMinor] equally; any remainder goes one unit at a time
/// to participants in list order, so shares always sum to the total.
List<Share> splitEqually(int amountMinor, List<ParticipantId> participants) {
  if (participants.isEmpty) throw ArgumentError('No participants');
  final base = amountMinor ~/ participants.length;
  final remainder = amountMinor - base * participants.length;
  return [
    for (var i = 0; i < participants.length; i++)
      Share(participants[i], base + (i < remainder ? 1 : 0)),
  ];
}
```

TypeScript (functions): strict mode, ESLint + Prettier.

---

## 14. Testing Strategy

| Level | Tooling | Scope | Bar |
|---|---|---|---|
| Unit | `flutter_test` | split math, FX conversion, validation, settlement | **100%** line coverage on `domain/splits`; property test: balances always sum to 0 |
| Widget | `flutter_test` | each screen's states (empty, loading, error, offline, populated) | every screen |
| Security rules | `@firebase/rules-unit-testing` + Vitest + emulator | budgets private, pals can't write, only leads manage squad, minors' pending state blocks data access | every rule has allow + deny tests |
| Functions | Vitest + emulator | invite join, banner, FX, budget alerts, consent flow, deletion | ≥ 80% |
| Integration | `integration_test` on emulator | the 6 journeys in §15 | all pass before each release |
| Manual pilot | 10 users, real phones | full trip simulation | feedback form + Crashlytics review |

Overall app coverage ≥ 70%.

---

## 15. Success Criteria (Phase 1 is done when…)

1. **Journey A – Leader:** sign up → create adventure → share invite → promote a joiner to co-lead → add a pal.
2. **Journey B – Invitee:** open link without the app → install APK → sign up → accept invite → see the squad.
3. **Journey C – Tabs:** add a ₹ tab with 2 payers and custom % including a pal; add a € tab; split report is correct in the viewer's profile currency; balances sum to 0; marking every suggested transfer as settled shows "All square 🎉" for everyone.
4. **Journey D – Offline:** in airplane mode add 3 tabs with memories → reconnect → Sync → all squad members see them.
5. **Journey E – Minor:** 16-year-old signs up → parent consents by email link → child joins an adventure; location tagging unavailable. Decline path deletes the account.
6. **Journey F – Privacy:** budget alert at 80% reaches only its owner; data export and account deletion complete.
7. All CI checks green; APK published on GitHub Releases; update popup appears on the previous version.
8. A 12 MB photo uploads at ≤ 400 KB with no EXIF.
9. Pilot: 10 users complete a trip (real or simulated) with no data loss and zero crashes blocking a journey.

---

## 16. Boundaries

- **Always:** write a failing test before split-math or rules changes; run format, analyze and tests before each commit; keep money in integer minor units; compress and strip EXIF before upload; update this spec when a decision changes.
- **Ask first:** new dependencies; Firestore data-model changes after first deploy; anything that changes cost (Blaze usage); CI config changes; pushing to GitHub; publishing a release.
- **Never:** commit secrets or `google-services.json` for prod (CI injects them); store money as floats; let the UI be the only guard on private data; enable analytics for under-18 accounts; delete or skip failing tests to get to green.

---

## 17. Resolved Decisions (2026-10-27)

1. **Settlements:** "Mark as settled" is in Phase 1 (UC-26a).
2. **Parent verification:** a verified Roamio adult account is accepted for the pilot; DigiLocker / virtual-token verification is required before public launch.
3. **Grievance officer:** the project owner (Varun Parikh). Contact email is set when `docs/PRIVACY_NOTICE.md` is written; use a dedicated alias rather than a personal inbox.
4. **Invite host:** the free Firebase Hosting domain (`<project-id>.web.app`).
5. **Android package name:** `app.roamio.android`.
6. **Minimum age:** 13+. Ages 13–17 need parental consent (§7).
7. **Accounts:** the owner creates Google/Firebase (Blaze), Unsplash and email-provider accounts with step-by-step guidance in the setup tasks.

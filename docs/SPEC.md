# Spec: Roamio — Phase 1 (Android pilot)

> **Split bills. Not friendships.** · *Instant peer splits. Zero awkward math.*

Status: **APPROVED 2026-10-27** · Last updated: 2026-10-31 · Source vision: [`docs/vision/roamio-product-vision.rtf`](vision/roamio-product-vision.rtf)

---

## 1. Objective

Roamio is a travel partner app for young solo, couple and group travellers. It splits shared trip costs fairly, keeps a log of spends, and tells each traveller privately when they approach their own budget.

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
| **Admin** | The Squad Leader or a Co-squad Lead. |
| **Waiting tab** | A tab that an admin has not approved yet. It counts towards nothing. |
| **Personal tab** | A tab you paid and only you share. It needs no approval and only you can see it. |

### 1.2 Out of scope for Phase 1

Payment gateway / in-app payments · Uploading your own pictures: display pictures, banners and tab photos (next phase) · Explore page · Web app (Phase 2) · iOS app (Phase 3) · Sign in with Apple (Phase 3) · Gamification · Duplicate-tab detection · Multiple languages (English only, built ready for translation).

---

## 2. Tech Stack

| Concern | Choice |
|---|---|
| App | **Flutter** (stable channel, version pinned in `app/.fvmrc` at setup), Dart, Material 3 themed to the Roamio design system |
| State / DI | Riverpod |
| Navigation | go_router (handles `roamio://` and `https://<host>/i/<code>` invite links) |
| Auth | Firebase Authentication — Google, email + password (with email verification) |
| Database | Cloud Firestore, region **asia-south1 (Mumbai)**, offline persistence on |
| Files | Cloud Storage for Firebase, asia-south1 (for the next phase: no Phase 1 screen uploads a picture) |
| Server logic | Cloud Functions for Firebase (TypeScript, Node LTS), asia-south1 |
| Remote settings | Firebase Remote Config |
| Push | Firebase Cloud Messaging |
| Crash reporting | Firebase Crashlytics (**disabled for under-18 accounts**, see §7) |
| Hosting | Firebase Hosting — invite landing page, privacy notice, parental-consent page |
| OCR | Google ML Kit Text Recognition (on device, offline) |
| Image compression | `flutter_image_compress` (next phase, with uploads) |
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

- **UC-5** Shows "Hey <first name> 👋" with a small picture of you that opens You, then the offline card (only when offline, UC-31), the **adventure card**, **Needs you**, New adventure, Recent activity, then other trips.
  - **Adventure card:** the trip happening now (the most recently started, if several) or else the next one. Banner, badge, name, dates, weather, squad pictures (first 4 then "+N", pals included), **Add tab**, an arrow that expands it, and the photographer's credit. Tapping the card opens the adventure.
  - **Badge and subtitle:** "Current adventure" with "5 days left" ("Last day" on the final day); "Next adventure" with "Starts in 12 days".
  - **Expanded** (starts collapsed; the phone remembers): your budget (UC-19), daily spend (the 7 days ending today, today in blue, swipe for earlier, fewer bars on a short trip, "No spending yet" with no tabs; before the trip only once something has been spent; your own spend when you only have personal tabs), squad, recent activity; a count of tabs waiting for approval (leads and co-leads only, opening the tab list); the top category; the exchange rate on a trip in another currency; and Invite your squad for a lead still alone in the squad. **See split** and **View all** open Split on this adventure; the squad row opens the adventure's squad.
  - **Needs you:** the top 2 cards and See all, in this order: tabs to approve, invites, join cards, budget alerts, character prompt, notification prompt.
  - **New adventure** is a plain outlined button under the adventure card.
  - **Recent activity:** one row with the newest event across current and upcoming trips, opening that trip's Activity.
  - **Other trips:** "Also happening now" for other current trips; "Upcoming adventures" for future trips, with the date beside each card; Past adventures (collapsed). Trips that ended stay in Past; Add tab stays on their page for 7 days (UC-11). "Have an invite code?" stays as a small link.
- **Sign-in photo:** one of the same 10, drifting very slowly from left to right (still under reduced motion), and never the same as the image card's in that app open.
- **UC-6 Nothing ahead:** with no current or upcoming adventure, the top of Home is an image card, "Plan your next adventure", with a pulsing chartreuse **Create a new adventure**. Its image is chosen at random from the 10 bundled destination photos, a new one each time the app opens, and has a gradient dark enough for the text on all 10. Only invites sit above it; other prompts go below. With no adventures at all, a "No adventures yet" card follows; with past trips, the Past list does.
- **UC-7 Weather:** the adventure card shows current weather beside the dates, for the user's location if location permission is granted, otherwise for the adventure's city. Hidden when unavailable — never an error state.

### 5.3 Adventures

- **UC-8 Create adventure** (any adult member or consented minor): step 1 country (searchable list of 195 from `data/`) + optional city; step 2 name (e.g. "College group's Bangkok adventure") + optional description; step 3 start/end dates. Base currency auto-filled from the country, editable. Banner auto-loaded (§9.2). The creator becomes **Squad Leader**.
- **UC-9 Invite link:** after creation the user sees one button, **Share invite**, which opens the Android share sheet with `https://<host>/i/<CODE>` and a copy button. Codes are 8 characters, valid 14 days, revocable and regenerable by leads.
- **UC-10 Edit adventure** (leads only): name, description, dates, base currency (base currency locked once a tab exists).
- **UC-11 Archive:** adventures end automatically the day after the end date (move to "Past") and stay readable; leads can still add tabs for 7 days after.

### 5.4 Joining via invite

- **UC-12** User B opens the link. With the app installed it opens straight to the invite. Without it, the landing page shows the adventure name, the code with a Copy button, and a Download APK button. On first launch the app checks the clipboard (with Android's paste notice) for a Roamio code and offers to use it; otherwise a "Have an invite code?" field on Home accepts it.
- **UC-13** The invite appears under **Invites** on Home. Tapping it shows the adventure name, leader and dates with one button, **Join squad**. Joining adds the user as Member.
- **UC-14** All leads get a push notification and an in-app card: "<Name> joined your squad" with two actions: **Make co-lead** and **Remove**.

### 5.5 Squad roles & pals

- **UC-15** The Squad Leader can promote a member to Co-squad Lead and demote them. Leads show a 🎩 on their avatar within that adventure.
- **UC-16** Leads can remove a member or pal. If they are a payer or participant on any tab, they are marked **Left** instead of deleted: they keep their history and balance but can't be added to new tabs.
- **UC-17** The Squad Leader can't leave without first handing leadership to another member. If they are the only member, leaving archives the adventure.
- **UC-18 Pal:** only leads add a pal, with a nickname and a character, both required, on one screen (from the squad or from Add tab). No real name, email, phone or photo. Add stays disabled, with the reason shown, until both are filled; closing the picker keeps the nickname. The picker dims characters already used in this squad, but they can still be chosen. Leads can edit both later. Members see a hint on Add tab: "Need someone without the app? Ask a squad lead to add them." Pals appear in tab participant lists and have their own balance row in the split report.

### 5.6 Personal budget

- **UC-19** Each member can set a personal budget for an adventure (amount + currency, default their profile currency), at any time, including before and after the trip. **Only they can read it** — enforced by security rules, not just hidden in the UI. It appears as a widget on the expanded Home card, on the adventure page and in Split's top card: "₹768 left" or "₹500 over budget", the percentage and a bar. Tapping it opens the edit sheet, which has Save and Remove budget (with a confirmation). With no budget it offers a plain Set a budget. When tabs are waiting: "₹1,200 waiting for approval, not counted".
- **UC-20** The budget is measured against the user's **own share** of approved tabs plus their personal tabs (not what they paid). A push + in-app alert fires once at 80% and once at 100% (thresholds from remote config), including when an approval crosses a threshold. Changing the budget resets the alerts. An alert opens Split on its adventure.

### 5.7 Tabs (expenses)

- **UC-21 Add tab** (any member, never a pal). Fields:
  - Optional **Scan bill** (camera) → OCR prefills amount, date and description; the user confirms.
  - **Amount** (required, > 0, ≤ 10,000,000 in that currency; in another currency it shows what it comes to in yours as you type), **currency** (default adventure base currency), **date** (default today, editable, can't be later than today), **category** (10 categories from `data/`; the 4 most common show first, with View more), optional **description**.
  - **Paid by:** defaults to "You · 100%". A "Split payment" link reveals the payer list; payer amounts must total the tab amount exactly.
  - **Paid with** (required, per payer, set by the tab's creator): 💵 Cash, 💳 Card, 📱 UPI, 📝 Cheque, 🏦 Bank transfer, 🔖 Other. Starts on the method last used on that phone; with none yet, Save stays disabled and says why. It records how someone paid; Roamio moves no money. An unknown value shows as Other and never invalidates a tab.
  - **Split between:** multi-select of active members and pals (all ticked by default). Leads also see **+ Add pal** here to create a pal inline for this tab (the pal then joins the squad); members who aren't leads don't. Mode **Equal** (default) or **Custom %** (creator only); custom percentages must total exactly 100.00%. Save stays disabled with a live "x% of 100% assigned" counter until valid.
  - Optional **location**: an Add location button that turns the setting on and asks Android's permission when tapped; never for under-18 users. Scan bill reads on the phone and uploads and keeps nothing.
  - **Split between** shows each person's picture.
- **UC-21a Approval:** a tab waits for an admin unless it is personal (you paid and only you share; automatic, and it changes if someone else is added).
  - Admins see **Approve** and **Reject** (plain buttons; Reject confirms and takes an optional reason) on the waiting tab's row in the adventure's tab list, and get a push and a Needs you card. Approving needs a connection; the buttons say why when offline. It stays possible after the 7-day window for adding tabs.
  - Nobody approves their own tab while another admin exists. With only one admin, their tab is approved automatically; if the second admin leaves, tabs waiting on them are approved. The first decision wins, and a second admin sees "already decided". Tabs of removed or deleted members can still be decided.
  - A waiting or rejected tab counts towards nothing: balances, charts, budget, export. A rejected tab stays visible to its creator and the admins with its reason; the creator is told, and can edit and resubmit or delete it.
  - Changing the amount, currency, payers or shares of an approved tab sends it back to waiting. Changing the description, category or payment method does not.
  - A personal tab is visible only to its creator, enforced by security rules. It counts towards their own budget and "spent by you", not squad totals.
- **UC-22 Edit / delete tab:** the creator can edit everything; leads can delete any tab (soft delete, shown in activity). Unticking a participant while in Custom % mode resets the split to Equal with a visible notice.
- **UC-23 Adventure page:** banner header with the tab list as a sheet that scrolls up over it; tabs grouped by day, newest first; each row shows the category and amount; the description and the viewer's own share; the pictures of people sharing (first 4 then "+N", the viewer first) and the payment emoji; and, for admins on a waiting tab, Approve and Reject. TalkBack reads "Shared by Ari, Cara and 3 others". Tapping opens tab details (payers with how they paid, shares, map pin).

### 5.8 Split report (bottom tab: Split)

- **UC-24** Defaults to the **active adventure** if there is one, otherwise **Overall** (the user's spend across all adventures, tap an adventure to drill in).
- **UC-25 Adventure split:**
  - **Top card:** "₹14,231 spent by you" (your share, with personal tabs), then "You're owed ₹1,240" / "You owe ₹560" / "All square 🎉", then the budget widget. A "•••" menu holds Export and show in the trip currency. "N tabs waiting, not counted" sits under it and opens the tab list.
  - **Spend by category:** total spend, and a coloured bar (no graph uses chartreuse, which is kept for the primary button) of the top 3 categories plus Other, with percentages that add up to 100 and a 2×2 legend. Every number is also in text.
  - **Who pays whom** (minimum transfers), with pictures: the first 4, then View all. Only rows the viewer can act on have an arrow, which opens Mark as settled. Settled: "Everyone is square 🎉".
  - **See detailed breakdown** expands on the same page: balances with pictures (members and pals), Payments recorded with Undo, all categories, and a bar chart by day.
  - **Other states:** no tabs (top card and Open adventure); only waiting tabs ("2 tabs waiting for approval", opening the tab list); only personal tabs (your own spend by category and day, seen only by you, then Open adventure); rates missing (a note). "Days left" shows only during the trip.
- **Update rates:** a small button on Split, the tab list and Add tab, wherever another currency is involved, fetches the latest rates (online only). The server asks the provider at most once an hour. A tab keeps its own rate day, so this fills in what's missing and doesn't change converted totals.
- **UC-26** All amounts appear in the **viewer's profile currency**, converted using each tab's stored FX rate date (§9.1); the "•••" menu shows the base-currency figures.
- **UC-26a Mark as settled:** next to each suggested transfer, **Mark as settled** records that one person paid another outside the app (no money moves). Amount defaults to the suggested transfer and can be lowered for a partial payment. Either member in the transfer can record it; for a pal's transfer, the member involved or any lead records it. The other member gets a notification. Either party or a lead can undo it, and the undo appears in the activity log. Recording works offline and syncs like a tab.
- **UC-27 Export:** PDF and Excel of the adventure split (summary, transfers, full tab list), shared via the Android share sheet. A minor's export never includes location.

### 5.9 Profile (bottom tab: You)

- **UC-28** Character, name, optional description, profile currency, notification and location toggles. Everyone has a character: one of the 47 in `assets/characters/`, always on opaque white. A new account gets a default worked out from its ID, and Needs you offers to change it ("We have selected your awesome Avatar", with Change and Keep). Uploading your own picture is next phase.
- **UC-28a Picture beside every name:** wherever a person is listed or named on a screen, their picture is beside it: Home greeting, join cards, invites, squad, Activity, invite link screen, Add tab's lists, tab details, Who pays whom, balances, Payments recorded and the settle sheet. Not in pop-up messages, confirmation dialogs, push notifications or exports. A deleted user gets a plain grey icon; a neutral circle shows while loading. TalkBack reads the name, not the character.
- **UC-29 Privacy centre:** download my data (JSON), correct my data, delete my account, nominate a person, raise a concern (grievance contact; hidden in the app for the pilot by owner's decision, 2026-10-31, and in the privacy notice meanwhile), withdraw individual consents. For parents: **Linked children** (§7).

### 5.10 Offline & sync

- **UC-30** The app works fully offline after first sign-in: browse adventures, add/edit tabs.
- **UC-31** When the device is offline, Roamio switches Firestore to offline mode and shows a card saying changes are kept on the phone. A short blip isn't offline: it takes three failed checks in a row. When connectivity returns, Roamio re-enables the network and uploads queued writes by itself, showing "Synced ✓" or the error with Try again. There is no Sync button to press while connected (owner, 2026-10-31).
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
- Only approved tabs count towards balances. Personal tabs have no effect: the one person's net is 0.
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
| Minimise data | No phone number or contacts. Pals are a nickname and a character only. No Phase 1 screen uploads a picture. |
| Rights (§11–14) | Access/export, correction, erasure, nomination, grievance — all in the Privacy centre. Grievances acknowledged within 7 days. |
| Erasure | Account deletion removes profile, budgets and tokens within 30 days; tabs keep a "Deleted user" placeholder so balances stay correct. |
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
- **Unsplash's API terms require photos to stay on Unsplash's CDN**, so instead of re-hosting, Roamio stores Unsplash's link with resize and compression parameters (1600 px, WebP, quality 80). As soon as someone has a current or upcoming trip and a connection, the app saves its banner on the phone (the device's cache of that link), so it still shows while travelling. Android can clear this cache if the phone runs low on storage; the card then shows the flag until the next connection.
- The photographer is credited on the banner, bottom-left on Home's adventure card, with a link to their Unsplash page.
- If nothing is found or Unsplash is unreachable, a gradient banner with the flag emoji is shown and the lookup is tried again later.

### 9.3 Weather
- Open-Meteo, cached 30 minutes; hidden on failure.

---

## 10. Photos

- **Phase 1 uploads no pictures** (owner, 2026-10-31). Characters and the 10 destination photos ship in the app; banners come from Unsplash (§9.2); Scan bill reads on the phone and keeps nothing.
- **Next phase:** own display pictures, banners and tab photos come back, behind the switches in `app/lib/core/config/phase2.dart`. Every photo is then compressed **on device before upload**: longest side ≤ 1600 px, WebP quality 80, EXIF removed, ≤ 400 KB from a 12 MB photo. Storage rules reject files > 1 MB or not of type `image/webp`. Max 4 photos per tab; uploads queue offline and retry with backoff.

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
3. **Journey C – Tabs:** add a ₹ tab with 2 payers and custom % including a pal; add a € tab; an admin approves them; split report is correct in the viewer's profile currency; balances sum to 0; marking every suggested transfer as settled shows "All square 🎉" for everyone.
4. **Journey D – Offline:** in airplane mode add 3 tabs → reconnect → Sync → all squad members see them, waiting; an admin approves them.
5. **Journey E – Minor:** 16-year-old signs up → parent consents by email link → child joins an adventure; location tagging unavailable. Decline path deletes the account.
6. **Journey F – Privacy:** budget alert at 80% reaches only its owner; data export and account deletion complete.
7. All CI checks green; APK published on GitHub Releases; update popup appears on the previous version.
8. A leader with no co-lead, a rejected and resubmitted tab, and a personal tab each work end to end, with no dead end.
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
8. **Pilot scope (2026-10-30):** the Android pilot asks **no date of birth** and refuses no one; the sign-up tick reads "I'm 18 or older and I've read the privacy notice" and is recorded (`adultDeclared`). **Nominate a person** is by writing to the grievance officer. Under-18 accounts (§7) and in-app nomination are built but switched off until a DPDP-compliant version in Phase 2 (`app/lib/core/config/phase2.dart`, `docs/ROADMAP.md`). Supersedes item 6 for the pilot.
9. **Pilot redesign (2026-10-31):** tab approval, personal tabs, payment method, pal characters, a picture beside every name, the budget widget, and the Split and Home redesigns, as written in §5. Uploading your own pictures, including tab photos, moves to the next phase; `docs/ROADMAP.md`.

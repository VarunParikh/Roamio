# Roamio

[![CI](https://github.com/VarunParikh/Roamio/actions/workflows/ci.yml/badge.svg)](https://github.com/VarunParikh/Roamio/actions/workflows/ci.yml)
![Platform](https://img.shields.io/badge/Platform-Android_(pilot)-3DDC84)
![App](https://img.shields.io/badge/App-Flutter-02569B)
![Backend](https://img.shields.io/badge/Backend-Firebase_(asia--south1)-FFA000)
![Built with](https://img.shields.io/badge/Built_with-Claude_Code-orange)

**Split bills. Not friendships.**
*Instant peer splits. Zero awkward math.*

Roamio is a travel partner app for solo, couple and group travellers. Create an adventure, invite your squad with a link, log tabs (expenses) in any currency, and see who owes whom. It works offline, counts friends who don't have the app, and warns you privately when you near your own budget.

> **Roamio moves no money.** It records what people paid and owe. Settling up happens outside the app.

> **Status:** Android pilot build. [`v1.0.1`](https://github.com/VarunParikh/Roamio/releases/tag/v1.0.1) is the latest release, and the pilot with testers hasn't started. See [Status at a glance](#status-at-a-glance).

## Reviewer's map

| If you want to… | Open |
|---|---|
| **Run it** | [Setup](#setup), or the [pilot guide](docs/epics/roamio/release/pilot-guide.md) to install the APK |
| **Know what it is and why** | [Why Roamio exists](#why-roamio-exists), [What stands out](#what-stands-out), the [product vision](docs/core/product-vision.md) (the owner's brief), the [PRD](docs/epics/roamio/requirements/product-spec.md) |
| **See the business side** | [Pilot targets](#pilot-targets), [Ways Roamio could make money](#ways-roamio-could-make-money), [Roadmap](#roadmap) |
| **Understand the design** | [How it works](#how-it-works), [architecture](docs/epics/roamio/design/architecture.md), [data model](docs/epics/roamio/design/data-model.md), [ADRs](docs/epics/roamio/design/adr/README.md) |
| **Check privacy and honesty** | [Known limitations](docs/epics/roamio/release/known-limitations.md), [privacy notice](docs/epics/roamio/release/privacy-notice.md), [security review](docs/epics/roamio/verify/reviews/security-2026-10.md) |
| **Trace requirements to tests** | [User stories](docs/epics/roamio/requirements/user-stories.md), [test plan](docs/epics/roamio/verify/test-plan.md) |
| **Follow the decisions** | [Conflicts log](docs/core/open-conflicts.md), [approval register](docs/core/approval-register.md), [roadmap](docs/core/roadmap.md) |
| **Release it** | [Release checklist](docs/epics/roamio/release/release-checklist.md), [RELEASING.md](docs/RELEASING.md) |
| **Continue the work** | [`CLAUDE.md`](CLAUDE.md), [task list](tasks/todo.md), [handover](tasks/HANDOVER.md) |

## Why Roamio exists

Shared trips make money awkward: several currencies, several people paying, friends without the app, poor connections, and a spreadsheet at the end. Roamio aims to end the trip with a split everyone agrees with, and without that spreadsheet.

This is the owner's premise. It hasn't been tested with users, and the pilot is how it gets tested.

## What stands out

- **A budget only you can see:** a private limit for the trip, with alerts at 80% and 100%. Security rules enforce it, so it isn't just hidden on screen.
- **Nothing counts until it's approved:** a squad lead checks each shared tab before it touches anyone's balance.
- **Friends without the app still count:** a pal has a nickname, a character and their own balance, with no real name, phone number or email.
- **Scan the bill, check it, save:** the phone reads the bill and fills in the details for you to confirm, and nothing is uploaded.
- **Keep logging with no signal:** see [Offline mode](#offline-mode).
- **Totals that stay put:** each tab keeps its own day's exchange rate, so old totals don't change.

These haven't been compared hands-on with other expense-splitting apps, so they aren't claims to be unique.

## Status at a glance

As of 2026-11-01.

| Area | Position |
|---|---|
| App tests | 928 pass |
| Journeys on emulators | 8 of 8 pass, plus 2 bill-reading tests |
| Backend tests | 330 pass |
| GitHub's checks | Green on each PR through #128 |
| Prod backend and website | Deployed |
| Test release on a real phone | Installs, and Google sign-in works (owner's report) |
| Double-recording fix and new icon | Passed on two real phones on a dev build, and `v0.1.0-rc2` installs over `rc1` on a real phone (owner's reports) |
| Pilot with testers | Not started |
| Bill-scan accuracy | Not measured on bills the fix wasn't built around |

Everything limited or unproven: **[known limitations](docs/epics/roamio/release/known-limitations.md)**. What's left: **[release checklist](docs/epics/roamio/release/release-checklist.md)**.

## What it does

- **Adventures and squads:** invite by link or code, promote co-leads, and add pals without the app.
- **Tabs:** any currency, several payers, equal or custom percentage splits, and how each person paid.
- **Approval:** admins approve shared tabs before they count. Personal tabs stay yours alone.
- **Split:** your spend, who pays whom in the fewest transfers, and spend by category and day.
- **Mark as settled:** record a payment in any currency.
- **Private budget:** only you can read it, with alerts at 80% and 100%.
- **Scan bill:** reads a bill on the phone and fills in what it trusts. You confirm it, and nothing is uploaded.
- **Offline:** add and edit while offline, and it syncs by itself.
- **Your data:** download it or delete your account from the Privacy centre.
- **Updates:** the app checks GitHub Releases and offers new versions.

Under-18 accounts, uploading your own pictures, Raise a concern and in-app Nominate are built but switched off for the pilot: see the [roadmap](docs/core/roadmap.md).

### Offline mode

After your first sign-in, your changes stay on the phone while you're offline and upload by themselves when you reconnect. There's no Sync button to press.

| Works offline | Needs a connection |
|---|---|
| Browsing your adventures | Approving tabs |
| Adding and editing tabs | Joining a squad and inviting |
| Marking payments as settled | Changing squad roles |

## Pilot targets

These are proposed goals, not results, because the pilot hasn't run. The criteria for finishing Phase 1 are separate, in [spec §15](docs/epics/roamio/requirements/product-spec.md#15-success-criteria-phase-1-is-done-when).

| Target | KPI | What it measures | Where the number comes from |
|---|---|---|---|
| 70%+ | Trips settled | Trips that reach All square within 14 days of ending | Firestore |
| 80%+ | Squads activated | Squads with 3+ members and a first tab within 48 hours | Firestore |
| 60%+ | Logged on the go | Trip days with at least one tab added | Firestore |
| 90%+ | Splits agreed | Travellers who say the final split felt fair | Feedback form |

The app has no analytics events, and neither the Firestore report nor the feedback form exists yet.

## Ways Roamio could make money

These are options only. Nothing is decided, and no pricing is set.

- **Squad Pass:** a one-off payment per trip that unlocks extras for the whole squad, such as richer reports and custom banners.
- **Roamio Plus:** a yearly plan for frequent travellers, with spending insights across all their trips.
- **Activity bookings:** commission from partners when travellers book through the planned Explore page.
- **Travel money partners:** referral fees from forex card and payment partners, alongside planned in-app payments.

## How it works

```mermaid
flowchart LR
  App["Flutter app on Android"] <--> FS["Firestore and security rules"]
  App --> Auth["Firebase Auth"]
  App --> Fn["Cloud Functions"]
  FS --> Fn
  Fn --> Rates["Exchange rates"]
  Fn --> Banners["Unsplash banners"]
  App --> Kit["ML Kit, on the phone"]
  App --> GH["GitHub Releases"]
```

- **Money** is integer minor units, and percentages are basis points. Balances always sum to exactly zero.
- **Security rules** are the privacy boundary, with allow and deny tests for every rule.
- **Cloud Functions** handle anything that must be trusted, such as joining and role changes.
- **All Firebase resources** are in asia-south1 (Mumbai).

More diagrams: [architecture](docs/epics/roamio/design/architecture.md).

## Setup

Full machine setup (Flutter through FVM, both JDKs, Android SDK, emulator, Firebase CLI) is in **[docs/SETUP.md](docs/SETUP.md)**.

| Part | Folder | Needs |
|---|---|---|
| Android app | `app/` | Flutter pinned in `app/.fvmrc`, JDK 17 |
| Backend | `firebase/` | Node, Firebase CLI, JDK 21 for the emulators |

`google-services.json` is never committed. Download it as SETUP.md describes.

```bash
cd app && fvm flutter run --flavor dev
```

## Tests

App (the same checks as CI):

```bash
cd app && fvm dart format --set-exit-if-changed . && fvm flutter analyze && fvm flutter test
```

Backend (rules and functions, against emulators):

```bash
cd firebase && JAVA_HOME=/opt/homebrew/opt/openjdk@21 npm test
```

Journeys (real app on an Android emulator, against Firebase emulators):

```bash
JAVA_HOME=/opt/homebrew/opt/openjdk@21 PATH=/opt/homebrew/opt/openjdk@21/bin:$PATH ./tool/e2e.sh integration_test/journeys_test.dart
```

CI runs the app and backend checks on every pull request, and the journeys nightly on `main`.

## Releases

A release is a signed APK on [GitHub Releases](https://github.com/VarunParikh/Roamio/releases). Pushing a tag such as `v1.2.3` starts a build that waits for the owner's approval. A tag such as `v1.2.3-rc1` becomes a pre-release, which the app's update popup ignores. Steps: [RELEASING.md](docs/RELEASING.md).

## Repository map

| Path | Contents |
|---|---|
| `app/` | Flutter app: `lib/core/`, `lib/features/<feature>/{data,domain,ui}`, tests and journeys |
| `firebase/` | Security rules, Cloud Functions, Hosting pages and their tests |
| `docs/core/` | Vision, constitution, strategy, platforms, roadmap, conflicts log, approval register, glossary |
| `docs/epics/roamio/` | Discovery, requirements (BRD, PRD, user stories), design, verification and release |
| `docs/inputs/` | The owner's original brief |
| `docs/SETUP.md`, `RELEASING.md`, `REMOTE_CONFIG.md` | How-to guides |
| `design/` | [DESIGN.md](design/DESIGN.md), reference screens and the app icon |
| `data/` | Countries, currencies and expense categories |
| `tasks/` | Plan, task list, handover, screen-state checklist |
| `tool/` | `e2e.sh` journey runner |
| `.github/workflows/` | CI, nightly journeys and release |

## Roadmap

**Phase 1:** Android pilot with 10 users.

**Phase 2:** everything planned next is grouped here for now (owner, 2026-11-01), and plans may change after the pilot.

- **More ways in:** iPhone app, Sign in with Apple, web app and more languages.
- **Pay and plan:** paying your squad inside the app, and exploring activities nearby.
- **Your own pictures:** your own display picture and trip banners, and photos and bills saved on tabs.
- **Smarter squads:** flags for duplicate tabs, games and rewards, and accounts for ages 13–17 with a parent's consent.

The [detailed roadmap](docs/core/roadmap.md) and the spec still split these up: iOS and Sign in with Apple are in Phase 3, and some others aren't planned yet. See C12 in the [conflicts log](docs/core/open-conflicts.md).

## Known limitations (short version)

- **Scan bill accuracy isn't measured,** and a finished scan coming back into the app is unproven.
- **Android only, English only, sideloaded,** so Play Protect may warn on install.
- **The privacy notice names the owner with no email address** during the pilot. It needs review before any wider launch.
- **Some place names and shop names read oddly,** with fixes planned for phase 2.

The full list: [known limitations](docs/epics/roamio/release/known-limitations.md).

## Data and secrets

- **Secrets:** `google-services.json`, keystores and `.env` files are never committed. Release secrets live in a GitHub environment that needs the owner's approval.
- **Personal data:** see the [privacy notice](docs/epics/roamio/release/privacy-notice.md).
- **Licence:** MIT; see [LICENSE](LICENSE).

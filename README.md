# Roamio

[![CI](https://github.com/VarunParikh/Roamio/actions/workflows/ci.yml/badge.svg)](https://github.com/VarunParikh/Roamio/actions/workflows/ci.yml)

**Split bills. Not friendships.**
*Instant peer splits. Zero awkward math.*

Roamio is a travel partner app for solo, couple and group travellers. Create an adventure, invite your squad with a link, log tabs (expenses) in any currency with photos and receipts, and see who owes whom, online or offline.

> **Status:** Phase 1 (Android pilot) in development. See the [task list](tasks/todo.md) for progress.

## Documents

| Doc | What it is |
|---|---|
| [docs/SPEC.md](docs/SPEC.md) | Approved product + technical specification |
| [tasks/plan.md](tasks/plan.md) | Implementation plan, phases, risks |
| [tasks/todo.md](tasks/todo.md) | Task list with acceptance criteria |
| [docs/SETUP.md](docs/SETUP.md) | Developer machine setup |
| [docs/DATA_MODEL.md](docs/DATA_MODEL.md) | Firestore collections, who can read/write them, Storage paths |
| [docs/PRIVACY_NOTICE.md](docs/PRIVACY_NOTICE.md) | Adult and child (parent) privacy notices, versioned |
| [docs/BREACH_RESPONSE.md](docs/BREACH_RESPONSE.md) | What to do if personal data leaks |
| [docs/adr/](docs/adr/) | Architecture decision records |
| [design/DESIGN.md](design/DESIGN.md) | Visual design system (+ reference screens in `design/`) |
| [data/](data/) | Countries/currencies and expense categories source data |
| [docs/vision/](docs/vision/) | Original product vision |

## Get started

Full machine setup (Flutter via FVM, both JDKs, Android SDK, emulator, Firebase CLI, projects and secrets) is in **[docs/SETUP.md](docs/SETUP.md)**. In short:

| Part | Folder | Needs |
|---|---|---|
| Android app | `app/` | Flutter pinned in `app/.fvmrc` (via FVM), JDK 17 |
| Backend (rules, Cloud Functions, Hosting pages) | `firebase/` | Node, Firebase CLI, JDK 21 for the emulators |

`google-services.json` is never committed; download it for the dev project as described in SETUP.md.

### Run the app

```bash
cd app && fvm flutter run --flavor dev
```

Uses the `roamio-dev-varun` project. To run against local emulators instead, see [SETUP.md → Running the app against local emulators](docs/SETUP.md#running-the-app-against-local-emulators).

### Test

App (format, analyze, tests — the same checks as CI):

```bash
cd app && fvm dart format --set-exit-if-changed . && fvm flutter analyze && fvm flutter test
```

Backend (security rules and Cloud Functions, against emulators; no cloud access):

```bash
cd firebase && JAVA_HOME=/opt/homebrew/opt/openjdk@21 npm test
```

CI ([`.github/workflows/ci.yml`](.github/workflows/ci.yml)) runs both on every pull request.

### Release

Pilot builds are Android APKs published on [GitHub Releases](https://github.com/VarunParikh/Roamio/releases). The planned flow (Task 42): pushing a tag `vX.Y.Z` builds a signed `prod` APK in CI and publishes a GitHub Release with notes. The app checks the latest release at most once a day and offers the update; Remote Config's `min_supported_version` can make an update required. Publishing a release, and deploying anything to the prod Firebase project, is always done by the owner.

## Tech

Flutter (Android first, then Web and iOS) · Firebase (Auth, Firestore, Storage, Functions, Remote Config, FCM) in asia-south1 · DPDP (India) compliant, including verifiable parental consent for users aged 13–17.

## Roadmap

1. **Phase 1:** Android pilot with 10 users
2. **Phase 2:** Web app
3. **Phase 3:** iOS app + Sign in with Apple

Later: in-app payments, an Explore page, gamification, duplicate-tab detection.

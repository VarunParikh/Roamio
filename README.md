# Roamio

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
| [design/DESIGN.md](design/DESIGN.md) | Visual design system (+ reference screens in `design/`) |
| [data/](data/) | Countries/currencies and expense categories source data |
| [docs/vision/](docs/vision/) | Original product vision |

## Tech

Flutter (Android first, then Web and iOS) · Firebase (Auth, Firestore, Storage, Functions, Remote Config, FCM) in asia-south1 · DPDP (India) compliant, including verifiable parental consent for users aged 13–17.

## Roadmap

1. **Phase 1:** Android pilot with 10 users
2. **Phase 2:** Web app
3. **Phase 3:** iOS app + Sign in with Apple

Later: in-app payments, an Explore page, gamification, duplicate-tab detection.

# Implementation Plan: Roamio Phase 1 (Android pilot)

Spec: [docs/epics/roamio/requirements/product-spec.md](../docs/epics/roamio/requirements/product-spec.md) (approved 2026-10-27) · Task list: [tasks/todo.md](todo.md)

## Overview

Build the Roamio Android app (Flutter) and its Firebase backend (asia-south1) so a 10-person pilot can run a whole trip: sign up (including under-18s with parental consent), create and join adventures, log multi-currency tabs with multiple payers and custom % splits, work offline and sync on demand, see and settle the split, and receive budget alerts — distributed as an APK through GitHub Releases.

## Architecture Decisions

- **Feature-first Flutter layout** (`lib/features/<feature>/{data,domain,ui}`). Domain code is pure Dart, so the riskiest logic (money, splits) is unit-tested without Firebase.
- **Money as integer minor units, percentages as basis points.** No floats anywhere in the money path (spec §6).
- **Server-side Cloud Functions for anything that must be trusted:** joining via invite, role changes, parental consent, budget alerts, FX rates, banners, account deletion. The client never grants itself a role.
- **Security rules are the privacy boundary**, not the UI. Every rule ships with allow and deny tests run against the emulator.
- **Offline via Firestore persistence + `disableNetwork()` / `enableNetwork()`.** When connectivity drops, the app goes offline on purpose; the Sync button re-enables the network. This reuses Firestore's queue instead of building our own (ADR-002, written in Task 9).
- **Two Firebase projects:** `roamio-dev` (emulators + manual testing) and `roamio-prod` (pilot). Prod config is injected by CI, never committed.
- **Invite links on Firebase Hosting** (`<project>.web.app/i/<code>`) with Android App Links; clipboard / manual code entry covers installs from the APK (Firebase Dynamic Links was shut down in 2025).
- **Riskiest work first:** split engine and security rules (Phase 1) come before any screens, and parental consent (Phase 2) comes before the features it gates.

## Phases

| Phase | Tasks | Delivers | Checkpoint |
|---|---|---|---|
| 0 Setup | 1–6 | Tools installed, repo on GitHub, Firebase projects, app + backend skeletons, CI | App runs on emulator; CI green |
| 1 Core logic | 7–9 | Money/FX, split engine, data model + security rules | 100% split-engine coverage; rules tests pass |
| 2 Identity | 10–13 | Sign in/up, age gate, parental consent, minor protections | Journey E |
| 3 Adventures & squad | 14–21 | Countries, create adventure, banner, invites, join, roles, pals, edit | Journeys A, B |
| 4 Tabs & splits | 22–31 | Photos, tabs (multi-payer, %), memories, OCR, adventure page, FX, split screen, settle, export | Journey C |
| 5 Budget, offline, profile | 32–38 | Budget alerts, offline sync, You page, privacy centre, weather, remote config, update popup | Journeys D, F |
| 6 Polish & ship | 39–44 | UX pass, docs, end-to-end tests, release pipeline, reviews, pilot | All success criteria in spec §15 |

The full task list with acceptance criteria and verification is in [todo.md](todo.md).

## Where you (the owner) are needed

These need your hands or your approval; everything else I run:

| Task | What you do |
|---|---|
| 1 | Approve ~5 GB of tool downloads; enter your Mac password for installers |
| 2 | Approve the first push to github.com/VarunParikh/Roamio |
| 3 | Create the Firebase projects and attach a billing card (I give click-by-click steps); create an Unsplash developer app |
| 11 | Choose an email-sending provider and set up its account |
| 40 | Choose the grievance contact email alias |
| 42 | Keep the release signing key safe (I generate it; you store a backup) |
| 44 | Invite the 10 pilot users and collect feedback |
| Every checkpoint | Try the build and approve before the next phase |

## Parallelization

After Phase 1, the contracts (data model, rules, split engine) are fixed. Then these can run in separate sessions if you want speed:
- Phase 2 (identity) and Tasks 14–16 (countries, create adventure, banner) touch different features.
- Tasks 26 (OCR), 31 (export) and 36 (weather) are independent leaf features.
- Docs (Task 40) can be written any time after Phase 2.

Must stay sequential: the security rules (Task 9 and later rule changes), Task 22 (image pipeline) before any photo feature, Task 33 (offline) after tabs exist.

## Risks and Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| Flutter / Android toolchain issues on a brand-new macOS + M5 | High (blocks everything) | Task 1 runs `flutter doctor` to green before anything else; use FVM to pin a known-good Flutter version |
| Split math bug causes wrong balances | High (trust) | Pure-Dart engine, TDD, property test that balances sum to 0, worked examples from the spec as fixtures |
| Private data leaked by a rules mistake (budgets, minors) | High (DPDP) | Default-deny rules; allow + deny tests for every path; security review in Task 43 |
| Manual-sync model surprises users (Firestore behaviour with `disableNetwork`) | Medium | Spike inside Task 33 first; fallback is automatic sync with the button as "sync now" |
| Parental consent emails land in spam | Medium (minors blocked) | Use a provider with domain authentication; "Resend" + change-email options; consent page also reachable by code |
| Sideloaded APK: Play Protect warnings, App Links not verified | Medium | Pilot instructions explain the warning; code-entry fallback for invites |
| Unsplash demo limit (50 requests/hour) | Low | Banners cached per country; pre-warm top 20; gradient fallback |
| OCR misreads receipts | Low | OCR only prefills; user confirms; feature flag to disable |
| Firebase costs | Low | Budget alert at ₹500/month; compressed photos; no polling |
| FX API outage | Low | Last known day's rates, marked on the tab |

## Definition of Done (every task)

Tests written and passing · `flutter analyze` and lint clean · behaviour checked on the emulator (or emulator suite for backend) · spec and docs updated if behaviour changed · committed on a branch with a clear message.

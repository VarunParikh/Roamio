# Roamio — rules for coding agents

Read [docs/epics/roamio/requirements/product-spec.md](docs/epics/roamio/requirements/product-spec.md) before changing behaviour; it is the source of truth. Pick up work from [tasks/todo.md](tasks/todo.md) in order and tick tasks off when their verification passes.

Documents follow the Zest layout: `docs/core/` is product-wide and `docs/epics/roamio/` is the work, indexed in [its README](docs/epics/roamio/README.md). Log disagreements between documents in [open-conflicts.md](docs/core/open-conflicts.md).

## Non-negotiables
- Money is integer minor units + ISO 4217 code; percentages are basis points. Never floats.
- Security rules are the privacy boundary. Every rule change ships with allow + deny tests.
- Write the failing test first for split-math, FX, rules and consent logic.
- Photos are compressed and EXIF-stripped on device before upload.
- No analytics/Crashlytics/location for under-18 accounts: check `privacyPolicyProvider` (`app/lib/core/privacy/privacy_policy.dart`) before any of them.
- One primary (chartreuse) button per screen; every empty/error/offline state has one next action.
- Visual style comes from `design/DESIGN.md`; the `design/*` screens are style references, not feature specs.

## Chores
Pushing, opening or merging PRs, updating PR branches, pulling data, test runs, test builds, wide searches, screenshots, docs upkeep, mechanical edits and log summaries go to a cheaper session: follow [.claude/skills/delegate-chores/SKILL.md](.claude/skills/delegate-chores/SKILL.md).

## Ask the owner first
New dependencies · data-model changes after first deploy · anything that adds Firebase cost · CI changes · pushing to GitHub · publishing a release.

## Never
Commit secrets, `google-services.json`, keystores or `.env` files · skip or delete failing tests · let the UI be the only guard on private data.

## Commands
- App: `cd app && fvm dart format --set-exit-if-changed . && fvm flutter analyze && fvm flutter test` (Flutter pinned in `app/.fvmrc`; builds need `JAVA_HOME=/opt/homebrew/opt/openjdk@17`)
- Run dev build: `cd app && fvm flutter run --flavor dev`
- Backend: `cd firebase && JAVA_HOME=/opt/homebrew/opt/openjdk@21 npm test` (emulators need Java 21; Flutter needs 17)
- Toolchain paths and setup: [docs/SETUP.md](docs/SETUP.md)

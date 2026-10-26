# Roamio — rules for coding agents

Read [docs/SPEC.md](docs/SPEC.md) before changing behaviour; it is the source of truth. Pick up work from [tasks/todo.md](tasks/todo.md) in order and tick tasks off when their verification passes.

## Non-negotiables
- Money is integer minor units + ISO 4217 code; percentages are basis points. Never floats.
- Security rules are the privacy boundary. Every rule change ships with allow + deny tests.
- Write the failing test first for split-math, FX, rules and consent logic.
- Photos are compressed and EXIF-stripped on device before upload.
- No analytics/Crashlytics/location for under-18 accounts.
- One primary (chartreuse) button per screen; every empty/error/offline state has one next action.
- Visual style comes from `design/DESIGN.md`; the `design/*` screens are style references, not feature specs.

## Ask the owner first
New dependencies · data-model changes after first deploy · anything that adds Firebase cost · CI changes · pushing to GitHub · publishing a release.

## Never
Commit secrets, `google-services.json`, keystores or `.env` files · skip or delete failing tests · let the UI be the only guard on private data.

## Commands
- App: `cd app && dart format --set-exit-if-changed . && flutter analyze && flutter test`
- Backend: `cd firebase && npm test`
- Toolchain paths and setup: [docs/SETUP.md](docs/SETUP.md)

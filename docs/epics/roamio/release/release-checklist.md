# Release Checklist: pilot

As of 2026-11-01. Ticks only what has evidence. How to release: [RELEASING.md](../../../RELEASING.md).

## Done
- [x] Prod backend and website deployed (functions and rules from `65382bd`, website from `247fb4b`)
- [x] Upload key created, secrets on GitHub, fingerprints on prod
- [x] `v0.1.0-rc1` built, signed with the upload key and published as a pre-release
- [x] It installs on a real phone, and Google sign-in works on prod (owner's report)
- [x] Nightly journeys and their routine turned back on
- [x] Pilot guide says adults only, with no date of birth
- [x] Placeholder email removed from the live privacy page
- [x] Double-recording fix live on dev and prod's server, and passed on two real phones on a dev build (owner's report)
- [x] New R. icon passed on a real phone on a dev build (owner's report)
- [x] MIT licence added
- [x] `v0.1.0-rc2`, with the double-recording fix and new icon, installed over `rc1` on a real phone and worked (owner's report)

## Still to do before inviting testers
- [ ] Second copy of the upload key, on USB
- [ ] Check prod's first scheduled exchange-rate run
- [ ] Feedback form created, with its link in the invite message
- [ ] Owner's approvals: see the [approval register](../../../core/approval-register.md)
- [ ] Bump the version, write notes and release `v1.0.0`, if the owner wants that for the pilot
- [x] `v1.0.0` published; the update popup appeared on a real phone over `rc2`, and installing from the GitHub release page kept the app working (owner's report)
- [x] Download update opening the release page, then downloading and installing, on a real phone on a one-off dev build (owner's report)
- [ ] Release `v1.0.1`, so that testers get the new button

## Spec §15 success criteria

| # | Criterion | Position |
|---|---|---|
| 1–6 | Journeys A to F | Pass on the emulators (`ad2cde0`). Real-device coverage is partial: see `tasks/HANDOVER.md`. |
| 7 | CI green, APK on GitHub Releases, update popup on the previous version | CI and pre-release done; popup not seen |
| 8 | Leader with no co-lead, rejected tab, personal tab | Journey G and widget tests; checked on devices 2026-11-01 for part of it |
| 9 | 10 users complete a trip | Not started |

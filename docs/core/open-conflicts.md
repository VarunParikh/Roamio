# Open Conflicts Log

Places where documents disagree, or where a document disagrees with what was built. Started 2026-11-01. Format: ID · conflict · sources · resolution · status. Precedence is in the [constitution](constitution.md).

| ID | Conflict | Sources | Resolution | Status |
|---|---|---|---|---|
| C1 | Brief asks for Apple sign-in; Phase 1 has none | Vision vs spec §1.2 | Phase 3 | Decided (spec) |
| C2 | Brief has photo uploads, banners and 4 memories per tab; the pilot uploads no pictures | Vision vs spec §10 | Next phase; code kept behind switches | Decided (owner, 2026-10-31) |
| C3 | UC-3 and UC-4 ask for a date of birth and allow ages 13 and over; the pilot asks none and is 18 or over only | Spec §5.1 vs §17 item 8 | §17 item 8 wins for the pilot. UC text is left as the Phase 2 behaviour. | Decided (owner, 2026-10-30); wording **open** |
| C4 | Journey E is a success criterion, but under-18 screens are off in the pilot | Spec §15 vs §17 item 8 | Journey E still runs with the features switched on, so that code stays tested | Decided |
| C5 | Spec and privacy notice expect a grievance contact; the pilot publishes no email and names the owner | Spec §8 and §17 item 3 vs privacy notice | Owner's decision for a small pilot. Get it reviewed before any wider launch. | Decided (owner, 2026-11-01); **review owed** |
| C6 | "Sync" described as a button; since 2026-10-31 sync happens by itself | ADR-002, pilot guide, Journey D wording, Task 33 title vs spec UC-31 | ADR-002 and pilot guide corrected 2026-11-01. Spec §15 and Task 33 still say Sync. | Partly fixed; **open** |
| C7 | Spec's deploy command named project `roamio-prod`; the real one is `roamio-prod-varun` | Spec §3 vs `.firebaserc` | Spec corrected | Fixed 2026-11-01 |
| C8 | Setup doc said dev was on the free plan with no Storage; dev is on Blaze | `SETUP.md` vs live project | Setup doc corrected | Fixed 2026-11-01 |
| C9 | Owner is happy with the release, but Task 33, Task 44 and every checkpoint are unticked in the task list | Owner, 2026-11-01 vs `tasks/todo.md` | Task 42 ticked 2026-11-01, as its release and real-phone install passed. The owner decides on the rest. See the [approval register](approval-register.md). | **Open** |
| C10 | Task 44 and spec §15 expect `v1.0.0` and a 10-person pilot; the only release is the pre-release `v0.1.0-rc1` | Spec §15 vs GitHub Releases | The owner decides when to release `v1.0.0` | **Open** |
| C11 | `docs/RELEASING.md` asks for two copies of the upload key; there's one cloud copy so far, and Apple Passwords can't hold the file | `RELEASING.md` vs owner, 2026-11-01 | Owner to add a USB copy | **Open** |

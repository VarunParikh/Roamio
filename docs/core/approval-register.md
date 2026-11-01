# Approval Register

One place that records what the owner has approved, and when. Only the owner approves. Started 2026-11-01, using only approvals that are written down elsewhere. If an approval isn't recorded, it's listed as not recorded rather than assumed.

## Documents

| Document | Path | Status |
|---|---|---|
| Product spec (PRD) | `docs/epics/roamio/requirements/product-spec.md` | **Approved** 2026-10-27, with later dated owner decisions inside it |
| ADR-001, ADR-002 | `docs/epics/roamio/design/adr/` | Accepted 2026-10-29. ADR-002 later changed by the owner's decision on UC-31. |
| Privacy notice | `docs/epics/roamio/release/privacy-notice.md` | Version 2026-10, revised 2026-11-01 by the owner's decision on the email. No lawyer's review yet. |
| Vision | `docs/core/product-vision.md` | The owner's own brief |
| Constitution, strategy, platforms, glossary, BRD, user stories, architecture, test plan, risk register, known limitations, release checklist | `docs/core/`, `docs/epics/roamio/` | **Approved** by the owner, 2026-11-01 |

## Checkpoints

From `tasks/todo.md`. None is ticked there, and no owner approval is recorded against any of them.

| Checkpoint | Status |
|---|---|
| 0 Skeleton, 1 Core logic, 2 Identity, 3 Adventures, 4 Tabs, 5 Budget and offline, 7 Redesign, 6 Ship | Not recorded |

## Owner decisions on the release (2026-11-01)

| Decision | Owner's words or action |
|---|---|
| Merged #120, #121, #122, #123, #124, #125 | Named each PR |
| Deployed prod | "Yes, deploy prod" |
| Redeployed prod's website | "Redeploy website" |
| Test release `v0.1.0-rc1` | "Start test release", and approved the run on GitHub |
| Installed it, and Google sign-in worked on a real phone | "Both worked" (the owner's report) |
| App, logs, Crashlytics and budget checks | "All four look fine" (the owner's report) |
| The release, for now | "This is done. Happy with the release for now." |
| Junk shop names and odd place names | Phase 2 |
| No grievance email in the pilot | "Part of next phase and not the pilot" |
| Merged #126, #127, #128 and deployed the settlement rule and function to dev and prod | Named each PR; "Merge and deploy"; "Yes, deploy prod" |
| Double-recording fix and new icon, on the dev test build from `a84d824` | "All three passed" (the owner's report) |
| `v0.1.0-rc2` installed over `rc1` on a real phone | "Yes, it worked" (the owner's report) |
| Merged #129, #130, #131, and published `v1.0.0` | Named each PR; "Merge and publish" |
| Popup appeared on `v1.0.0`, and its direct download stuck; installing from the release page worked | The owner's report |
| New button on a one-off dev build | "It worked" (the owner's report) |
| MIT licence, GitHub description, approving the draft documents | "Approved for these" |

"Happy with the release for now" is recorded as written. It hasn't been treated as ticking the checkpoints above or as approving `v1.0.0`. Approving the documents doesn't tick the checkpoints either.

## Rules
- A merge needs the owner to name the PR number. Approval for one isn't approval for the next.
- A draft becomes approved only when the owner says so.

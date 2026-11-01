# Product Constitution: Roamio

Status: APPROVED (owner, 2026-11-01), written 2026-11-01 from rules already in force. It collects them and adds none. Sources: `CLAUDE.md`, [spec](../epics/roamio/requirements/product-spec.md) §6, §7, §8, §12 and §16, and [ADR-001](../epics/roamio/design/adr/ADR-001-firebase-backend.md).

When documents disagree, the higher one wins, and the conflict goes in the [conflicts log](open-conflicts.md):

1. Owner decisions recorded with a date
2. [Product spec (PRD)](../epics/roamio/requirements/product-spec.md)
3. This constitution
4. [Product vision](product-vision.md) (the original brief, which the spec has since refined)
5. [`design/DESIGN.md`](../../design/DESIGN.md) for look and feel. The `design/*` screens are style references, not feature specs.

## Part 1. Principles

| # | Principle | What it means in practice |
|---|---|---|
| P1 | **Money is exact** | Integer minor units plus an ISO 4217 code. Percentages are basis points. Never floats. A squad's balances always sum to exactly zero. |
| P2 | **Security rules are the privacy boundary** | The UI is never the only guard on private data. Every rule change ships with allow and deny tests. |
| P3 | **The server decides what must be trusted** | Joining, role changes, consent, budget alerts, rates and account deletion run in Cloud Functions. The client never grants itself a role. |
| P4 | **Roamio records payments and moves no money** | "Mark as settled" and "Paid with" are records only. There is no payment gateway. |
| P5 | **Works offline** | After first sign-in, tabs can be added and edited offline and sync by themselves. Actions that need a connection say why they're disabled. |
| P6 | **Collect little** | No phone numbers or contacts. A pal is a nickname and a character. The pilot uploads no pictures, and Scan bill reads on the phone and keeps nothing. |
| P7 | **Extra protection for under-18 accounts** | No analytics, Crashlytics or location. Check `privacyPolicyProvider` first. Anyone not confirmed as an adult is treated as a minor. |
| P8 | **No dead ends** | One primary (chartreuse) button per screen. Every empty, error and offline state has one next action. |
| P9 | **A scanned bill is a guess, and the person confirms it** | Scan bill only prefills. An empty amount is better than a wrong one. |

## Part 2. Build rules

**Always**
- Write the failing test first for split math, FX, rules and consent logic.
- Run format, analyze and tests before each commit.
- Update the spec when a decision changes.
- Compress photos and strip EXIF on the device before any upload.

**Ask the owner first**
New dependencies · data-model changes after first deploy · anything that adds Firebase cost · CI changes · pushing to GitHub · publishing a release.

**Never**
Commit secrets, `google-services.json`, keystores or `.env` files · skip or delete failing tests · let the UI be the only guard on private data.

## Part 3. Who decides

| Decision | Who |
|---|---|
| Product scope, merges (by PR number), deploys, releases, approvals | Owner |
| Signing key and its password | Owner only. They are never shared with an agent or pasted into a chat. |
| Implementation inside an approved spec section | Claude Code, with tests, for the owner's review |

## Part 4. Changes

A change to this document goes through a pull request the owner merges, with the reason recorded in the [approval register](approval-register.md).

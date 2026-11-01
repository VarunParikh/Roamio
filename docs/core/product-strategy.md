# Product Strategy: Roamio

Status: APPROVED (owner, 2026-11-01), written 2026-11-01 from the [vision](product-vision.md), [spec](../epics/roamio/requirements/product-spec.md) §1 and §15, and the [roadmap](roadmap.md). No market research has been done, so nothing here is backed by user data yet.

## 1. Purpose
Roamio is a travel partner app for young solo, couple and group travellers. It splits shared trip costs fairly, keeps a log of spending, and tells each traveller privately when they approach their own budget.

**Tagline:** Split bills. Not friendships. · **Sub-tagline:** Instant peer splits. Zero awkward math.

## 2. Problem (the owner's premise, not yet tested)
Shared trips create awkward money conversations: mixed currencies, several people paying, friends without the app, poor connections while travelling, and spreadsheets to work it all out at the end.

## 3. Users
- **Squad Leader or Co-squad Lead:** sets up the trip, invites the squad, approves tabs.
- **Member:** adds tabs, sees what they owe, keeps a private budget.
- **Pal:** travels with the squad without the app. A lead adds them by nickname, and they have their own balance.
- **Solo traveller:** logs personal spending and budget.

Under-18 travellers with a parent's consent are built but switched off until Phase 2.

## 4. Value proposition
- Fair splits across currencies, several payers and custom percentages, with balances that always sum to zero.
- A budget only you can see.
- Works offline while travelling.
- People without the app still count.

## 5. Goals and success measures
**Phase 1 goal:** a working Android app used by a 10-person pilot, distributed as an APK through GitHub Releases.

**Success looks like:** a squad creates an adventure, invites each other, logs tabs in mixed currencies, goes offline and syncs later, and ends the trip with a split everyone agrees with, without opening a spreadsheet.

The measurable criteria are in [spec §15](../epics/roamio/requirements/product-spec.md#15-success-criteria-phase-1-is-done-when). Where they stand: [release checklist](../epics/roamio/release/release-checklist.md).

## 6. Scope
**In Phase 1:** everything in spec §5. **Held back or later:** see the [roadmap](roadmap.md) and spec §1.2.

## 7. Delivery strategy
- **Sideloaded APK, not the Play Store.** Updates come from a check against GitHub Releases, signed with one upload key.
- **Riskiest work first:** split engine and security rules came before any screens.
- **Keep code, switch off screens:** features held back from the pilot stay built and tested behind `app/lib/core/config/phase2.dart`.

## 8. Main bets to check in the pilot
See the [assumptions and risk register](../epics/roamio/discovery/assumptions-and-risk-register.md).

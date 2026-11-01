# Business Requirements Document (BRD): Roamio

Status: APPROVED (owner, 2026-11-01), written 2026-11-01 from the [vision](../../../core/product-vision.md), [strategy](../../../core/product-strategy.md) and [spec](product-spec.md). It adds no requirements. The detail and acceptance criteria are in the spec, which wins if the two differ.

## 1. Purpose and background
The owner wants a travel app for solo, couple and group travellers that splits bills and logs trip spending. Phase 1 tests this with a 10-person pilot on Android.

## 2. Stakeholders

| Who | Role |
|---|---|
| Owner (Varun Parikh) | Product owner, grievance officer, runs the pilot |
| Pilot testers | About 10 adults on Android |
| Squads and pals | Travellers using the app, and friends counted without it |
| Data Protection Board of India | Regulator under the DPDP Act |

## 3. Scope
**In:** an Android app and its Firebase backend, distributed as an APK. **Out:** payments, web, iOS and the rest of [spec §1.2](product-spec.md#12-out-of-scope-for-phase-1).

## 4. Business requirements

| ID | Requirement | Spec |
|---|---|---|
| B1 | A group can create a trip and invite others with a link | UC-8 to UC-14 |
| B2 | Roles and friends without the app are supported | UC-15 to UC-18 |
| B3 | Expenses support any currency, several payers and custom splits | UC-21 to UC-23, §6 |
| B4 | Admins approve shared expenses before they count | UC-21a |
| B5 | Everyone sees who owes whom, and can record payments outside the app | UC-24 to UC-26a |
| B6 | Each person has a private budget with alerts | UC-19, UC-20 |
| B7 | The app works offline while travelling | UC-30 to UC-33 |
| B8 | Bills can be scanned on the phone to save typing | UC-21 |
| B9 | People can export a trip | UC-27 |
| B10 | Personal data is handled under India's DPDP Act | §7, §8, UC-29 |
| B11 | Testers get updates without an app store | UC-34 |

## 5. Business rules
- Roamio records payments and never moves money.
- All data stays in asia-south1 (Mumbai).
- The pilot is for adults only (owner, 2026-10-30).
- The pilot uploads no pictures (owner, 2026-10-31).

## 6. Constraints and dependencies
- One owner building with AI assistance.
- Firebase Blaze plan, with a ₹500 monthly budget alert.
- Outside services: see [platforms](../../../core/product-platforms.md).

## 7. Measuring success
[Spec §15](product-spec.md#15-success-criteria-phase-1-is-done-when). Current position: [release checklist](../release/release-checklist.md).

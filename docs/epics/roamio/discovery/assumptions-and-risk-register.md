# Assumptions and Risk Register: Roamio

Status: DRAFT, written 2026-11-01 from [`tasks/plan.md`](../../../../tasks/plan.md) and results that day. **No user research or market research was done.** The assumptions below are untested until the pilot runs.

## Assumptions

| ID | Assumption | How the pilot tests it |
|---|---|---|
| A1 | Groups will log tabs during a trip rather than afterwards | Tabs added per trip day |
| A2 | Admin approval feels helpful, not like a chore | Feedback form |
| A3 | Testers accept installing an APK and the Play Protect warning | Install drop-off |
| A4 | Scan bill is accurate enough to save time | 30–50 real bills, not yet measured |
| A5 | People need a budget that's private from the squad | Feedback form |

## Risks

| ID | Risk | Impact | Current position |
|---|---|---|---|
| R1 | Split math bug gives wrong balances | High | Pure-Dart engine, property test that balances sum to 0, journeys pass |
| R2 | Security rule leaks private data | High | Default-deny, allow and deny tests, [security review](../verify/reviews/security-2026-10.md) |
| R3 | Upload key lost, so nobody can update | High | One cloud copy; USB copy owed by the owner |
| R4 | Scan bill fills in a wrong amount that's saved unnoticed | Medium | The person confirms it; a doubted plain Total stays empty. A strong label that's wrong still gets through. |
| R5 | A finished scan doesn't come back into the app correctly | Medium | Never proven in a test. From the plugin's source it should work. |
| R6 | Privacy notice names the owner with no email address | Medium | Owner's decision for the pilot; review before wider launch |
| R7 | Crash reports turn out unreadable | Low | Symbols upload; no real crash checked yet |
| R8 | Geocoder's rate limit is hit | Low | Each place is looked up once per session; falls back to coordinates |
| R9 | Sideloading warnings or unverified App Links | Medium | Pilot guide explains; invite codes as a fallback |
| R10 | Firebase costs | Low | Budget alerts on both projects |
| R11 | Exchange-rate service is down | Low | Last available day's rates, marked on the tab |

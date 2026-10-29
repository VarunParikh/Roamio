# Data Model (Cloud Firestore)

Spec: [SPEC.md](SPEC.md) · Rules: [firebase/firestore.rules](../firebase/firestore.rules) · Tests: [firebase/test/rules/](../firebase/test/rules/)

Conventions:
- Money is `…Minor` (integer minor units) + `currency` (ISO 4217). Percentages are basis points (10000 = 100%).
- Dates without time are `yyyy-mm-dd` strings; instants are Firestore timestamps.
- **Server-only** fields are written by Cloud Functions (Admin SDK) and rejected by rules if a client sends them.
- "Active user" = signed in and `users/{uid}/private/account.ageStatus` is `adult` or `minor_active`. Any other status (none yet, `minor_pending`, `minor_frozen`, `adult_unconfirmed`) can only touch their own profile (spec §7).

## Collections

| Path | Fields | Read | Write |
|---|---|---|---|
| `users/{uid}` | `name`, `photoUrl`, `bio` | any active user; owner always | owner (only these fields) |
| `users/{uid}/private/account` | `dob`, `profileCurrency`, `consents{location,camera,notifications}`, `noticeVersion`, `createdAt`, `fcmTokens[]`; **server-only:** `ageStatus` (`adult` \| `minor_pending` \| `minor_active` \| `minor_frozen` (consent withdrawn) \| `adult_unconfirmed` (turned 18, notice not yet accepted)), `parentUid`, `adultNoticeAcceptedAt` | owner | owner creates (needs `dob`); owner updates `profileCurrency`, `consents`, `fcmTokens`; `dob` immutable |
| `users/{uid}/invites/{code}` | `code`, `addedAt` — invite codes this user has opened (Home → Invites) | owner | owner |
| `adventures/{aid}` | `name`, `description`, `countryCode`, `city`, `startDate`, `endDate`, `baseCurrency`, `bannerUrl`, `createdBy`, `createdAt`, `leaderUid`, `coLeadUids[]`, `memberUids[]` (active members incl. leads); **server-only:** `hasTabs`, `activeInviteCode` | members | create: active user as sole member + leader; update: leads, metadata only; `baseCurrency` locked once `hasTabs`; roles/membership server-only; no delete |
| `adventures/{aid}/members/{uid}` | `role` (`leader` \| `co_lead` \| `member`), `status` (`active` \| `left`), `joinedAt` | members | server-only |
| `adventures/{aid}/pals/{pid}` | `nickname`, `addedBy`, `status` (`active` \| `left`), `createdAt` | members | leads create/rename/mark left; no delete |
| `adventures/{aid}/tabs/{tid}` | `description`, `category`, `amountMinor`, `currency`, `date`, `fxDate`, `payers[{id, amountMinor}]`, `participants[]`, `percentBp` (map or null), `memories[]` (≤ 4 URLs), `location` (optional; adults only), `createdBy`, `createdAt`, `updatedAt`, `deleted` | members | members create as themselves; creator edits; leads soft-delete (`deleted: true`) only; no hard delete |
| `adventures/{aid}/settlements/{sid}` | `from`, `to`, `amountMinor`, `currency` (= base), `recordedBy`, `createdAt`, `undone`, `undoneBy` | members | a party to the transfer, or a lead when a pal is involved; undo only (`undone: true`) |
| `adventures/{aid}/budgets/{uid}` | `amountMinor`, `currency`, `updatedAt`; **server-only:** `alertsSent[]` | **owner only** | owner (must be a member) |
| `adventures/{aid}/activity/{id}` | `type`, `actorUid`, `subject`, `createdAt` | members | server-only |
| `invites/{code}` | 8 characters from `ABCDEFGHJKMNPQRSTUVWXYZ23456789`; `adventureId`, `adventureName`, `countryCode`, `startDate`, `endDate`, `leaderName` (first name), `createdBy`, `createdAt`, `expiresAt` (14 days), `revoked` | active users, single-document get only (no listing) | server-only |
| `fx_rates/{yyyy-mm-dd}` | `rates{CODE: "decimal string"}` (units per USD), `fetchedAt` | active users | server-only |
| `banners/{countryCode}` | `url` (Unsplash CDN link with resize params), `photographer`, `photographerUrl`, `unsplashUrl`, `fetchedAt` | active users | server-only |
| `parentalConsents/{childUid}` | `childUid`, `parentEmail` (lower-case), `relationship`, `status` (`requested` \| `granted` \| `declined` \| `expired` \| `withdrawn` \| `closed` \| `aged_out`), `requestedAt`, `remindersSent`, `requestsOn{day,count}`, `noticeVersion`; once decided: `parentUid`, `decidedAt`, `method`. `tokenHash` (SHA-256 of the emailed link token) exists only while open | the child or the parent | server-only |
| `mail/{id}` | `to`, `message{subject,text}`, `createdAt` — outbox in the Firebase "Trigger Email" extension format | nobody | server-only |
| `auditLog/{id}` | `actorUid`, `action`, `target`, `at` (kept 1 year) | nobody (console only) | server-only |

Anything not listed is denied.

## What rules can't check (enforced elsewhere)

Firestore rules can't loop over arrays, so these are checked by the app's split engine (`problemsWith`) and re-checked by a Cloud Function trigger in Task 23:
- payer amounts add up to the tab amount; percentages add up to 100%;
- every payer is a member and every participant is a member or pal.

Rules still bound the shapes: amount > 0 and an integer, 1–50 payers and participants, ≤ 4 memories.

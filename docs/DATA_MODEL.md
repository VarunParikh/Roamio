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
| `users/{uid}` | `name`, `photoUrl` (Phase 2 uploads; null in the pilot), `bio`, `characterId` (a character from the app; while missing, a default worked out from the account ID is shown) | one at a time (`get`, never list): the owner; an active user who shares or shared a squad with them (`profileReaders`); their consenting parent. A deleted profile reads as missing | owner (only these fields) |
| `profileReaders/{uid}` | `uids[]`: everyone who shares, or shared (Left), a squad with `uid`. Rebuilt by `profileReadersOnAdventure` when a squad's `memberUids`/`leftUids` change, updated at once by `joinAdventure`, deleted with the account | nobody (rules read it) | server-only |
| `users/{uid}/private/account` | `dob` (Phase 2; not asked in the pilot) **or** `adultDeclared: true` (the pilot's sign-up tick "I'm 18 or older"; the server then sets `ageStatus: adult`), `profileCurrency`, `consents{location,camera,notifications}`, `noticeVersion`, `createdAt`, `nominee` (optional `{name, email}` or null: who may use the person's privacy rights if they can't; adults only), `fcmTokens[]` (each phone's FCM installation ID; push is sent only while `consents.notifications` is true); **server-only:** `ageStatus` (`adult` \| `minor_pending` \| `minor_active` \| `minor_frozen` (consent withdrawn) \| `adult_unconfirmed` (turned 18, notice not yet accepted)), `parentUid`, `adultNoticeAcceptedAt` | owner | owner creates (with either `dob` or `adultDeclared: true`, never both); owner updates `profileCurrency`, `consents`, `fcmTokens`, `nominee` (adults; name 1–80 chars, valid email); `dob` immutable |
| `users/{uid}/invites/{code}` | `code`, `addedAt` — invite codes this user has opened (Home → Invites) | owner | owner |
| `users/{uid}/notifications/{id}` | `type` (`member_joined` \| `budget_alert` \| `tab_waiting` \| `tab_rejected`), `adventureId`, `adventureName`, `memberUid`, `memberName` (joins) or `threshold` (budget) or `tabId` (tabs; `tab_rejected` also has `description`), `createdAt`. Ids `{aid}_joined_{memberUid}` / `{aid}_budget_{threshold}` / `{aid}_tabwaiting_{tid}` / `{aid}_tabrejected_{tid}`. Lead cards (spec UC-14), cleared for every lead when one acts on them; `tab_waiting` goes to each admin but the tab's creator and is cleared for everyone once the tab stops waiting; `tab_rejected` goes to the creator and is cleared when the tab is no longer rejected (spec UC-21a) | owner | server-only; owner may delete (dismiss) |
| `adventures/{aid}` | `name`, `description`, `countryCode`, `city`, `startDate`, `endDate`, `baseCurrency`, `bannerUrl` (null = country photo; otherwise only a Firebase Storage link, never an outside URL), `createdBy`, `createdAt`, `leaderUid`, `coLeadUids[]`, `memberUids[]` (active members incl. leads); **server-only:** `hasTabs`, `activeInviteCode`, `archived`, `archivedAt` (set when the last member, the leader, leaves), `leftUids[]` (people kept as Left because they're on a tab; removed if they rejoin; lets their data download find it) | members | create: active user as sole member + leader; update: leads, metadata only; `baseCurrency` locked once `hasTabs`; roles/membership server-only; no delete |
| `adventures/{aid}/members/{uid}` | `role` (`leader` \| `co_lead` \| `member`), `status` (`active` \| `left`), `joinedAt` | members | server-only |
| `adventures/{aid}/pals/{pid}` | `nickname`, `characterId` (required), `addedBy`, `status` (`active` \| `left`), `createdAt` | members | leads create/edit/mark left; no delete |
| `adventures/{aid}/tabs/{tid}` | `status` (`waiting` \| `approved` \| `rejected` \| `personal`; never created `approved` unless the creator is the only admin), `decidedBy`, `decidedAt`, `rejectReason` (optional, up to 200 characters; only its creator and admins can read a rejected tab, and only its creator a personal one); each entry in `payers[]` also has `method` (`cash` \| `card` \| `upi` \| `cheque` \| `bank_transfer` \| `other`); `description`, `category`, `amountMinor`, `currency`, `date`, `fxDate` (the day of the exchange rates that convert it, saved when it's added: the latest rates day on or before `date`, at most 7 days earlier; kept on edits unless the date changes, so totals never shift), `payers[{id, amountMinor}]`, `participants[]`, `percentBp` (map or null), `memories[]` (≤ 4 of our own Firebase Storage links, never an outside URL), `location` (optional; adults only; exactly `{lat, lng}`, no address), `createdBy`, `createdAt`, `updatedAt`, `baseUpdatedAt` (optional; on an edit, the `updatedAt` of the version the editor started from, so the server can log `tab_edit_replaced`), `deleted`, `deletedBy` (the lead who deleted it; logged as `tab_deleted`) | members | members create as themselves; creator edits (but can't change `deleted`); leads soft-delete (`deleted: true`) only; no hard delete |
| `adventures/{aid}/settlements/{sid}` | `from`, `to` (members, pals, or someone who has left), `amountMinor`, `currency` (= base), `date` (yyyy-mm-dd, its rates convert it), `recordedBy`, `createdAt`, `undone`, `undoneBy` | members | a party to the transfer, or a lead when a pal is involved; undo only (`undone: true`) |
| `adventures/{aid}/budgets/{uid}` | `amountMinor`, `currency`, `updatedAt`; **server-only:** `alertsSent[]` (thresholds already alerted; cleared when the amount or currency changes). Measured against the owner's own share of non-deleted tabs, converted at each tab's day. Deleted when the member leaves, is removed, or deletes their account | **owner only** | owner (must be a member) |
| `adventures/{aid}/activity/{id}` | `type` (`member_joined` \| `member_removed` \| `member_left` \| `co_lead_added` \| `co_lead_removed` \| `leader_changed` \| `tab_rejected` \| `tab_deleted` \| `tab_edit_replaced` \| `settlement_recorded` \| `settlement_undone`), `actorUid`, `subject`, `createdAt`; `reason` on `tab_rejected` | members | server-only |
| `invites/{code}` | 8 characters from `ABCDEFGHJKMNPQRSTUVWXYZ23456789`; `adventureId`, `adventureName`, `countryCode`, `startDate`, `endDate`, `leaderName` (first name), `leaderUid`, `leaderCharacterId`, `createdBy`, `createdAt`, `expiresAt` (14 days), `revoked` | active users, single-document get only (no listing) | server-only |
| `fx_rates/{yyyy-mm-dd}` | `date` (same as the id, for "latest on or before" queries), `rates{CODE: "decimal string"}` (units per USD, exact text from the provider), `source`, `fetchedAt`. Written daily at 00:30 UTC by `dailyFxRates`; nothing is written when the provider is down | active users | server-only |
| `banners/{countryCode}` | `url` (Unsplash CDN link with resize params), `photographer`, `photographerUrl`, `unsplashUrl`, `fetchedAt` | active users | server-only |
| `parentalConsents/{childUid}` | `childUid`, `parentEmail` (lower-case), `relationship`, `status` (`requested` \| `granted` \| `declined` \| `expired` \| `withdrawn` \| `closed` \| `aged_out`), `requestedAt`, `remindersSent`, `requestsOn{day,count}`, `noticeVersion`; once decided: `parentUid`, `decidedAt`, `method`. `tokenHash` (SHA-256 of the emailed link token) exists only while open | the child or the parent | server-only |
| `mail/{id}` | `to`, `message{subject,text}`, `createdAt` (ms), `expiresAt` (timestamp, 30 days on; a Firestore TTL policy deletes the email then) — outbox in the Firebase "Trigger Email" extension format | nobody | server-only |
| `auditLog/{id}` | `actorUid`, `action` (`account_deleted`), `target`, `at` (kept 1 year) | nobody (console only) | server-only |

Anything not listed is denied.

## Data export (spec UC-29)

`exportMyData` (callable) builds a person's data on demand and stores nothing: the JSON (profile, private account, invites, notifications, and per adventure they are in or have left: role, tabs they added, paid or share, transfers they are part of, their own budget, activity about them; their consent record and linked children without `tokenHash`; audit entries about them), then their photos (profile photos and memories on tabs they added) as stored zips of at most 6 MB each, one call per part. A parent may pass `childUid` for a child whose consent is `granted`. Every JSON download writes `auditLog` `data_exported` (actor = caller, target = whose data). Adventures the person left while on a tab (`leftUids`) are included, with `role: "left"`.

## Storage (photos)

**Next phase:** no Phase 1 screen uploads a picture, and rules deny these paths until then.

Rules: [firebase/storage.rules](../firebase/storage.rules) · Tests: [firebase/test/rules/storage.test.ts](../firebase/test/rules/storage.test.ts). Every file is WebP, at most 1 MB, compressed and EXIF-stripped on the device, and written once (no overwrite or delete from the app). The rules read Firestore to decide access, so the first deploy must let Storage read Firestore (the CLI offers to grant this).

| Path | Read | Create |
|---|---|---|
| `adventures/{aid}/tabs/{tid}/{id}.webp` | members | the tab's creator (the link goes into the tab's `memories`) |
| `adventures/{aid}/banner/{id}.webp` | members | leads (the link goes into `bannerUrl`) |
| `users/{uid}/avatar/{id}.webp` | active users; owner always | owner |

Photos added offline wait in an on-device queue (`app/lib/core/images/upload_queue.dart`) that survives restarts and retries with backoff (5 s doubling to 30 min); the link is written to the document once the upload succeeds.

## What rules can't check (enforced elsewhere)

Firestore rules can't loop over arrays, so these are checked by the app's split engine (`problemsWith`) and re-checked by the `checkTab` Cloud Function trigger, which soft-deletes a failing tab and logs `tab_rejected` (it also sets the adventure's `hasTabs`):
- payer amounts add up to the tab amount; percentages add up to 100%;
- every payer is a member and every participant is a member or pal (only checked for people newly put on a tab, so someone who has left stays on their old tabs).

Rules still bound the shapes: amount an integer from 1 to 10,000,000,000 (the app's largest tab in a 3-decimal currency; transfers too), 1–50 payers and participants, ≤ 4 memories.

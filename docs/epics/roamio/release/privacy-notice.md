# Roamio privacy notice

Spec: [SPEC.md §7, §8](../requirements/product-spec.md) · Data: [DATA_MODEL.md](../design/data-model.md) · Published copy: [`firebase/hosting/privacy/index.html`](../../../../firebase/hosting/privacy/index.html) (served at `https://<project-id>.web.app/privacy/`)

There are two notices:

| Notice | Who reads it | Version | Recorded in code as |
|---|---|---|---|
| [Adult notice](#adult-notice) | Everyone 18 or older, at sign-up and when a teen turns 18 | **2026-10** | `privacyNoticeVersion` (`app/lib/features/auth/data/auth_service.dart`), `ADULT_NOTICE_VERSION` (`firebase/functions/src/auth/birthdays.ts`) |
| [Child notice](#child-notice-for-parents-and-guardians) | The parent or guardian of a 13–17-year-old, before they say yes | **2026-10** | `CHILD_NOTICE_VERSION` (`firebase/functions/src/consent/consent.ts`) |

**Changing a notice:** edit it here and in the Hosting page, bump the version in the files above (in the same PR), and add a line to the [change log](#change-log). The version is stored with each person's acceptance and each parent's consent, so we can always tell which wording someone agreed to.

> **Next phase:** the pilot publishes no grievance email (owner, 2026-11-01). The owner chooses a dedicated address in the next phase. Add it here, in the Hosting page, and in `grievanceEmail` (`app/lib/features/profile/ui/privacy_centre.dart`), which stays hidden behind `grievanceEnabledProvider`.

*This notice follows the Digital Personal Data Protection Act, 2023 and the DPDP Rules, 2025 as an engineering checklist. It is not legal advice; have a lawyer review it before any public launch.*

---

## Adult notice

Version 2026-10 · For people aged 18 and over

### Who we are
Roamio is an app for splitting travel costs with friends. Roamio is run by Varun Parikh, who decides how your data is used (the "Data Fiduciary" under India's DPDP Act). The pilot is small (about 10 people) and the app is not sold or used for advertising.

### What we keep, and why

| What | Why |
|---|---|
| Your name, email and how you sign in (Google or email + password) | To create your account and let you sign in. |
| That you confirmed you're 18 or older (the sign-up tick) | Roamio's pilot is for adults. We don't ask your date of birth; we record that you confirmed your age, and when. |
| The character you choose as your picture, and a short description (both optional) | So your squad recognises you. |
| Your profile currency | To show amounts in money you know. |
| Your choices for notifications, location and camera | So the app only does what you allowed. |
| A code that lets us send notifications to your phone | For alerts when friends join and when you near your budget. Removed when a phone stops using it. |
| Your adventures, squads, roles, tabs (expenses), who paid and how (cash, card and so on), who shares, whether a tab was approved, and transfers you marked as settled | That's what the app is for: splitting costs fairly. Your squad sees these, except personal tabs, which only you can see. |
| Nicknames of "pals" (people on a trip without the app), and the character chosen for them | To split costs with them. Nothing else about them. |
| Your personal budget for an adventure | To warn you privately at 80% and 100%. **Only you can see it.** |
| Where a tab happened, if you turn Location on and add it | To remember the spot. Stored as a map point only, no address. Your squad can see it. |
| Invite codes you opened, and activity on your adventures (joins, role changes, deleted or replaced tabs) | So squads can see what changed and why. |
| A short audit record when your data is downloaded or an account is deleted | To prove we honoured your rights. |

We **don't** collect your phone number or contacts. You can't upload pictures to Roamio during the pilot. Reading a bill with "Scan a bill" happens on your phone; the bill image isn't sent anywhere or kept. Roamio has **no ads** and, today, **no analytics or crash reporting** in the app.

### Where it's kept
On Google's Firebase service, in the **Mumbai (asia-south1)** region in India. Data is encrypted while it travels (TLS) and while stored (Google-managed encryption). Security rules on the server — not just the app screens — decide who can read what.

### Who else is involved

| Service | What they get | Why |
|---|---|---|
| **Google Firebase** (Authentication, Firestore, Storage, Cloud Functions, Cloud Messaging, Remote Config, Hosting) | Everything above, as our data processor | To run the app. If you sign in with Google, Google also confirms who you are. |
| **Google Play Integrity** (part of Google Play services on your phone) | A check that the app on your phone is the real Roamio and hasn't been tampered with; it says nothing about what you do in the app | To protect Roamio's servers from fake apps (Firebase App Check). |
| **Open-Meteo** (open-meteo.com) | If you've turned Location on: your approximate position (rounded to about 1 km). Otherwise: just the adventure's city and country | To show the weather on your Home card. No account or name is sent. |
| **Unsplash** (unsplash.com) | Your phone loads the adventure's country photo from Unsplash. Our server asks Unsplash for a photo of the country — never anything about you | Adventure banner pictures, with credit to the photographer. |
| **GitHub** (github.com) | Your phone asks GitHub, at most once a day, for the latest Roamio version | To tell you when an update is ready. |
| **ExchangeRate-API** (open.er-api.com) | Nothing about you: our server fetches the day's exchange rates once a day | To convert currencies. |
| **Email provider** (set up by the owner through Firebase's "Trigger Email" extension) | Email addresses and the text of messages we send (parental consent requests and account notices) | To send those emails. |

Like any website, these services see your phone's internet (IP) address when your phone talks to them. We don't sell or share your data with anyone else.

### How long we keep it
- **While your account is open**, we keep your data so the app works.
- **When you delete your account**, your profile, budgets, settings, notification codes and sign-in are deleted straight away (and always within 30 days). Tabs you were part of stay with your squad, with your name shown as "Deleted user", so everyone's balances stay right.
- **Emails we send** (consent requests and account notices) are deleted from our outbox after **30 days**.
- **Audit records** are deleted after **1 year**.
- **Parental consent records** (if you are a parent) are kept for the life of the child's account plus **1 year**, as proof of consent.

### Your rights — all in **You → Privacy centre**
- **Download your data:** a file of everything we keep about you.
- **Correct your data:** change your name, character and description on the You page. To fix your date of birth, write to us (we check it by hand).
- **Delete your account.** If you lead a squad with others in it, make someone else leader first.
- **Nominate a person** to use these rights for you if you can't (for example through illness or death). During the pilot, write to our grievance officer (below) with their name and email; choosing one in the app comes in Phase 2.
- **Change your mind:** switch notifications, location or camera on or off at any time. Turning one off stops it from then on.
- **Raise a concern** with our grievance officer (below). If you're not happy with our answer, you can complain to the **Data Protection Board of India**.

### Grievance officer
Varun Parikh. During the pilot, contact Varun directly, or through the person who invited you.
We acknowledge every concern **within 7 days** and aim to resolve it within 30 days.

### If something goes wrong
If your data is ever exposed, we will tell you without delay: what happened, what it means for you, what we're doing about it, and what you can do. We also report it to the Data Protection Board. See [BREACH_RESPONSE.md](breach-response.md).

### Changes
If we change this notice we'll update its version and date, and tell you before a change that affects you takes effect.

---

## Child notice (for parents and guardians)

Version 2026-10 · For the parent or lawful guardian of a 13–17-year-old

> **Not in use during the pilot.** Roamio's Android pilot is for adults (18 and over). This notice applies once under-18 accounts open in Phase 2.

Your child wants to use Roamio, an app for splitting travel costs with friends. Because they are under 18, Indian law (DPDP Act §9) needs your **verifiable consent** first. Roamio is run by Varun Parikh (the "Data Fiduciary").

### How consent works
1. Your child enters your email. We email you a single-use link that works for **7 days** (reminders on day 3 and day 6).
2. You sign in to Roamio — or create an account — with that email. Your account must show you are **18 or older**. *Falsely claiming to be a child's parent or guardian is an offence.*
3. You read this notice and tap **I give consent** or **Decline**.
4. We record your decision: your account, your child's account, this notice's version, how you were checked, and when. **Your child can't change this record.**

If you decline, or nobody answers within 7 days, your child's account and data are **deleted** and they are told by email.

### What we keep about your child, and why
- Their **name, email and date of birth** — to run the account and know they are under 18. Until you say yes, this (plus your email and relationship) is all we keep.
- After you say yes: an optional **profile photo and description**, their **profile currency**, their **notification and camera choices** and a notification code for their phone.
- The **adventures, tabs (expenses), photos and settled transfers** they add or are part of — their squad sees these, which is the point of the app.
- Their **personal budget** — private from the squad.
- A short **audit record** when their data is downloaded or their account is deleted.

### Extra protections for under-18s
- **No tracking or monitoring:** no analytics and no crash reports, ever, on a child's account. No ads (Roamio has none).
- **No location:** they can't tag where a tab happened, and the weather on their Home card uses the adventure's **city**, not where they are.
- **Their budget stays private** from the squad. You can see it only in a data download you request.
- Photos are shrunk and stripped of hidden details (including GPS) on the phone before upload.
- No phone number or contacts are collected.

### Where it's kept and who else is involved
On Google Firebase in **Mumbai (asia-south1)**, India, encrypted in transit and at rest. The services involved are the same as in the [adult notice](#who-else-is-involved), with one difference: **Open-Meteo only ever gets the adventure's city**, never your child's position.

### Your controls — **You → Linked children** and **Privacy centre**
- See your child's status and the date you gave consent.
- **Download your child's data** (the same file they would get).
- **Ask for a correction** by writing to the grievance officer.
- **Withdraw consent at any time.** Your child's account is frozen straight away and deleted after **48 hours**; they are told. Tabs they were part of stay with the squad as "Deleted user", so balances stay right.

Your child can also change their notification and camera choices, download their data and delete their account themselves.

### How long we keep it
- While the account is open.
- When the account is deleted (by them, by you withdrawing, or by a declined or expired request), their profile, profile photos, budgets and sign-in are deleted straight away (always within 30 days); tabs, including photos they added to them, stay with the squad as "Deleted user".
- Emails we sent about the request are deleted from our outbox after **30 days**.
- **Your consent record** is kept for the life of the child's account plus **1 year**, as proof of consent.
- Audit records are deleted after **1 year**.

### When your child turns 18
The link to you is removed, you are told, and they must accept the adult notice themselves before using the app again.

### Grievance officer
Varun Parikh. During the pilot, contact Varun directly, or through the person who invited you.
We acknowledge every concern **within 7 days**. You can also complain to the **Data Protection Board of India**.

---

## Change log

| Version | Date | Change |
|---|---|---|
| 2026-10 | 2026-10-30 | First adult and child notices for the Android pilot. |
| 2026-10 (revised) | 2026-10-30 | Before anyone accepted it: the pilot asks no date of birth (people confirm they're 18 or older at sign-up), nominating is by writing to us until Phase 2, and the child notice is marked as not in use. Version unchanged because no one had agreed to the earlier wording. |
| 2026-10 (revised) | 2026-11-01 | Before anyone accepted it on prod: the placeholder grievance email is removed for the pilot; people contact the owner directly, and a dedicated address comes in the next phase. |

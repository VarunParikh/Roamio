# Personal data breach response

Spec: [SPEC.md §8](../requirements/product-spec.md) · Notice: [PRIVACY_NOTICE.md](privacy-notice.md)

A **personal data breach** is any unauthorised use, sharing, change, loss or destruction of personal data that Roamio holds — for example a security rule that let one squad read another's tabs, a leaked service-account key, a lost laptop with exported data, or photos deleted by mistake.

Under the DPDP Act 2023 (§8(6)) and DPDP Rules 2025 (Rule 7), Roamio must tell **every affected person** and the **Data Protection Board of India** without delay, and send the Board a **detailed report within 72 hours** of becoming aware.

*Engineering checklist, not legal advice. Before public launch, have a lawyer confirm the Board's current reporting channel and form.*

## Who does what

Roamio is a one-person project in the pilot, so roles are few:

| Role | Who | Does |
|---|---|---|
| **Incident lead** | Varun Parikh (owner, grievance officer) | Decides it's a breach, approves every message to people and the Board, keeps the incident log. |
| **Engineer** | Varun, helped by a coding agent | Contains, investigates and fixes. Never deletes evidence. |
| **Processor** | Google Firebase / Google Cloud | Their own incidents reach the owner through the Google Cloud console and the project's billing/contact email. |

Anyone (a pilot user, a squad member, a security researcher) can report a suspected breach to the owner directly during the pilot. A dedicated grievance email comes in the next phase.

## Timeline

| When | What |
|---|---|
| **Hour 0** | Someone notices. Start the [incident log](#incident-log): time, who noticed, what they saw. |
| **First 4 hours** | [Contain](#1-contain). |
| **Within 24 hours** | [Assess](#2-assess): what data, whose, how many, still happening? |
| **Without delay** (as soon as the facts above are known — aim for 24 h) | Short **intimation to the Board** and **message to each affected person**. |
| **Within 72 hours** of becoming aware | **Detailed report to the Board** (or ask the Board in writing for more time, with reasons). |
| **Within 2 weeks** | Fix shipped, tests added, review written. |

## 1. Contain

Stop it getting worse first; investigate second. Pick what fits:

- **Leaked key or token** (service account, Unsplash key, signing key, CI secret): revoke it in Google Cloud → IAM / Secret Manager / GitHub settings, then create a new one. Check Cloud Audit Logs for its use.
- **Bad security rule**: deploy a fixed `firestore.rules` or `storage.rules` (with the allow + deny test that would have caught it). If a fix will take time, deploy a rule that denies the affected path for everyone.
- **Misbehaving Cloud Function**: delete or disable just that function (`firebase functions:delete <name> -P prod`) — data stays.
- **Compromised account**: disable the user in Firebase Console → Authentication.
- **Anything bigger**: set the app's `min_supported_version` in Remote Config above the current version so the app stops being usable, and say why in the next release notes.

Don't delete logs, documents or files that show what happened; copy them to the incident folder first.

## 2. Assess

Answer, in the incident log:

1. **What data?** Use [DATA_MODEL.md](../design/data-model.md) to list the collections and fields involved. Flag anything about **under-18 accounts** (their `ageStatus` is `minor_*`), dates of birth, photos or locations — these are the most sensitive.
2. **Whose?** List the affected user IDs. For a child, the person to tell is also the parent in `parentalConsents/{childUid}`.
3. **How?** Cause, when it started, when it stopped. Sources: Cloud Audit Logs, Cloud Functions logs, Firestore/Storage usage graphs, `auditLog`, GitHub history.
4. **Likely harm?** For example embarrassment, money (if amounts or settlements were changed), identity misuse.

When in doubt, treat it as a breach and report it. Reporting something that turns out to be small is fine; not reporting is not.

## 3. Notify

### Affected people
Email each one (and each affected child's parent) in plain language, from the grievance address. Include:
- what happened and when, in a sentence or two;
- what data of theirs was involved;
- what it might mean for them;
- what we have done to stop it and reduce harm;
- what they can do (for example: change your password, watch for odd emails);
- who to contact: the grievance officer.

If the app is still usable, also show a short notice on Home (via a release or Remote Config) so people who miss the email see it.

### Data Protection Board
1. **Intimation without delay:** what happened, roughly how many people, likely impact.
2. **Detailed report within 72 hours:** the facts and timeline, cause, the people and data involved, the harm, what was done to contain and fix it, the findings about who/what caused it, and copies of the messages sent to people.

Use the Board's official online channel (check the Board's website at the time; it may change).

## 4. Fix and learn
- Write a failing test that reproduces it (rules: allow + deny test; logic: unit test), then fix.
- Rotate anything that might have been seen.
- Add a short review to `docs/epics/roamio/verify/reviews/` (what happened, why, what changed). Update this file if the process didn't work.

## Incident log

Keep one Markdown file per incident, outside the public repo (for example a private Google Drive folder), named `YYYY-MM-DD-short-name.md`:

```
Noticed: <date time IST> by <who>, how: <...>
Contained: <date time> — <what was done>
Data: <collections / fields>    People: <count, uids list attached>    Children involved: yes/no
Cause: <...>
Board intimation sent: <date time>    Detailed report sent: <date time>
People told: <date time>, how: <email / in app>
Fix: <PR link>    Review: <docs/epics/roamio/verify/reviews/...>
```

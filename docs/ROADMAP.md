# Roadmap

What comes after the Android pilot (spec §1.2). Owner decisions are dated.

## Phase 2: web app, plus features held back from the pilot

**Held back from the pilot (owner, 2026-10-30).** The code, security rules and tests are all in place; only the screens are switched off, in `app/lib/core/config/phase2.dart`, so pilot users aren't confused. Turning a feature back on is a one-line change there, plus a device check.

| Feature | Switch | What switching it on brings back | Before turning on |
|---|---|---|---|
| **Under-18 accounts** (spec §7) | `minorsEnabledProvider` | the date-of-birth question at sign-up; sign-up for ages 13–17 with a parent's email consent; waiting-for-parent, account paused and turned-18 screens; a parent's **Linked children** on You and in the Privacy centre (withdraw consent, download a child's data); the location lock for under-18s | DigiLocker or virtual-token parent verification (spec §17.2); the child privacy notice (`docs/PRIVACY_NOTICE.md`) taken out of "not in use"; Journey E checked on a device |
| **Nominate a person** (spec UC-29, DPDP §14) | `nomineeEnabledProvider` | the Nominate section in the Privacy centre (stored in `account.nominee`, adults only) | the grievance email chosen, so nominees can reach us; the adult notice updated to describe in-app nomination |

During the pilot:
- **No date of birth is asked and no one is refused.** The sign-up tick reads "I'm 18 or older and I've read the privacy notice", and the account record keeps `adultDeclared: true` (owner's choice, 2026-10-30). A separate, DPDP-compliant version with age checks and parental consent comes in Phase 2.
- **Nominating is by writing to the grievance officer**, as the privacy notice says.
- Journey E (`app/integration_test/journeys/e_minor.dart`) still runs with the under-18 features switched on, so that code stays tested.

**Web app** (spec §1.2): the same accounts and data, in a browser.

**Also deferred to this phase:** the grievance officer's email address (Task 40; a placeholder until then).

## Phase 3
iOS app · Sign in with Apple (spec §1.2).

## Not planned yet
In-app payments · Explore page · gamification · duplicate-tab detection · more languages (spec §1.2).

# Known Limitations: Roamio

As of 2026-11-01, on `v0.1.0-rc1`.

## Scan bill
- **Accuracy isn't measured.** Three real bills read correctly, but they helped shape the fix. The planned check is 30–50 other bills, especially cash and restaurant ones.
- **A finished scan coming back into the app hasn't been proven in a test.**
- A wrong amount under a strong label such as "Grand Total" still gets through.
- "To Pay" can match other wording containing it, beyond the "Auto Pay" case handled.
- A bill with no total label, or a doubted plain "Total", needs the amount typed in. That's by design.
- Shop names can come out as junk and land in the description (phase 2).
- Thai and Hindi text won't be read, and the bill is assumed to be in the tab's currency.

## Place names
- Some names are odd: Bangkok shows as "Krung Thep Maha Nakhon, Thailand", and Rome as "Roma, Italy" (phase 2).
- From reading the code, a place whose lookup failed offline stays as coordinates until the app is reopened.
- The service's rate limit is unspecified.

## Settling up
- A payment in another currency is recorded at today's rates, so the recorded amount can differ slightly from what was paid.
- The same payment marked twice now counts once, which passed on two real phones on a dev build (owner's report, 2026-11-01). Two phones can still both count if they disagree: for example, different amounts typed, or one phone hadn't yet seen an earlier payment. Undo in Payments recorded fixes it.
- Payments recorded twice before this fix stay recorded until someone undoes the extra one.

## Not built, or switched off for the pilot
See the [roadmap](../../../core/roadmap.md): under-18 accounts, uploading your own pictures, Raise a concern, in-app Nominate, web, iOS, payments.

Also phase 2: approved tabs skipping re-approval, and stale stored names (audit items 10 and 12).

## Privacy
- The privacy notice names the owner with no email address, by the owner's decision for the pilot. Get it reviewed before any wider launch.
- The notice is an engineering checklist against India's DPDP rules, not legal advice.
- App Check isn't enforced, because sideloaded APKs may fail it.

## Not yet proven
- A real crash showing up readable in Crashlytics.
- An update installing over an older version, and the update popup.
- Prod's first scheduled exchange-rate run.
- A 10-person pilot.
- Remaining device checks are in [`tasks/HANDOVER.md`](../../../../tasks/HANDOVER.md).

## Platform
Android only, in English only, sideloaded, so Play Protect may warn on install.

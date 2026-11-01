# References and Glossary: Roamio

## 1. Glossary

The app's own words. Same as [spec §1.1](../epics/roamio/requirements/product-spec.md#11-glossary-app-dictionary), which wins if the two differ.

| Term | Meaning |
|---|---|
| **Adventure** | A trip, with a country, dates, base currency and banner |
| **Squad** | Everyone in an adventure: members and pals |
| **Squad Leader** | The member who created the adventure. Exactly one per adventure. |
| **Co-squad Lead** | A member promoted by the leader, with the same rights except managing leadership |
| **Admin** or **lead** | The Squad Leader or a Co-squad Lead |
| **Member** | An app user in the squad |
| **Pal** | Someone on the trip without the app: a nickname, a character and their own balance |
| **Tab** | One expense in an adventure |
| **Payer** | A squad member who paid part or all of a tab |
| **Participant** | A member or pal who owes a share of a tab |
| **Split** | The calculated who-owes-whom for an adventure |
| **Waiting tab** | A tab no admin has approved yet. It counts towards nothing. |
| **Personal tab** | A tab you paid and only you share. It needs no approval and only you can see it. |

## 2. Technical terms

| Term | Meaning |
|---|---|
| **Minor units** | The smallest unit of a currency, such as paise or cents |
| **Basis points** | Hundredths of a percent. 100% is 10,000. |
| **Dev** and **prod** | The test and real Firebase projects |
| **Journey** | An end-to-end test of the real app against local emulators (spec §15) |
| **Upload key** | The key that signs every release, so phones accept updates |
| **rc** | Release candidate: a pre-release the update popup ignores |
| **DPDP** | India's Digital Personal Data Protection Act, 2023 |
| **PRD** | Product requirements document. Here it's the [product spec](../epics/roamio/requirements/product-spec.md). |
| **BRD** | Business requirements document |
| **ADR** | Architecture decision record |

## 3. References
- **Owner's brief:** [product vision](product-vision.md)
- **Look and feel:** [`design/DESIGN.md`](../../design/DESIGN.md)
- **Source data:** [`data/`](../../data/)
- **Law:** Digital Personal Data Protection Act, 2023 and the DPDP Rules, 2025. Roamio uses them as an engineering checklist, not legal advice.

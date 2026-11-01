# User Stories and Traceability: Roamio

Status: APPROVED (owner, 2026-11-01), written 2026-11-01 by restating the [spec's](product-spec.md) use cases as stories. It adds no requirements. Acceptance criteria stay in the spec.

Tests are listed by folder, not one by one. Journeys are in `app/integration_test/journeys/`; app tests are in `app/test/features/`; server tests are in `firebase/test/`.

| ID | Story | Spec | Where it's tested |
|---|---|---|---|
| US-1 | As a new user, I want to sign in with Google or email, so that I can start quickly | UC-1 to UC-4 | `auth/`, Journey A |
| US-2 | As a member, I want Home to show my current trip and what needs me, so that I know what to do next | UC-5, UC-6 | `home/` |
| US-3 | As a traveller, I want to see the weather on my trip card, so that I can plan the day | UC-7 | `home/` |
| US-4 | As a traveller, I want to create an adventure with a country, name and dates, so that my squad has a place to log costs | UC-8, UC-10, UC-11 | `adventures/`, Journey A |
| US-5 | As a leader, I want to share an invite link, so that my squad can join | UC-9 | `invites/`, `functions/invites`, Journey A |
| US-6 | As an invitee, I want to join from a link or code, so that I can see the squad | UC-12 to UC-14 | `invites/`, `functions/join`, Journey B |
| US-7 | As a leader, I want to promote and remove people, and hand over leadership, so that the squad stays managed | UC-15 to UC-17 | `squad/`, `functions/roles` |
| US-8 | As a lead, I want to add a friend without the app as a pal, so that their share still counts | UC-18 | `squad/`, Journey A |
| US-9 | As a member, I want a budget only I can see, with alerts, so that I can watch my spending privately | UC-19, UC-20 | `budget/`, `functions/budget`, rules tests, Journey F |
| US-10 | As a member, I want to add a tab with several payers and custom shares in any currency, so that it reflects what really happened | UC-21, §6 | `tabs/`, `splits/`, Journey C |
| US-11 | As a member, I want to scan a bill, so that I type less, and I still confirm what it found | UC-21 | `tabs/`, `core/images/`, `receipt_ocr_test` |
| US-12 | As a member, I want a tab to show where it happened, in words, so that I can recognise it later | UC-21 | `core/location/`, `tabs/` |
| US-13 | As an admin, I want to approve or reject tabs, so that only agreed costs count | UC-21a | `tabs/`, `functions/approvals`, Journey G |
| US-14 | As a member, I want a personal tab only I can see, so that private spending stays private | UC-21a | `tabs/`, rules tests |
| US-15 | As a creator or lead, I want to edit or delete tabs, so that mistakes can be fixed | UC-22 | `tabs/`, `functions/tabs` |
| US-16 | As a member, I want to browse tabs by day, so that I can review the trip | UC-23 | `adventures/`, `tabs/` |
| US-17 | As a member, I want to see what I spent and who pays whom, so that settling up is easy | UC-24 to UC-26 | `splits/`, Journey C |
| US-18 | As a member, I want to record a payment in any currency, so that balances stay right without moving money in the app | UC-26a | `splits/`, `functions/settlements`, Journey C |
| US-19 | As a member, I want to export a trip as PDF or Excel, so that I can keep or share it | UC-27 | `splits/`, Journey F |
| US-20 | As a user, I want to manage my character, name, currency and switches, so that the app suits me | UC-28, UC-28a | `profile/` |
| US-21 | As a user, I want to download or delete my data, so that I stay in control | UC-29 | `profile/`, `functions/export-data`, `functions/delete-account`, Journey F |
| US-22 | As a traveller, I want everything to work offline and sync by itself, so that a bad connection doesn't stop me | UC-30 to UC-33 | `sync/`, Journey D |
| US-23 | As a tester, I want to be offered updates, so that I stay on the latest version | UC-34 | `updates/` |
| US-24 | As a parent, I want to approve or refuse my child's account (switched off in the pilot) | §7 | `consent/`, `functions/consent`, Journey E |

## Not yet proven on a real device
See [known limitations](../release/known-limitations.md).

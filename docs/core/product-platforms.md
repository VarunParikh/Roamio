# Product Platforms: Roamio

Status: DRAFT, written 2026-11-01. Sources: [spec](../epics/roamio/requirements/product-spec.md) §2 and §9, [SETUP.md](../SETUP.md), [RELEASING.md](../RELEASING.md) and live checks that day.

## 1. Platform map

| Concern | Platform | Notes |
|---|---|---|
| App | Flutter, Android first | Version pinned in `app/.fvmrc`. Web is Phase 2, iOS Phase 3. |
| Sign-in | Firebase Authentication | Google, and email with password |
| Database | Cloud Firestore, asia-south1 | Offline persistence on |
| Server logic | Cloud Functions (TypeScript), asia-south1 | 33 functions on each of dev and prod, 2026-11-01 |
| Files | Cloud Storage, asia-south1 | Rules deny uploads in the pilot |
| Website | Firebase Hosting | Invite pages and the privacy notice |
| Push | Firebase Cloud Messaging | |
| Remote settings | Firebase Remote Config | [REMOTE_CONFIG.md](../REMOTE_CONFIG.md) |
| Crash reports | Firebase Crashlytics | Off for under-18 accounts. No report checked as readable in the console yet. |
| Distribution | GitHub Releases | Signed APK; the app checks for newer versions |
| CI | GitHub Actions | Checks on each PR, nightly journeys, owner-approved releases |

## 2. Outside services

| Service | Used for | If it's unavailable |
|---|---|---|
| open.er-api.com | Daily exchange rates | Last available day's rates, marked on the tab |
| Unsplash | Banner photos | Gradient banner with the flag |
| Open-Meteo | Weather | Hidden |
| Android's Geocoder (through the `geocoding` package) | Place names on tabs | Coordinates. Its rate limit is unspecified, and an offline lookup never returns, so the screen keeps showing coordinates. |
| ML Kit Text Recognition and Document Scanner | Scan bill, on the phone | The camera, where the scanner can't run |

## 3. Projects

| | Dev | Prod |
|---|---|---|
| Project | `roamio-dev-varun` | `roamio-prod-varun` |
| Android package | `app.roamio.android.dev` | `app.roamio.android` |
| Website | `roamio-dev-varun.web.app` | `roamio-prod-varun.web.app` |
| Deployed (2026-11-01) | Functions from `cbd8efd` | Functions from `65382bd`, website from `247fb4b` |

## 4. Cost
Both projects are on the Blaze pay-as-you-go plan. Dev has a ₹500 budget alert, and the owner confirmed prod has an alert. A budget sends alerts and doesn't stop charges.

## 5. Platform risks
- **Sideloading:** Play Protect warnings, and App Links aren't verified. The pilot guide explains the warning, and invite codes are the fallback.
- **App Check isn't enforced:** sideloaded APKs may fail Play Integrity. See [SETUP.md](../SETUP.md).
- **The upload key can't be recovered.** Losing it means nobody can update the app. Backups are the owner's responsibility.
- **Unsplash is in demo mode** at 50 requests an hour. Banners are cached per country.

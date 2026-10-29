# Remote Config keys

Spec: [SPEC.md §11](SPEC.md). Every key has an in-app default, so Roamio behaves exactly as shipped when Remote Config is unreachable or a value is missing or garbled (a bad value falls back to its default, it never breaks a screen).

Set values in the Firebase console → Remote Config, once per project (`roamio-dev-varun`, `roamio-prod-varun`). Remote Config is free.

## App (read on launch; fetched at most every 12 hours)

Code: `app/lib/core/config/remote_config.dart` (`remoteConfigDefaults`).

| Key | Type | Default | What it does |
|---|---|---|---|
| `ocr_enabled` | `true`/`false` | `true` | Shows "Scan a bill" on Add tab (UC-21a). |
| `weather_enabled` | `true`/`false` | `true` | Weather on the Home hero card (UC-7). |
| `export_enabled` | `true`/`false` | `true` | PDF/Excel export on Split (UC-27). |
| `cta_pulse_enabled` | `true`/`false` | `true` | The primary button's three-breath pulse on empty screens (spec §12). Reduced-motion settings always win. |
| `min_supported_version` | `x.y.z` | `0.0.0` | Versions below this must update before using the app (Task 38). |
| `category_order` | comma-separated category ids | empty | These categories are listed first, in this order; the rest follow as bundled. Unknown ids are ignored. Ids are in `app/assets/data/categories.json`. |

## Server (Cloud Functions; read at most every 10 minutes per instance)

Code: `firebase/functions/src/config.ts` (`SERVER_CONFIG_DEFAULTS`).

| Key | Type | Default | Allowed | What it does |
|---|---|---|---|---|
| `budget_alert_thresholds` | JSON list of whole percentages | `[80, 100]` | 1–200, at least one | When a personal budget alert is sent (UC-19, UC-20). |
| `invite_validity_days` | whole days | `14` | 1–90 | How long a new invite link works (UC-9). Existing links keep their expiry. |
| `consent_link_validity_days` | whole days | `7` | 1–30 | How long a parent has to answer before a teen's request expires (spec §7.1). Reminders stay on days 3 and 6. |

## Not keys yet
- **Copy text** (spec §11): no screen reads its wording from Remote Config yet; add a key here when one does.

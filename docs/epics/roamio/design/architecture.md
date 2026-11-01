# Architecture: Roamio

Status: APPROVED (owner, 2026-11-01), written 2026-11-01 from the [spec](../requirements/product-spec.md), [plan](../../../../tasks/plan.md), [ADRs](adr/README.md) and the code.

## System

```mermaid
flowchart LR
  subgraph Phone["Android phone"]
    App["Flutter app"]
    Cache["Firestore offline copy"]
    Kit["ML Kit scanner and text reader"]
    Geo["Android Geocoder"]
    App --- Cache
    App --- Kit
    App --- Geo
  end
  subgraph FB["Firebase, asia-south1"]
    Auth["Authentication"]
    FS["Firestore and security rules"]
    Fn["Cloud Functions"]
    Web["Hosting: invite and privacy pages"]
    Other["Remote Config, FCM, Crashlytics"]
  end
  App --> Auth
  Cache <--> FS
  App --> Fn
  FS --> Fn
  App --> Other
  Fn --> FX["open.er-api.com"]
  Fn --> Un["Unsplash"]
  App --> Wx["Open-Meteo"]
  App --> GH["GitHub Releases: update check"]
```

## Main decisions

| Decision | Why | Where |
|---|---|---|
| Feature-first Flutter layout, with pure Dart in `domain/` | The riskiest logic can be tested on its own | `app/lib/features/<feature>/` |
| Money in integer minor units, percentages in basis points | No rounding errors | Spec §6 |
| Security rules are the privacy boundary | The UI can't be trusted to guard data | `firebase/firestore.rules` |
| Cloud Functions for anything that must be trusted | The client can't grant itself a role | `firebase/functions/src/` |
| Firestore's own offline queue | Avoids building a sync engine | [ADR-002](adr/ADR-002-offline-sync-model.md) |
| Two Firebase projects | Testing never touches real data | [Platforms](../../../core/product-platforms.md) |
| Features held back behind switches | Code stays built and tested | `app/lib/core/config/phase2.dart` |

## Offline and sync

```mermaid
flowchart TD
  A["Three failed connection checks"] --> B["App switches Firestore offline, shows offline card"]
  B --> C["Tabs are saved on the phone"]
  C --> D["Connection returns"]
  D --> E["Network back on, queued writes upload by themselves"]
  E --> F{"Did the server accept them?"}
  F -- Yes --> G["Synced ✓"]
  F -- No --> H["Card says what wasn't saved, with OK"]
```

## Adding a tab with Scan bill

```mermaid
flowchart TD
  A["Scan bill"] --> B{"Can Google's scanner run?"}
  B -- Yes --> C["Scanner flattens the page"]
  B -- No --> D["Camera opens"]
  C --> E["ML Kit reads the text on the phone"]
  D --> E
  E --> F{"Labelled total found and trusted?"}
  F -- Yes --> G["Amount prefilled; the person confirms"]
  F -- No --> H["Amount stays empty; the form asks for it"]
```

Nothing from the scan is uploaded or kept in the pilot.

## Data
See the [data model](data-model.md).

## Release

```mermaid
flowchart LR
  A["Push tag vX.Y.Z"] --> B["Owner approves on GitHub"]
  B --> C["Build and sign APK"]
  C --> D["GitHub Release"]
  D --> E["App's update popup offers it"]
```

A tag such as `v0.1.0-rc1` becomes a pre-release, which the popup ignores.

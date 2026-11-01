# ADR-002: Offline mode via Firestore persistence and a manual Sync button

Date: 2026-10-29 · Status: Accepted, then changed: since 2026-10-31 sync happens by itself when the connection returns, with no Sync button to press while connected (owner; spec UC-31)

## Context
The spec (UC-30–33) requires full offline use and a **Sync** button with the text "We know the data might be of essence, click here to sync the adventure with your squad". Edits made offline sync when the user presses it.

## Decision
Keep Firestore offline persistence on. When connectivity drops, the app calls `disableNetwork()` so writes queue locally; when connectivity returns, the Sync button appears and calls `enableNetwork()`, flushing the queue. Photos upload through our own retrying queue (Task 22). Conflicts are last-write-wins per tab, with an activity entry when an offline edit replaces a newer one.

## Alternatives considered
- **Custom outbox (SQLite/Drift):** full control, but duplicates what Firestore already does and adds a sync engine to test.
- **Automatic sync only:** simplest, but doesn't meet the spec's explicit button.

## Consequences
- Online-only actions (join, invite, role changes, deletion) are disabled offline.
- If the spike shows `disableNetwork` behaves badly (e.g. stale listeners), fall back to automatic sync with the button as "Sync now".

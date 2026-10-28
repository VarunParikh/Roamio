# ADR-001: Firebase as the backend, in asia-south1

Date: 2026-10-29 · Status: Accepted

## Context
Roamio Phase 1 is an Android pilot for 10 users, built by one owner with AI assistance, with Web and iOS to follow. It needs auth (Google + email), a database that works offline, file storage for photos, trusted server logic (invites, roles, parental consent, budget alerts), push notifications and remote config. India's DPDP Act applies.

## Decision
Use Firebase (Auth, Cloud Firestore, Cloud Storage, Cloud Functions in TypeScript, FCM, Remote Config, Hosting) with every resource in **asia-south1 (Mumbai)**. Prod runs on the Blaze plan (prepaid via UPI); dev stays on Spark and uses local emulators.

Security rules are the privacy boundary; anything that grants roles or crosses users runs in Cloud Functions.

## Alternatives considered
- **Supabase (Postgres + RLS):** stronger relational modelling for splits; rejected by the owner in favour of Firebase + Flutter.
- **Custom backend:** too much to operate for a 10-user pilot.

## Consequences
- Rules can't loop over arrays, so deep tab validation is repeated in a function trigger (see DATA_MODEL.md).
- Rules use `get()` lookups for membership; each costs a document read (fine at pilot scale).
- Storage and Functions require Blaze billing on prod.

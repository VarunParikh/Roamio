import {
  FieldValue,
  getFirestore,
  type DocumentData,
  type Timestamp,
} from "firebase-admin/firestore";
import { onDocumentWritten } from "firebase-functions/firestore";
import { logger } from "firebase-functions";

// Security rules can't loop over arrays, so this re-checks what they can't
// (DATA_MODEL.md): payments add up, percentages add up, and everyone on a
// new tab is in the squad. A failing tab is soft-deleted and logged; the
// app's split engine already refuses these, so this only catches bypasses.

const db = () => getFirestore();

type Payer = { id: string; amountMinor: number };

/** How much older than a tab its saved rates may be (an offline phone's last rates). */
const MAX_RATE_AGE_DAYS = 7;

/** Why [tab] is invalid, or null. [active] = members and active pals; [isMember] for payers. */
export function tabProblem(
  tab: DocumentData,
  active: Set<string>,
  isMember: (id: string) => boolean,
  before?: DocumentData,
): string | null {
  const payers: Payer[] = tab.payers ?? [];
  const participants: string[] = tab.participants ?? [];
  const sum = payers.reduce((total, p) => total + p.amountMinor, 0);
  if (sum !== tab.amountMinor) return "payments don't add up to the amount";
  if (payers.some((p) => !Number.isInteger(p.amountMinor) || p.amountMinor <= 0)) {
    return "each payer must pay more than zero";
  }
  if (new Set(payers.map((p) => p.id)).size !== payers.length) return "a payer is listed twice";
  if (new Set(participants).size !== participants.length) return "someone is listed twice";

  const percent = tab.percentBp as Record<string, number> | null | undefined;
  if (percent) {
    const keys = Object.keys(percent);
    const total = keys.reduce((t, k) => t + percent[k], 0);
    if (
      keys.length !== participants.length ||
      !keys.every((k) => participants.includes(k)) ||
      keys.some((k) => !Number.isInteger(percent[k]) || percent[k] <= 0) ||
      total !== 10000
    ) {
      return "percentages must add up to 100% over the participants";
    }
  }

  // The rates day the app saved (follow-up C4): never after the tab, and
  // at most a week before it, so nobody backdates to a better rate. Only
  // checked when it changes, so an old tab's edit is never refused for it.
  if (tab.fxDate !== before?.fxDate || tab.date !== before?.date) {
    const days = (Date.parse(tab.date) - Date.parse(tab.fxDate)) / 86_400_000;
    if (!(days >= 0 && days <= MAX_RATE_AGE_DAYS)) {
      return "the exchange rates must be from the tab's day or the week before";
    }
  }

  // Only people newly put on the tab must be active now; someone who has
  // since left stays on the tabs they were already on (spec UC-16).
  const wasOn = new Set<string>([
    ...((before?.participants as string[]) ?? []),
    ...((before?.payers as Payer[]) ?? []).map((p) => p.id),
  ]);
  if (participants.some((id) => !wasOn.has(id) && !active.has(id))) {
    return "everyone sharing must be in the squad";
  }
  if (payers.some((p) => !wasOn.has(p.id) && !isMember(p.id))) {
    return "every payer must be a member";
  }
  return null;
}

/**
 * True when [after] is an edit made from an older version than the one it
 * replaced (spec UC-32: last write wins, but the squad is told). Only writes
 * that moved `updatedAt` count, so attaching a photo link never trips it.
 */
export function replacedEdit(before?: DocumentData, after?: DocumentData): boolean {
  const base = after?.baseUpdatedAt as Timestamp | undefined;
  const was = before?.updatedAt as Timestamp | undefined;
  const now = after?.updatedAt as Timestamp | undefined;
  if (!base || !was || !now || now.isEqual(was)) return false;
  return !base.isEqual(was);
}

export const checkTab = onDocumentWritten("adventures/{aid}/tabs/{tid}", async (event) => {
  const after = event.data?.after;
  const tab = after?.data();
  if (!after || !tab) return;
  const adventureRef = db().doc(`adventures/${event.params.aid}`);
  const adventure = await adventureRef.get();
  if (adventure.get("hasTabs") !== true) await adventureRef.update({ hasTabs: true });
  if (tab.deleted === true) {
    // A lead just deleted it: say so in the activity (spec UC-22).
    const before = event.data?.before?.data();
    if (before && before.deleted !== true && tab.deletedBy) {
      await adventureRef.collection("activity").add({
        type: "tab_deleted",
        actorUid: tab.deletedBy,
        subject: event.params.tid,
        createdAt: FieldValue.serverTimestamp(),
      });
    }
    return;
  }

  const members: string[] = adventure.get("memberUids") ?? [];
  const pals = await adventureRef.collection("pals").where("status", "==", "active").get();
  const active = new Set([...members, ...pals.docs.map((p) => p.id)]);
  const problem = tabProblem(tab, active, (id) => members.includes(id), event.data?.before?.data());
  if (!problem) {
    if (replacedEdit(event.data?.before?.data(), tab)) {
      await adventureRef.collection("activity").add({
        type: "tab_edit_replaced",
        actorUid: tab.createdBy,
        subject: event.params.tid,
        createdAt: FieldValue.serverTimestamp(),
      });
    }
    return;
  }

  logger.warn("Rejected tab", { adventure: event.params.aid, tab: event.params.tid, problem });
  const batch = db().batch();
  batch.update(after.ref, { deleted: true, updatedAt: FieldValue.serverTimestamp() });
  batch.create(adventureRef.collection("activity").doc(), {
    type: "tab_rejected",
    actorUid: tab.createdBy ?? null,
    subject: event.params.tid,
    reason: problem,
    createdAt: FieldValue.serverTimestamp(),
  });
  await batch.commit();
});

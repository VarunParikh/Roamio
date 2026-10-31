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
// A payer's `method` is deliberately not checked: the app shows an unknown one
// as Other, so it must never remove a tab (spec UC-21).

const db = () => getFirestore();

type Payer = { id: string; amountMinor: number };

/**
 * Why [tab] is invalid, or null. [active] = members and active pals; [isMember] for payers.
 * [rateDayKnown]: whether `fx_rates` holds the tab's rates day, which the trigger reads.
 */
export function tabProblem(
  tab: DocumentData,
  active: Set<string>,
  isMember: (id: string) => boolean,
  before?: DocumentData,
  rateDayKnown = false,
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

  // The rates day the app saved (follow-up C4): never after the tab. An
  // earlier day is allowed only when `fx_rates` really holds it, so an offline
  // phone's last rates still count however old, but nobody can backdate to a
  // day with no rates. Only checked when it changes, so an old tab's edit is
  // never refused for it.
  if (tab.fxDate !== before?.fxDate || tab.date !== before?.date) {
    const days = (Date.parse(tab.date) - Date.parse(tab.fxDate)) / 86_400_000;
    if (!(days === 0 || (days > 0 && rateDayKnown))) {
      return "the exchange rates must be from the tab's day or an earlier day with rates";
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

/** Days after the trip's last day that leads can still add tabs (spec UC-11). */
const LEAD_GRACE_DAYS = 7;

/**
 * Why a new tab can't be added, or null. Members can add tabs dated up to the
 * trip's last day; leads and co-leads up to a week more. It goes by the tab's
 * own day, not today: a tab added offline can reach the server weeks later, and
 * must not be removed for that. The app stops anyone adding after their last
 * day, whatever date they pick. Edits are never refused for the date.
 */
export function windowProblem(
  tab: DocumentData,
  before: DocumentData | undefined,
  adventure: { endDate?: string; leaderUid: string; coLeadUids?: string[] },
): string | null {
  if (before) return null;
  const end = Date.parse(adventure.endDate ?? "");
  if (Number.isNaN(end)) return null; // Nothing to measure against.
  const leads = [adventure.leaderUid, ...(adventure.coLeadUids ?? [])];
  const grace = leads.includes(tab.createdBy) ? LEAD_GRACE_DAYS : 0;
  const last = new Date(end + grace * 86_400_000);
  const lastDay = last.toISOString().slice(0, 10);
  return tab.date > lastDay ? "tabs can't be dated after the trip" : null;
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

/** Whether what people owe changed; how someone paid doesn't count (spec UC-21a). */
export function moneyChanged(before: DocumentData, after: DocumentData): boolean {
  const facts = (t: DocumentData) =>
    JSON.stringify([
      t.amountMinor,
      t.currency,
      ((t.payers ?? []) as Payer[]).map((p) => [p.id, p.amountMinor]),
      t.participants,
      Object.entries(t.percentBp ?? {}).sort(([a], [b]) => a.localeCompare(b)),
    ]);
  return facts(before) !== facts(after);
}

export const checkTab = onDocumentWritten("adventures/{aid}/tabs/{tid}", async (event) => {
  const after = event.data?.after;
  const tab = after?.data();
  if (!after || !tab) return;
  const adventureRef = db().doc(`adventures/${event.params.aid}`);
  const adventure = await adventureRef.get();
  // Only its creator can see a personal tab, so it stays out of what the squad
  // sees: it doesn't lock the currency or appear in the activity (spec UC-21a).
  const personal = tab.status === "personal";
  if (!personal && adventure.get("hasTabs") !== true) await adventureRef.update({ hasTabs: true });
  if (tab.deleted === true) {
    // A lead just deleted it: say so in the activity (spec UC-22).
    const before = event.data?.before?.data();
    if (!personal && before && before.deleted !== true && tab.deletedBy) {
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
  const before = event.data?.before?.data();
  // Reads `fx_rates` only when the rates day or date changed (saves a read per write).
  const rateDayChanged = tab.fxDate !== before?.fxDate || tab.date !== before?.date;
  const rateDayKnown =
    rateDayChanged && tab.fxDate !== tab.date
      ? (await db().doc(`fx_rates/${tab.fxDate}`).get()).exists
      : false;
  const problem =
    windowProblem(tab, before, {
      endDate: adventure.get("endDate"),
      leaderUid: adventure.get("leaderUid"),
      coLeadUids: adventure.get("coLeadUids") ?? [],
    }) ?? tabProblem(tab, active, (id) => members.includes(id), before, rateDayKnown);
  if (!problem) {
    const before = event.data?.before?.data();
    if (before?.status === "waiting" && tab.status === "rejected") {
      await adventureRef.collection("activity").add({
        type: "tab_declined",
        actorUid: tab.decidedBy ?? null,
        subject: event.params.tid,
        createdAt: FieldValue.serverTimestamp(),
      });
    }
    const onlyAdmin =
      tab.createdBy === adventure.get("leaderUid") &&
      ((adventure.get("coLeadUids") as string[]) ?? []).length === 0;
    if (
      before?.status === "approved" &&
      tab.status === "approved" &&
      !onlyAdmin &&
      moneyChanged(before, tab)
    ) {
      await after.ref.update({
        status: "waiting",
        decidedBy: FieldValue.delete(),
        decidedAt: FieldValue.delete(),
      });
    }
    if (!personal && replacedEdit(event.data?.before?.data(), tab)) {
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

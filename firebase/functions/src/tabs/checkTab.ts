import { FieldValue, getFirestore, type DocumentData } from "firebase-admin/firestore";
import { onDocumentWritten } from "firebase-functions/firestore";
import { logger } from "firebase-functions";

// Security rules can't loop over arrays, so this re-checks what they can't
// (DATA_MODEL.md): payments add up, percentages add up, and everyone on a
// new tab is in the squad. A failing tab is soft-deleted and logged; the
// app's split engine already refuses these, so this only catches bypasses.

const db = () => getFirestore();

type Payer = { id: string; amountMinor: number };

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
  if (!problem) return;

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

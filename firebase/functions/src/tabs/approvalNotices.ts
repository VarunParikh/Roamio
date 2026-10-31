import { FieldValue, getFirestore, type DocumentSnapshot } from "firebase-admin/firestore";
import { onDocumentWritten } from "firebase-functions/firestore";
import { sendPush } from "../notify/push";

// Approval cards and pushes (spec UC-21a). Each waiting tab is one card per
// admin, cleared for everyone once it stops waiting, so Home's count can't go
// stale. Everything re-reads the tab first: triggers can arrive late and out
// of order, and a retried one finds its cards already there and pushes nothing.

const db = () => getFirestore();

type Squad = { leaderUid?: string; coLeadUids?: string[]; memberUids?: string[] };
type Decided = { createdBy?: string; decidedBy?: string };

export const waitingCardId = (aid: string, tid: string) => `${aid}_tabwaiting_${tid}`;
export const rejectedCardId = (aid: string, tid: string) => `${aid}_tabrejected_${tid}`;

const cardRef = (uid: string, id: string) => db().doc(`users/${uid}/notifications/${id}`);

const adminsOf = (s: Squad | undefined) =>
  s?.leaderUid ? [s.leaderUid, ...(s.coLeadUids ?? [])] : [];

/** Which cards a tab should have. A deleted tab has none. */
export function approvalState(tab: { status?: string; deleted?: boolean } | undefined) {
  if (!tab || tab.deleted === true) return "other";
  if (tab.status === "waiting" || tab.status === "rejected") return tab.status;
  return "other";
}

/** The admins who could decide a tab: all of them but its creator. */
export const waitingRecipients = (squad: Squad, createdBy: string | undefined) =>
  adminsOf(squad).filter((uid) => uid !== createdBy);

/** The creator, unless they rejected it themselves or are no longer in the squad. */
export function rejectionRecipient(squad: Squad, tab: Decided): string | null {
  const { createdBy, decidedBy } = tab;
  if (!createdBy || createdBy === decidedBy) return null;
  return squad.memberUids?.includes(createdBy) ? createdBy : null;
}

const stateOf = (tab: DocumentSnapshot | undefined) => approvalState(tab?.data());

async function announceWaiting(aid: string, tid: string) {
  const adventureRef = db().doc(`adventures/${aid}`);
  const tabRef = adventureRef.collection("tabs").doc(tid);
  const id = waitingCardId(aid, tid);
  const told = await db().runTransaction(async (tx) => {
    const [adventure, tab] = await Promise.all([tx.get(adventureRef), tx.get(tabRef)]);
    if (!adventure.exists || stateOf(tab) !== "waiting") return null;
    const admins = waitingRecipients(adventure.data() as Squad, tab.get("createdBy"));
    const cards = await Promise.all(admins.map((uid) => tx.get(cardRef(uid, id))));
    const due = admins.filter((_, i) => !cards[i].exists);
    const adventureName = String(adventure.get("name"));
    for (const uid of due) {
      tx.set(cardRef(uid, id), {
        type: "tab_waiting",
        adventureId: aid,
        adventureName,
        tabId: tid,
        createdAt: FieldValue.serverTimestamp(),
      });
    }
    return { due, adventureName };
  });
  if (told && told.due.length > 0) {
    await sendPush(told.due, {
      title: "A tab is waiting for your approval",
      body: told.adventureName,
      data: { type: "tab_waiting", adventureId: aid, tabId: tid },
    });
  }
}

async function announceRejected(aid: string, tid: string) {
  const adventureRef = db().doc(`adventures/${aid}`);
  const tabRef = adventureRef.collection("tabs").doc(tid);
  const id = rejectedCardId(aid, tid);
  const told = await db().runTransaction(async (tx) => {
    const [adventure, tab] = await Promise.all([tx.get(adventureRef), tx.get(tabRef)]);
    if (!adventure.exists || stateOf(tab) !== "rejected") return null;
    const creator = rejectionRecipient(adventure.data() as Squad, tab.data() as Decided);
    if (!creator || (await tx.get(cardRef(creator, id))).exists) return null;
    const adventureName = String(adventure.get("name"));
    tx.set(cardRef(creator, id), {
      type: "tab_rejected",
      adventureId: aid,
      adventureName,
      tabId: tid,
      description: String(tab.get("description") ?? ""),
      createdAt: FieldValue.serverTimestamp(),
    });
    return { creator, adventureName };
  });
  if (told) {
    await sendPush([told.creator], {
      title: "Your tab was rejected",
      body: told.adventureName,
      data: { type: "tab_rejected", adventureId: aid, tabId: tid },
    });
  }
}

/** Clears a waiting tab's cards, including for anyone demoted since they got one. */
async function clearWaiting(aid: string, tid: string) {
  const adventureRef = db().doc(`adventures/${aid}`);
  const tabRef = adventureRef.collection("tabs").doc(tid);
  await db().runTransaction(async (tx) => {
    const [adventure, tab] = await Promise.all([tx.get(adventureRef), tx.get(tabRef)]);
    if (!adventure.exists || stateOf(tab) === "waiting") return;
    const everyone = new Set<string>([
      ...adminsOf(adventure.data() as Squad),
      ...((adventure.get("memberUids") as string[]) ?? []),
      ...((adventure.get("leftUids") as string[]) ?? []),
    ]);
    for (const uid of everyone) tx.delete(cardRef(uid, waitingCardId(aid, tid)));
  });
}

async function clearRejected(aid: string, tid: string, creator: string | undefined) {
  if (!creator) return;
  const tabRef = db().doc(`adventures/${aid}/tabs/${tid}`);
  await db().runTransaction(async (tx) => {
    if (stateOf(await tx.get(tabRef)) === "rejected") return;
    tx.delete(cardRef(creator, rejectedCardId(aid, tid)));
  });
}

/** A tab changed: tell whoever it now concerns and clear what no longer applies. */
export const tabApprovalNotices = onDocumentWritten(
  "adventures/{aid}/tabs/{tid}",
  async (event) => {
    const { aid, tid } = event.params;
    const before = stateOf(event.data?.before);
    const after = stateOf(event.data?.after);
    if (before === after) return;
    if (before === "waiting") await clearWaiting(aid, tid);
    if (before === "rejected") {
      await clearRejected(aid, tid, event.data?.before?.get("createdBy"));
    }
    if (after === "waiting") await announceWaiting(aid, tid);
    if (after === "rejected") await announceRejected(aid, tid);
  },
);

/** A new admin can decide tabs already waiting, so they get those cards too. */
export const waitingCardsForNewAdmins = onDocumentWritten("adventures/{aid}", async (event) => {
  const before = event.data?.before?.data() as Squad | undefined;
  const after = event.data?.after?.data() as Squad | undefined;
  if (!before || !after) return;
  const added = adminsOf(after).filter((uid) => !adminsOf(before).includes(uid));
  if (added.length === 0) return;
  const { aid } = event.params;
  const adventureRef = db().doc(`adventures/${aid}`);
  await db().runTransaction(async (tx) => {
    const adventure = await tx.get(adventureRef);
    const waiting = await tx.get(adventureRef.collection("tabs").where("status", "==", "waiting"));
    for (const tab of waiting.docs) {
      if (stateOf(tab) !== "waiting") continue;
      for (const uid of added) {
        if (uid === tab.get("createdBy")) continue;
        tx.set(cardRef(uid, waitingCardId(aid, tab.id)), {
          type: "tab_waiting",
          adventureId: aid,
          adventureName: String(adventure.get("name")),
          tabId: tab.id,
          createdAt: FieldValue.serverTimestamp(),
        });
      }
    }
  });
});

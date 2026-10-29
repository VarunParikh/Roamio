import {
  FieldValue,
  getFirestore,
  type DocumentSnapshot,
  type Transaction,
} from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/https";
import { uidOf } from "../invites/invites";
import { joinCardId } from "../invites/join";

// The two actions on a lead's "<Name> joined your squad" card (spec UC-14).
// Task 19 adds demoting, leaving and handing over.

const db = () => getFirestore();

type Target = { adventure: DocumentSnapshot; memberUid: string };

/** Loads the adventure and checks the caller may act and the target is a plain member. */
async function loadTarget(
  tx: Transaction,
  data: { adventureId?: unknown; memberUid?: unknown } | undefined,
  uid: string,
  allowed: (adventure: DocumentSnapshot) => boolean,
  denied: string,
): Promise<Target> {
  const adventure = await tx.get(db().doc(`adventures/${String(data?.adventureId ?? "")}`));
  if (!adventure.exists || !allowed(adventure)) throw new HttpsError("permission-denied", denied);
  const memberUid = String(data?.memberUid ?? "");
  const isLead =
    adventure.get("leaderUid") === memberUid ||
    (adventure.get("coLeadUids") ?? []).includes(memberUid);
  if (!(adventure.get("memberUids") ?? []).includes(memberUid) || isLead) {
    throw new HttpsError("failed-precondition", "That person isn't a member of this squad.");
  }
  return { adventure, memberUid };
}

/** Clears every lead's join card for this member once someone has acted on it. */
function clearJoinCards(tx: Transaction, { adventure, memberUid }: Target) {
  const leads: string[] = [adventure.get("leaderUid"), ...(adventure.get("coLeadUids") ?? [])];
  for (const lead of leads) {
    tx.delete(db().doc(`users/${lead}/notifications/${joinCardId(adventure.id, memberUid)}`));
  }
}

/** The Squad Leader promotes a member to Co-squad Lead (spec UC-15). */
export const makeCoLead = onCall(async (request) => {
  const uid = uidOf(request);
  await db().runTransaction(async (tx) => {
    const target = await loadTarget(
      tx,
      request.data,
      uid,
      (a) => a.get("leaderUid") === uid,
      "Only the squad leader can make someone a co-lead.",
    );
    const ref = target.adventure.ref;
    clearJoinCards(tx, target);
    tx.update(ref, { coLeadUids: FieldValue.arrayUnion(target.memberUid) });
    tx.set(ref.collection("members").doc(target.memberUid), { role: "co_lead" }, { merge: true });
    tx.create(ref.collection("activity").doc(), {
      type: "co_lead_added",
      actorUid: uid,
      subject: target.memberUid,
      createdAt: FieldValue.serverTimestamp(),
    });
  });
  return { ok: true };
});

/** Whether a member pays for or shares in any tab, so must be kept as Left (spec UC-16). */
async function hasTabHistory(tx: Transaction, { adventure, memberUid }: Target): Promise<boolean> {
  if (adventure.get("hasTabs") !== true) return false;
  const tabs = await tx.get(adventure.ref.collection("tabs").select("payers", "participants"));
  return tabs.docs.some(
    (tab) =>
      (tab.get("participants") ?? []).includes(memberUid) ||
      (tab.get("payers") ?? []).some((p: { id: string }) => p.id === memberUid),
  );
}

/** A lead removes a member; anyone with tab history is marked Left instead (spec UC-16). */
export const removeMember = onCall(async (request) => {
  const uid = uidOf(request);
  await db().runTransaction(async (tx) => {
    const target = await loadTarget(
      tx,
      request.data,
      uid,
      (a) => a.get("leaderUid") === uid || (a.get("coLeadUids") ?? []).includes(uid),
      "Only the squad leader or a co-lead can remove someone.",
    );
    const keep = await hasTabHistory(tx, target);
    const ref = target.adventure.ref;
    const member = ref.collection("members").doc(target.memberUid);
    clearJoinCards(tx, target);
    tx.update(ref, { memberUids: FieldValue.arrayRemove(target.memberUid) });
    if (keep) tx.set(member, { status: "left" }, { merge: true });
    else tx.delete(member);
    tx.create(ref.collection("activity").doc(), {
      type: "member_removed",
      actorUid: uid,
      subject: target.memberUid,
      createdAt: FieldValue.serverTimestamp(),
    });
  });
  return { ok: true };
});

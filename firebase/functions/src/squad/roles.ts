import {
  FieldValue,
  getFirestore,
  type DocumentSnapshot,
  type Transaction,
} from "firebase-admin/firestore";
import { HttpsError, onCall, type CallableRequest } from "firebase-functions/https";
import { activeUidOf } from "../invites/invites";
import { joinCardId } from "../invites/join";

// Squad roles (spec UC-14 to UC-17). The Squad Leader manages leadership;
// co-leads have the same rights otherwise, so they can remove plain members.

const db = () => getFirestore();

type Squad = {
  adventure: DocumentSnapshot;
  leader: string;
  coLeads: string[];
  members: string[];
};

const notMember = () =>
  new HttpsError("failed-precondition", "That person isn't a member of this squad.");
const leaderOnly = (what: string) =>
  new HttpsError("permission-denied", `Only the squad leader can ${what}.`);

export async function loadSquad(tx: Transaction, adventureId: unknown): Promise<Squad> {
  const adventure = await tx.get(db().doc(`adventures/${String(adventureId ?? "")}`));
  if (!adventure.exists) throw new HttpsError("not-found", "This adventure no longer exists.");
  return {
    adventure,
    leader: adventure.get("leaderUid"),
    coLeads: adventure.get("coLeadUids") ?? [],
    members: adventure.get("memberUids") ?? [],
  };
}

function activity(tx: Transaction, squad: Squad, type: string, actorUid: string, subject: string) {
  tx.create(squad.adventure.ref.collection("activity").doc(), {
    type,
    actorUid,
    subject,
    createdAt: FieldValue.serverTimestamp(),
  });
}

/** Clears every lead's join card for this member once someone has acted on it. */
function clearJoinCards(tx: Transaction, squad: Squad, memberUid: string) {
  for (const lead of [squad.leader, ...squad.coLeads]) {
    tx.delete(db().doc(`users/${lead}/notifications/${joinCardId(squad.adventure.id, memberUid)}`));
  }
}

/** Whether a member pays for or shares in any tab, so must be kept as Left (spec UC-16). */
async function hasTabHistory(tx: Transaction, squad: Squad, memberUid: string): Promise<boolean> {
  if (squad.adventure.get("hasTabs") !== true) return false;
  const tabs = await tx.get(
    squad.adventure.ref.collection("tabs").select("payers", "participants"),
  );
  return tabs.docs.some(
    (tab) =>
      (tab.get("participants") ?? []).includes(memberUid) ||
      (tab.get("payers") ?? []).some((p: { id: string }) => p.id === memberUid),
  );
}

/** Takes someone out of the squad: Left if they have tab history, otherwise gone. */
export async function dropMember(
  tx: Transaction,
  squad: Squad,
  memberUid: string,
  actorUid: string,
  type: string,
) {
  const keep = await hasTabHistory(tx, squad, memberUid);
  const ref = squad.adventure.ref;
  const member = ref.collection("members").doc(memberUid);
  clearJoinCards(tx, squad, memberUid);
  // A budget only makes sense inside the squad, so it goes with the member.
  tx.delete(ref.collection("budgets").doc(memberUid));
  tx.update(ref, {
    memberUids: FieldValue.arrayRemove(memberUid),
    coLeadUids: FieldValue.arrayRemove(memberUid),
    // Lets them still find it for a data download (spec UC-29).
    ...(keep ? { leftUids: FieldValue.arrayUnion(memberUid) } : {}),
  });
  if (keep) tx.set(member, { role: "member", status: "left" }, { merge: true });
  else tx.delete(member);
  activity(tx, squad, type, actorUid, memberUid);
}

/** Runs [body] in a transaction with the caller's uid and the squad. */
function squadAction(
  body: (tx: Transaction, squad: Squad, uid: string, memberUid: string) => Promise<void> | void,
) {
  return onCall(async (request: CallableRequest) => {
    const uid = await activeUidOf(request);
    await db().runTransaction(async (tx) => {
      const squad = await loadSquad(tx, request.data?.adventureId);
      await body(tx, squad, uid, String(request.data?.memberUid ?? ""));
    });
    return { ok: true };
  });
}

/** The Squad Leader promotes a member to Co-squad Lead (spec UC-15). */
export const makeCoLead = squadAction((tx, squad, uid, memberUid) => {
  if (squad.leader !== uid) throw leaderOnly("make someone a co-lead");
  if (!squad.members.includes(memberUid) || memberUid === squad.leader) throw notMember();
  if (squad.coLeads.includes(memberUid)) return;
  const ref = squad.adventure.ref;
  clearJoinCards(tx, squad, memberUid);
  tx.update(ref, { coLeadUids: FieldValue.arrayUnion(memberUid) });
  tx.set(ref.collection("members").doc(memberUid), { role: "co_lead" }, { merge: true });
  activity(tx, squad, "co_lead_added", uid, memberUid);
});

/** The Squad Leader turns a co-lead back into a member (spec UC-15). */
export const demoteCoLead = squadAction((tx, squad, uid, memberUid) => {
  if (squad.leader !== uid) throw leaderOnly("change co-leads");
  if (!squad.coLeads.includes(memberUid)) {
    throw new HttpsError("failed-precondition", "That person isn't a co-lead.");
  }
  const ref = squad.adventure.ref;
  tx.update(ref, { coLeadUids: FieldValue.arrayRemove(memberUid) });
  tx.set(ref.collection("members").doc(memberUid), { role: "member" }, { merge: true });
  activity(tx, squad, "co_lead_removed", uid, memberUid);
});

/**
 * A lead removes someone (spec UC-16). The leader can remove anyone else;
 * co-leads only plain members. Nobody removes themselves: that's leaving.
 */
export const removeMember = squadAction(async (tx, squad, uid, memberUid) => {
  const isLeader = squad.leader === uid;
  if (!isLeader && !squad.coLeads.includes(uid)) {
    throw new HttpsError(
      "permission-denied",
      "Only the squad leader or a co-lead can remove someone.",
    );
  }
  if (!squad.members.includes(memberUid) || memberUid === squad.leader || memberUid === uid) {
    throw notMember();
  }
  if (!isLeader && squad.coLeads.includes(memberUid)) {
    throw leaderOnly("remove a co-lead");
  }
  await dropMember(tx, squad, memberUid, uid, "member_removed");
});

/**
 * The caller leaves (spec UC-16, UC-17). The Squad Leader must hand over
 * first; if they're the only one left, leaving archives the adventure.
 */
export const leaveAdventure = squadAction(async (tx, squad, uid) => {
  if (!squad.members.includes(uid)) {
    throw new HttpsError("failed-precondition", "You're not in this squad.");
  }
  if (squad.leader === uid) {
    if (squad.members.length > 1) {
      throw new HttpsError(
        "failed-precondition",
        "Make someone else squad leader before you leave.",
      );
    }
  }
  // dropMember reads tabs, and a transaction must read before it writes.
  await dropMember(tx, squad, uid, uid, "member_left");
  if (squad.leader === uid) {
    tx.update(squad.adventure.ref, { archived: true, archivedAt: FieldValue.serverTimestamp() });
  }
});

/** The Squad Leader hands leadership to another member and becomes a co-lead (spec UC-17). */
export const handOverLeadership = squadAction((tx, squad, uid, memberUid) => {
  if (squad.leader !== uid) throw leaderOnly("hand over leadership");
  if (!squad.members.includes(memberUid) || memberUid === uid) throw notMember();
  const ref = squad.adventure.ref;
  tx.update(ref, {
    leaderUid: memberUid,
    coLeadUids: [...squad.coLeads.filter((c) => c !== memberUid), uid],
  });
  tx.set(
    ref.collection("members").doc(memberUid),
    { role: "leader", status: "active" },
    { merge: true },
  );
  tx.set(
    ref.collection("members").doc(uid),
    { role: "co_lead", status: "active" },
    { merge: true },
  );
  activity(tx, squad, "leader_changed", uid, memberUid);
});

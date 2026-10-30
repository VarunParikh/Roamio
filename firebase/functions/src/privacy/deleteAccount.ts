import { getAuth } from "firebase-admin/auth";
import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";
import { HttpsError, onCall } from "firebase-functions/https";
import { deleteUserCompletely } from "../auth/deleteUser";
import { uidOf } from "../invites/invites";
import { dropMember, loadSquad } from "../squad/roles";

// Erasure (spec §8): profile, photos, budgets and sign-in go; tabs keep the
// person's id so every balance stays right and the app shows "Deleted user".

const db = () => getFirestore();

export type EraseDeps = {
  /** Deletes the person's profile photos from Cloud Storage. */
  removeAvatars: (uid: string) => Promise<void>;
  /** A parent has accepted that their linked children stay (spec §7.5). */
  confirmLinkedChildren?: boolean;
  /**
   * For a child whose parent said no or withdrew consent: a squad they lead
   * passes to a co-lead (or else the longest-listed member) instead of
   * blocking the deletion, which they can't do themselves (spec §7.3).
   */
  handOverLeadership?: boolean;
};

const leadsOthers = (uid: string, leader: string, members: string[]) =>
  leader === uid && members.length > 1;
const handOverFirst = (name: unknown) =>
  new HttpsError(
    "failed-precondition",
    `Make someone else squad leader of ${name} before you delete your account.`,
  );

export async function removeAvatarFiles(uid: string): Promise<void> {
  await getStorage()
    .bucket()
    .deleteFiles({ prefix: `users/${uid}/`, force: true });
}

/** Erases one person's account. Safe to run again if it stops part-way. */
export async function eraseAccount(uid: string, deps: EraseDeps): Promise<void> {
  const memberships = await db()
    .collection("adventures")
    .where("memberUids", "array-contains", uid)
    .get();

  // Leading a squad that others are in needs a hand-over first.
  for (const adventure of memberships.docs) {
    if (
      !deps.handOverLeadership &&
      leadsOthers(uid, adventure.get("leaderUid"), adventure.get("memberUids") ?? [])
    ) {
      throw handOverFirst(adventure.get("name"));
    }
  }
  const children = await db()
    .collection("parentalConsents")
    .where("parentUid", "==", uid)
    .where("status", "==", "granted")
    .get();
  if (!children.empty && !deps.confirmLinkedChildren) {
    throw new HttpsError(
      "failed-precondition",
      "Your linked children keep their accounts. Confirm to delete yours; you can withdraw their consent from this app first.",
    );
  }

  // Leave every squad the way leaving does: Left if on a tab, otherwise gone.
  for (const adventure of memberships.docs) {
    await db().runTransaction(async (tx) => {
      const squad = await loadSquad(tx, adventure.id);
      if (!squad.members.includes(uid)) return;
      // Checked again here: someone may have joined since the check above.
      const handOver = leadsOthers(uid, squad.leader, squad.members);
      if (handOver && !deps.handOverLeadership) throw handOverFirst(squad.adventure.get("name"));
      await dropMember(tx, squad, uid, uid, "member_left");
      if (handOver) {
        const next = squad.coLeads[0] ?? squad.members.filter((m) => m !== uid)[0];
        tx.update(squad.adventure.ref, {
          leaderUid: next,
          coLeadUids: squad.coLeads.filter((c) => c !== next),
        });
        tx.set(
          squad.adventure.ref.collection("members").doc(next),
          { role: "leader", status: "active" },
          { merge: true },
        );
        tx.create(squad.adventure.ref.collection("activity").doc(), {
          type: "leader_changed",
          actorUid: uid,
          subject: next,
          createdAt: FieldValue.serverTimestamp(),
        });
      } else if (squad.leader === uid) {
        tx.update(squad.adventure.ref, {
          archived: true,
          archivedAt: FieldValue.serverTimestamp(),
        });
      }
    });
  }

  await deps.removeAvatars(uid);
  await db().collection("auditLog").add({
    actorUid: uid,
    action: "account_deleted",
    target: uid,
    at: FieldValue.serverTimestamp(),
  });
  await deleteUserCompletely(uid);
  // The auth user may already be gone on a re-run; deleteUserCompletely allows that.
  await getAuth()
    .getUser(uid)
    .then(
      () => getAuth().deleteUser(uid),
      () => undefined,
    );
}

/** The caller deletes their own account (spec UC-29). */
export const deleteMyAccount = onCall(async (request) => {
  const uid = uidOf(request);
  await eraseAccount(uid, {
    removeAvatars: removeAvatarFiles,
    confirmLinkedChildren: request.data?.confirmLinkedChildren === true,
  });
  return { ok: true };
});

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
};

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
    if (adventure.get("leaderUid") === uid && (adventure.get("memberUids") ?? []).length > 1) {
      throw new HttpsError(
        "failed-precondition",
        `Make someone else squad leader of ${adventure.get("name")} before you delete your account.`,
      );
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
      await dropMember(tx, squad, uid, uid, "member_left");
      if (squad.leader === uid) {
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

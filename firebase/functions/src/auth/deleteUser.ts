import { getAuth } from "firebase-admin/auth";
import { getFirestore } from "firebase-admin/firestore";

/** Removes a person's auth user, profile and private records entirely. */
export async function deleteUserCompletely(uid: string): Promise<void> {
  const db = getFirestore();
  await db.recursiveDelete(db.doc(`users/${uid}`));
  await getAuth()
    .deleteUser(uid)
    .catch((e: { code?: string }) => {
      if (e.code !== "auth/user-not-found") throw e;
    });
}

import { getAuth } from "firebase-admin/auth";
import { getFirestore } from "firebase-admin/firestore";

/** Removes a person's auth user, profile, private records and reader list entirely. */
export async function deleteUserCompletely(uid: string): Promise<void> {
  const db = getFirestore();
  await db.recursiveDelete(db.doc(`users/${uid}`));
  // Who could see the profile (S3b); nothing left to see.
  await db.doc(`profileReaders/${uid}`).delete();
  await getAuth()
    .deleteUser(uid)
    .catch((e: { code?: string }) => {
      if (e.code !== "auth/user-not-found") throw e;
    });
}

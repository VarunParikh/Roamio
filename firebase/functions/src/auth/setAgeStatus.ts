import { getAuth } from "firebase-admin/auth";
import { getFirestore } from "firebase-admin/firestore";
import { logger } from "firebase-functions";
import { onDocumentCreated } from "firebase-functions/firestore";
import { bracketFor, todayInIndia } from "./age";

/**
 * Sets the server-only `ageStatus` from the date of birth a new account gives
 * (spec UC-4, §7). Under-13s are removed entirely; an impossible date removes
 * just the account record so the app asks for it again.
 */
export const setAgeStatus = onDocumentCreated("users/{uid}/private/account", async (event) => {
  const snapshot = event.data;
  if (!snapshot || snapshot.get("ageStatus") !== undefined) return;
  const uid = event.params.uid;
  const bracket = bracketFor(String(snapshot.get("dob") ?? ""), todayInIndia(new Date()));

  switch (bracket) {
    case "adult":
    case "minor":
      await snapshot.ref.update({ ageStatus: bracket === "adult" ? "adult" : "minor_pending" });
      return;
    case "invalid":
      await snapshot.ref.delete();
      return;
    case "underThirteen":
      logger.info("Removing under-13 sign-up", { uid });
      await getFirestore().recursiveDelete(getFirestore().doc(`users/${uid}`));
      await getAuth()
        .deleteUser(uid)
        .catch((e: { code?: string }) => {
          if (e.code !== "auth/user-not-found") throw e;
        });
  }
});

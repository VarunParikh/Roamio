import { logger } from "firebase-functions";
import { onDocumentCreated } from "firebase-functions/firestore";
import { bracketFor, todayInIndia } from "./age";
import { deleteUserCompletely } from "./deleteUser";

const NOT_FOUND = 5; // gRPC status code

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
      await snapshot.ref
        .update({ ageStatus: bracket === "adult" ? "adult" : "minor_pending" })
        // The record may already be gone (e.g. the account was deleted at once).
        .catch((e: { code?: number }) => {
          if (e.code !== NOT_FOUND) throw e;
        });
      return;
    case "invalid":
      await snapshot.ref.delete();
      return;
    case "underThirteen":
      logger.info("Removing under-13 sign-up", { uid });
      await deleteUserCompletely(uid);
  }
});

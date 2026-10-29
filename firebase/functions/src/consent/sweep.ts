import { getFirestore, type Timestamp } from "firebase-admin/firestore";
import { logger } from "firebase-functions";
import { onSchedule } from "firebase-functions/scheduler";
import { deleteChild, emailParent } from "./consent";
import { nextConsentAction } from "./rules";
import { hashToken, newToken } from "./token";

/**
 * Reminds parents on day 3 and 6 and deletes unanswered minors on day 7
 * (spec §7.1 step 3). Only a token's hash is stored, so a reminder carries
 * a fresh link that replaces the previous one.
 */
export async function runConsentSweep(now: Date): Promise<void> {
  const open = await getFirestore()
    .collection("parentalConsents")
    .where("status", "==", "requested")
    .get();

  for (const doc of open.docs) {
    const action = nextConsentAction(
      {
        status: doc.get("status"),
        requestedAt: (doc.get("requestedAt") as Timestamp).toMillis(),
        remindersSent: doc.get("remindersSent") ?? 0,
      },
      now.getTime(),
    );
    if (action === "remind") {
      const token = newToken();
      await doc.ref.update({
        tokenHash: hashToken(token),
        remindersSent: (doc.get("remindersSent") ?? 0) + 1,
      });
      await emailParent(doc.get("parentEmail"), doc.id, token, true);
    } else if (action === "expire") {
      logger.info("Parental consent expired", { childUid: doc.id });
      await doc.ref.update({ status: "expired", tokenHash: null });
      await deleteChild(doc.id, "a parent or guardian didn't respond within 7 days");
    }
  }
}

export const consentSweep = onSchedule(
  { schedule: "every day 09:00", timeZone: "Asia/Kolkata" },
  () => runConsentSweep(new Date()),
);

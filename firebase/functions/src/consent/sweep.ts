import { getFirestore, type Timestamp } from "firebase-admin/firestore";
import { logger } from "firebase-functions";
import { onSchedule } from "firebase-functions/scheduler";
import { purgeOldAuditLog } from "../privacy/auditRetention";
import { deleteChild, emailParent } from "./consent";
import { nextConsentAction } from "./rules";
import { hashToken, newToken } from "./token";

/**
 * Reminds parents on day 3 and 6, deletes unanswered minors on day 7
 * (spec §7.1 step 3) and deletes withdrawn minors after 48 hours (§7.3). Only a token's hash is stored, so a reminder carries
 * a fresh link that replaces the previous one.
 */
export async function runConsentSweep(now: Date): Promise<void> {
  const open = await getFirestore()
    .collection("parentalConsents")
    .where("status", "in", ["requested", "withdrawn"])
    .get();

  for (const doc of open.docs) {
    const action = nextConsentAction(
      {
        status: doc.get("status"),
        requestedAt: (doc.get("requestedAt") as Timestamp).toMillis(),
        remindersSent: doc.get("remindersSent") ?? 0,
        withdrawnAt: (doc.get("withdrawnAt") as Timestamp | undefined)?.toMillis(),
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
    } else if (action === "delete") {
      logger.info("Deleting child after consent withdrawal", { childUid: doc.id });
      await doc.ref.update({ status: "closed" });
      await deleteChild(doc.id, "your parent or guardian withdrew their consent");
    }
  }
}

/**
 * The daily privacy jobs. The audit-log clean-up (spec §8) rides along here
 * rather than having its own job: the project's three schedules are
 * Cloud Scheduler's free allowance.
 */
export async function runDailySweep(now: Date): Promise<void> {
  await runConsentSweep(now);
  const removed = await purgeOldAuditLog(now);
  if (removed > 0) logger.info("Removed audit log entries older than a year", { removed });
}

export const consentSweep = onSchedule(
  { schedule: "every day 09:00", timeZone: "Asia/Kolkata" },
  () => runDailySweep(new Date()),
);

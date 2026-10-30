import { getFirestore, type QueryDocumentSnapshot, type Timestamp } from "firebase-admin/firestore";
import { logger } from "firebase-functions";
import { onSchedule } from "firebase-functions/scheduler";
import { purgeOldAuditLog } from "../privacy/auditRetention";
import { type EraseDeps, removeAvatarFiles } from "../privacy/deleteAccount";
import { deleteChild, emailParent } from "./consent";
import { nextConsentAction } from "./rules";
import { hashToken, newToken } from "./token";
import { serverConfig } from "../config";

/**
 * Reminds parents on day 3 and 6, deletes unanswered minors on day 7
 * (spec §7.1 step 3) and deletes withdrawn minors after 48 hours (§7.3). Only a token's hash is stored, so a reminder carries
 * a fresh link that replaces the previous one.
 */
export async function runConsentSweep(
  now: Date,
  photos: Pick<EraseDeps, "removeAvatars"> = { removeAvatars: removeAvatarFiles },
): Promise<void> {
  const open = await getFirestore()
    .collection("parentalConsents")
    .where("status", "in", ["requested", "withdrawn"])
    .get();
  const { consentDays } = await serverConfig();

  for (const doc of open.docs) {
    // One failure must not stop the others; it is tried again tomorrow.
    try {
      await sweepOne(doc, now, consentDays, photos.removeAvatars);
    } catch (e) {
      logger.error("Consent sweep failed for one request", {
        childUid: doc.id,
        error: String(e),
      });
    }
  }
}

async function sweepOne(
  doc: QueryDocumentSnapshot,
  now: Date,
  consentDays: number,
  removeAvatars: EraseDeps["removeAvatars"],
): Promise<void> {
  const action = nextConsentAction(
    {
      status: doc.get("status"),
      requestedAt: (doc.get("requestedAt") as Timestamp).toMillis(),
      remindersSent: doc.get("remindersSent") ?? 0,
      withdrawnAt: (doc.get("withdrawnAt") as Timestamp | undefined)?.toMillis(),
    },
    now.getTime(),
    consentDays,
  );
  // Deleting comes before the status that ends the request, so a deletion
  // that stops part-way is picked up again by the next sweep.
  if (action === "remind") {
    const token = newToken();
    await doc.ref.update({
      tokenHash: hashToken(token),
      remindersSent: (doc.get("remindersSent") ?? 0) + 1,
    });
    await emailParent(doc.get("parentEmail"), doc.id, token, true);
  } else if (action === "expire") {
    logger.info("Parental consent expired", { childUid: doc.id });
    await deleteChild(doc.id, "a parent or guardian didn't respond within 7 days", removeAvatars);
    await doc.ref.update({ status: "expired", tokenHash: null });
  } else if (action === "delete") {
    logger.info("Deleting child after consent withdrawal", { childUid: doc.id });
    await deleteChild(doc.id, "your parent or guardian withdrew their consent", removeAvatars);
    await doc.ref.update({ status: "closed" });
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

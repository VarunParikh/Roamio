import { getFirestore, Timestamp } from "firebase-admin/firestore";

// The audit log is kept for one year (spec §8). Runs daily inside
// consentSweep (runDailySweep), so it needs no schedule of its own.

/** Deletes audit entries more than a year older than [now]; returns how many. */
export async function purgeOldAuditLog(now: Date, batchSize = 400): Promise<number> {
  const cutoff = new Date(now);
  cutoff.setUTCFullYear(cutoff.getUTCFullYear() - 1);
  const db = getFirestore();
  let removed = 0;
  for (;;) {
    const old = await db
      .collection("auditLog")
      .where("at", "<", Timestamp.fromDate(cutoff))
      .limit(batchSize)
      .get();
    if (old.empty) return removed;
    const batch = db.batch();
    old.docs.forEach((d) => batch.delete(d.ref));
    await batch.commit();
    removed += old.size;
  }
}

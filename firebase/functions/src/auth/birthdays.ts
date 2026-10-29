import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { logger } from "firebase-functions";
import { HttpsError, onCall } from "firebase-functions/https";
import { onSchedule } from "firebase-functions/scheduler";
import { queueMail } from "../mail";
import { bracketFor, todayInIndia } from "./age";

/** Bumped whenever the adult privacy notice text changes. */
export const ADULT_NOTICE_VERSION = "2026-10";

/**
 * Minors who have turned 18 (spec §7.4): the parent link is removed, the
 * parent is told, and the account waits until its owner accepts the adult
 * privacy notice. An unanswered consent request is simply closed.
 */
export async function runBirthdaySweep(now: Date): Promise<void> {
  const db = getFirestore();
  const today = todayInIndia(now);
  const minors = await db
    .collectionGroup("private")
    .where("ageStatus", "in", ["minor_active", "minor_pending"])
    .get();

  for (const account of minors.docs) {
    const user = account.ref.parent.parent;
    if (account.id !== "account" || !user) continue;
    if (bracketFor(String(account.get("dob")), today) !== "adult") continue;

    const uid = user.id;
    const consent = db.doc(`parentalConsents/${uid}`);
    const consentSnap = await consent.get();
    const wasActive = account.get("ageStatus") === "minor_active";

    const batch = db.batch();
    batch.update(account.ref, {
      ageStatus: "adult_unconfirmed",
      parentUid: FieldValue.delete(),
    });
    if (consentSnap.exists) {
      batch.update(consent, {
        status: wasActive ? "aged_out" : "closed",
        tokenHash: FieldValue.delete(),
      });
    }
    await batch.commit();
    logger.info("Minor turned 18", { uid });

    const parentEmail = consentSnap.get("parentEmail");
    if (wasActive && parentEmail) {
      await queueMail(
        parentEmail,
        "Your consent for Roamio has ended",
        "Your child has turned 18, so they now manage their own Roamio account " +
          "and your consent is no longer needed. They no longer appear under " +
          "You → Linked children.",
      );
    }
  }
}

export const birthdaySweep = onSchedule(
  { schedule: "every day 00:30", timeZone: "Asia/Kolkata" },
  () => runBirthdaySweep(new Date()),
);

/** A newly-18 account owner accepts the adult privacy notice (spec §7.4). */
export const acceptAdultNotice = onCall(async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Sign in first.");
  const account = getFirestore().doc(`users/${request.auth.uid}/private/account`);
  if ((await account.get()).get("ageStatus") !== "adult_unconfirmed") {
    throw new HttpsError("failed-precondition", "Nothing to accept.");
  }
  await account.update({
    ageStatus: "adult",
    noticeVersion: ADULT_NOTICE_VERSION,
    adultNoticeAcceptedAt: FieldValue.serverTimestamp(),
  });
  return { ok: true };
});

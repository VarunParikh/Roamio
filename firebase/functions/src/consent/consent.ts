import { getAuth } from "firebase-admin/auth";
import { FieldValue, getFirestore, Timestamp } from "firebase-admin/firestore";
import { HttpsError, onCall, type CallableRequest } from "firebase-functions/https";
import { todayInIndia } from "../auth/age";
import { deleteUserCompletely } from "../auth/deleteUser";
import { queueMail, siteUrl } from "../mail";
import { canRequestAgain, isExpired, type RequestCounter, WITHDRAW_GRACE_HOURS } from "./rules";
import { hashToken, newToken, tokensMatch } from "./token";

/** Bumped whenever the child-specific privacy notice text changes. */
export const CHILD_NOTICE_VERSION = "2026-10";
const EMAIL = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;

const consentDoc = (childUid: string) => getFirestore().doc(`parentalConsents/${childUid}`);
const accountDoc = (uid: string) => getFirestore().doc(`users/${uid}/private/account`);

function signedIn(request: CallableRequest): { uid: string; email?: string; verified: boolean } {
  if (!request.auth) throw new HttpsError("unauthenticated", "Sign in first.");
  const token = request.auth.token;
  return {
    uid: request.auth.uid,
    email: token.email?.toLowerCase(),
    verified: token.email_verified === true,
  };
}

async function ageStatusOf(uid: string): Promise<string | undefined> {
  return (await accountDoc(uid).get()).get("ageStatus");
}

async function firstNameOf(uid: string): Promise<string> {
  const name: string = (await getFirestore().doc(`users/${uid}`).get()).get("name") ?? "";
  return name.trim().split(/\s+/)[0] || "Your child";
}

export function consentLink(childUid: string, token: string): string {
  return `${siteUrl()}/consent?c=${encodeURIComponent(childUid)}&t=${token}`;
}

export async function emailParent(
  parentEmail: string,
  childUid: string,
  token: string,
  reminder = false,
): Promise<void> {
  const child = await firstNameOf(childUid);
  await queueMail(
    parentEmail,
    `${reminder ? "Reminder: " : ""}${child} wants to use Roamio`,
    `${child} has signed up to Roamio, an app for splitting travel costs with friends.\n\n` +
      `Because ${child} is under 18, they need a parent or guardian's consent first. ` +
      `Open this link to read what Roamio collects and to say yes or no:\n\n` +
      `${consentLink(childUid, token)}\n\n` +
      `The link works for 7 days from the first request and replaces any earlier link. ` +
      `If you don't answer, ${child}'s account and data are deleted.`,
  );
}

/** Child asks a parent or guardian for consent (spec §7.1 steps 2–3). */
export const requestParentalConsent = onCall(async (request) => {
  const child = signedIn(request);
  const data = (request.data ?? {}) as { parentEmail?: unknown; relationship?: unknown };
  const parentEmail = String(data.parentEmail ?? "")
    .trim()
    .toLowerCase();
  const relationship = String(data.relationship ?? "parent or guardian").slice(0, 30);

  if (!EMAIL.test(parentEmail)) throw new HttpsError("invalid-argument", "Enter a valid email.");
  if (parentEmail === child.email) {
    throw new HttpsError("invalid-argument", "Use a parent or guardian's email, not your own.");
  }
  if ((await ageStatusOf(child.uid)) !== "minor_pending") {
    throw new HttpsError("failed-precondition", "This account doesn't need parental consent.");
  }

  const token = newToken();
  const today = todayInIndia(new Date());
  await getFirestore().runTransaction(async (tx) => {
    const existing = await tx.get(consentDoc(child.uid));
    const counter = existing.get("requestsOn") as RequestCounter | undefined;
    if (!canRequestAgain(counter, today)) {
      throw new HttpsError("resource-exhausted", "You can send 3 requests a day. Try tomorrow.");
    }
    const count = counter?.day === today ? counter.count + 1 : 1;
    tx.set(consentDoc(child.uid), {
      childUid: child.uid,
      parentEmail,
      relationship,
      status: "requested",
      tokenHash: hashToken(token),
      // The 7 days run from the first request; a resend doesn't extend them.
      requestedAt:
        existing.get("status") === "requested" ? existing.get("requestedAt") : Timestamp.now(),
      remindersSent: existing.get("remindersSent") ?? 0,
      requestsOn: { day: today, count },
      noticeVersion: CHILD_NOTICE_VERSION,
    });
  });
  await emailParent(parentEmail, child.uid, token);
  return { ok: true };
});

type Decision = { childUid: string; token: string; decision?: string };

/** Loads an open request and checks the link token; shared by describe/decide. */
async function openRequest(data: Decision) {
  const snap = await consentDoc(String(data.childUid ?? "")).get();
  if (snap.get("status") !== "requested") {
    throw new HttpsError(
      "failed-precondition",
      "This request has already been answered or closed.",
    );
  }
  if (isExpired((snap.get("requestedAt") as Timestamp).toMillis(), Date.now())) {
    throw new HttpsError("failed-precondition", "This request has expired.");
  }
  if (!tokensMatch(String(data.token ?? ""), snap.get("tokenHash"))) {
    throw new HttpsError("permission-denied", "This link isn't valid. Use the newest email.");
  }
  return snap;
}

/** What the consent page shows the parent before they decide. */
export const describeConsentRequest = onCall(async (request) => {
  signedIn(request);
  const snap = await openRequest(request.data as Decision);
  return {
    childFirstName: await firstNameOf(snap.id),
    relationship: snap.get("relationship"),
    parentEmail: snap.get("parentEmail"),
  };
});

/**
 * A parent or guardian grants or declines (spec §7.1 steps 4–7). They must be
 * signed in to a verified Roamio adult account whose email the request was
 * sent to — reliable identity and age details held by Roamio (Rule 10).
 */
export const decideParentalConsent = onCall(async (request) => {
  const parent = signedIn(request);
  const data = request.data as Decision;
  if (data.decision !== "grant" && data.decision !== "decline") {
    throw new HttpsError("invalid-argument", "Decision must be grant or decline.");
  }
  if (parent.uid === data.childUid) {
    throw new HttpsError("permission-denied", "You can't give consent for yourself.");
  }
  const snap = await openRequest(data);
  if (!parent.verified || parent.email !== snap.get("parentEmail")) {
    throw new HttpsError(
      "permission-denied",
      "Sign in with the verified email address this request was sent to.",
    );
  }
  if ((await ageStatusOf(parent.uid)) !== "adult") {
    throw new HttpsError("permission-denied", "A guardian must be 18 or older.");
  }

  const childUid = snap.id;
  const db = getFirestore();
  await db.runTransaction(async (tx) => {
    const fresh = await tx.get(consentDoc(childUid));
    if (fresh.get("status") !== "requested") {
      throw new HttpsError("failed-precondition", "This request has already been answered.");
    }
    tx.update(consentDoc(childUid), {
      status: data.decision === "grant" ? "granted" : "declined",
      parentUid: parent.uid,
      decidedAt: FieldValue.serverTimestamp(),
      method: "verified_adult_roamio_account",
      tokenHash: FieldValue.delete(),
    });
    if (data.decision === "grant") {
      tx.update(accountDoc(childUid), { ageStatus: "minor_active", parentUid: parent.uid });
    }
  });

  if (data.decision === "decline") {
    await deleteChild(childUid, "your parent or guardian said no");
  }
  return { ok: true };
});

/** Tells the child why, then deletes their account and data (spec §7.1 step 7). */
export async function deleteChild(childUid: string, reason: string): Promise<void> {
  const email = await getAuth()
    .getUser(childUid)
    .then((u) => u.email)
    .catch(() => undefined);
  if (email) {
    await queueMail(
      email,
      "Your Roamio account has been closed",
      `We've deleted your Roamio account and its data because ${reason}. ` +
        `You're welcome to sign up again with a parent or guardian's consent.`,
    );
  }
  await deleteUserCompletely(childUid);
}

/**
 * The consenting parent withdraws consent (spec §7.3): the child's account is
 * frozen at once and deleted by the daily sweep after the grace period.
 */
export const withdrawParentalConsent = onCall(async (request) => {
  const parent = signedIn(request);
  const childUid = String((request.data as { childUid?: unknown })?.childUid ?? "");
  const snap = await consentDoc(childUid).get();
  if (snap.get("status") !== "granted" || snap.get("parentUid") !== parent.uid) {
    throw new HttpsError("permission-denied", "Only the parent who gave consent can withdraw it.");
  }
  const batch = getFirestore().batch();
  batch.update(consentDoc(childUid), {
    status: "withdrawn",
    withdrawnAt: FieldValue.serverTimestamp(),
  });
  batch.update(accountDoc(childUid), { ageStatus: "minor_frozen" });
  await batch.commit();

  const email = (await getAuth().getUser(childUid)).email;
  if (email) {
    await queueMail(
      email,
      "Your Roamio account is paused",
      "Your parent or guardian has withdrawn their consent, so your Roamio account is " +
        `paused and will be deleted in ${WITHDRAW_GRACE_HOURS} hours. ` +
        "Ask them if you think this is a mistake.",
    );
  }
  return { ok: true };
});

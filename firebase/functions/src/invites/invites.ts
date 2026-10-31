import {
  FieldValue,
  getFirestore,
  Timestamp,
  type DocumentSnapshot,
} from "firebase-admin/firestore";
import { HttpsError, onCall, onRequest } from "firebase-functions/https";
import { newCode, normaliseCode } from "./code";
import { serverConfig } from "../config";

const db = () => getFirestore();

export function uidOf(request: { auth?: { uid: string } }): string {
  if (!request.auth) throw new HttpsError("unauthenticated", "Sign in first.");
  return request.auth.uid;
}

/**
 * The caller's uid once their account is active: signed in and not waiting
 * for, or frozen out of, parental consent or the adult notice (spec §7).
 */
export async function activeUidOf(request: { auth?: { uid: string } }): Promise<string> {
  const uid = uidOf(request);
  const status = (await db().doc(`users/${uid}/private/account`).get()).get("ageStatus");
  if (status !== "adult" && status !== "minor_active") {
    throw new HttpsError("failed-precondition", "Your account can't do that right now.");
  }
  return uid;
}

/** Loads an adventure and checks the caller leads it. */
async function ledAdventure(adventureId: unknown, uid: string): Promise<DocumentSnapshot> {
  const snap = await db()
    .doc(`adventures/${String(adventureId ?? "")}`)
    .get();
  const isLead = snap.get("leaderUid") === uid || (snap.get("coLeadUids") ?? []).includes(uid);
  if (!snap.exists || !isLead) {
    throw new HttpsError("permission-denied", "Only the squad leader or a co-lead can do that.");
  }
  return snap;
}

const isUsable = (invite: DocumentSnapshot) =>
  invite.exists &&
  invite.get("revoked") !== true &&
  (invite.get("expiresAt") as Timestamp).toMillis() > Date.now();

async function firstNameOf(uid: string): Promise<string> {
  const name: string = (await db().doc(`users/${uid}`).get()).get("name") ?? "";
  return name.trim().split(/\s+/)[0] || "Your friend";
}

/**
 * The adventure's current invite code, creating one if there's none or it
 * has expired (spec UC-9). Leads and co-leads only.
 */
export const createInvite = onCall(async (request) => {
  const uid = await activeUidOf(request);
  const adventure = await ledAdventure(request.data?.adventureId, uid);

  const current = adventure.get("activeInviteCode") as string | undefined;
  if (current) {
    const invite = await db().doc(`invites/${current}`).get();
    if (isUsable(invite)) {
      return { code: current, expiresAt: (invite.get("expiresAt") as Timestamp).toMillis() };
    }
  }

  const { inviteDays } = await serverConfig();
  const expiresAt = Timestamp.fromMillis(Date.now() + inviteDays * 86_400_000);
  const leaderUid: string = adventure.get("leaderUid");
  const leaderName = await firstNameOf(leaderUid);
  // Invitees can't read the leader's profile, so the picture goes on the invite.
  const leaderCharacterId: string | null =
    (await db().doc(`users/${leaderUid}`).get()).get("characterId") ?? null;
  for (let attempt = 0; attempt < 5; attempt++) {
    const code = newCode();
    const created = await db()
      .doc(`invites/${code}`)
      .create({
        adventureId: adventure.id,
        adventureName: adventure.get("name"),
        countryCode: adventure.get("countryCode"),
        startDate: adventure.get("startDate"),
        endDate: adventure.get("endDate"),
        leaderName,
        leaderUid,
        leaderCharacterId,
        createdBy: uid,
        createdAt: FieldValue.serverTimestamp(),
        expiresAt,
        revoked: false,
      })
      .then(() => true)
      .catch((e: { code?: number }) => {
        if (e.code === 6) return false; // ALREADY_EXISTS: try another code
        throw e;
      });
    if (created) {
      await adventure.ref.update({ activeInviteCode: code });
      return { code, expiresAt: expiresAt.toMillis() };
    }
  }
  throw new HttpsError("internal", "Couldn't make an invite code. Try again.");
});

/** Stops the current link working; the next share makes a new one. */
export const revokeInvite = onCall(async (request) => {
  const uid = await activeUidOf(request);
  const adventure = await ledAdventure(request.data?.adventureId, uid);
  const current = adventure.get("activeInviteCode") as string | undefined;
  const batch = db().batch();
  if (current) batch.update(db().doc(`invites/${current}`), { revoked: true });
  batch.update(adventure.ref, { activeInviteCode: FieldValue.delete() });
  await batch.commit();
  return { ok: true };
});

export async function usableInvite(input: unknown): Promise<DocumentSnapshot> {
  const code = normaliseCode(String(input ?? ""));
  if (!code)
    throw new HttpsError("invalid-argument", "That doesn't look like a Roamio invite code.");
  return checkUsable(await db().doc(`invites/${code}`).get());
}

/** Throws the reason an invite can't be used, or returns it. */
export function checkUsable(invite: DocumentSnapshot): DocumentSnapshot {
  if (!invite.exists)
    throw new HttpsError("not-found", "We couldn't find that invite. Check the code.");
  if (invite.get("revoked") === true) {
    throw new HttpsError(
      "failed-precondition",
      "This invite link is no longer active. Ask for a new one.",
    );
  }
  if (!isUsable(invite)) {
    throw new HttpsError("failed-precondition", "This invite has expired. Ask for a new one.");
  }
  return invite;
}

/** What an invitee sees before joining (spec UC-12, UC-13). */
export const lookupInvite = onCall(async (request) => {
  uidOf(request);
  const invite = await usableInvite(request.data?.code);
  return {
    code: invite.id,
    adventureId: invite.get("adventureId"),
    adventureName: invite.get("adventureName"),
    leaderName: invite.get("leaderName"),
    leaderUid: invite.get("leaderUid") ?? null,
    leaderCharacterId: invite.get("leaderCharacterId") ?? null,
    countryCode: invite.get("countryCode"),
    startDate: invite.get("startDate"),
    endDate: invite.get("endDate"),
    expiresAt: (invite.get("expiresAt") as Timestamp).toMillis(),
  };
});

/**
 * Public preview for the invite web page (no sign-in): just the adventure
 * name and the leader's first name, for anyone holding a valid code.
 */
export const invitePreview = onRequest({ cors: true }, async (req, res) => {
  try {
    const invite = await usableInvite(req.query.code);
    res.json({
      code: invite.id,
      adventureName: invite.get("adventureName"),
      leaderName: invite.get("leaderName"),
    });
  } catch (e) {
    const status = e instanceof HttpsError && e.code === "invalid-argument" ? 400 : 404;
    res.status(status).json({ error: e instanceof HttpsError ? e.message : "Not found" });
  }
});

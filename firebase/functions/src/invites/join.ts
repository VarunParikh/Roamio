import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/https";
import { uidOf, usableInvite } from "./invites";

const db = () => getFirestore();

/** One "<Name> joined your squad" card per lead, newcomer and adventure. */
export const joinCardId = (adventureId: string, memberUid: string) =>
  `${adventureId}_joined_${memberUid}`;

/** Today as yyyy-mm-dd in UTC, which is never earlier than the joiner's local date in Asia. */
const todayUtc = () => new Date().toISOString().slice(0, 10);

/**
 * Adds the caller to an invite's adventure as a Member and gives every lead
 * an in-app card (spec UC-13, UC-14). Joining twice is harmless.
 */
export const joinAdventure = onCall(async (request) => {
  const uid = uidOf(request);
  const ageStatus = (await db().doc(`users/${uid}/private/account`).get()).get("ageStatus");
  if (ageStatus !== "adult" && ageStatus !== "minor_active") {
    throw new HttpsError(
      "failed-precondition",
      "You can join a squad once a parent has said OK to your account.",
    );
  }
  const invite = await usableInvite(request.data?.code);
  const adventureRef = db().doc(`adventures/${invite.get("adventureId")}`);
  const memberName: string = (await db().doc(`users/${uid}`).get()).get("name") ?? "Someone";

  return db().runTransaction(async (tx) => {
    const adventure = await tx.get(adventureRef);
    if (!adventure.exists) throw new HttpsError("not-found", "This adventure no longer exists.");
    const memberUids: string[] = adventure.get("memberUids") ?? [];
    if (memberUids.includes(uid)) return { adventureId: adventure.id, alreadyMember: true };
    if (adventure.get("endDate") < todayUtc()) {
      throw new HttpsError("failed-precondition", "This adventure has already ended.");
    }

    tx.update(adventureRef, { memberUids: FieldValue.arrayUnion(uid) });
    tx.set(adventureRef.collection("members").doc(uid), {
      role: "member",
      status: "active",
      joinedAt: FieldValue.serverTimestamp(),
    });
    tx.create(adventureRef.collection("activity").doc(), {
      type: "member_joined",
      actorUid: uid,
      subject: uid,
      createdAt: FieldValue.serverTimestamp(),
    });
    const leads: string[] = [adventure.get("leaderUid"), ...(adventure.get("coLeadUids") ?? [])];
    for (const lead of leads) {
      tx.set(db().doc(`users/${lead}/notifications/${joinCardId(adventure.id, uid)}`), {
        type: "member_joined",
        adventureId: adventure.id,
        adventureName: adventure.get("name"),
        memberUid: uid,
        memberName,
        createdAt: FieldValue.serverTimestamp(),
      });
    }
    return { adventureId: adventure.id, alreadyMember: false };
  });
});

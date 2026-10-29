import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { onDocumentWritten } from "firebase-functions/firestore";
import { sendPush } from "../notify/push";

// "Mark as settled" (spec UC-26a): a record that one person paid another
// outside the app. The activity log shows it and any undo; the other
// member involved gets a push.

type Settlement = { from: string; to: string; recordedBy: string };

/** Members to notify: the parties other than whoever recorded it; pals have no app. */
export function notifyFor(s: Settlement, memberUids: string[]): string[] {
  return [s.from, s.to].filter((id) => id !== s.recordedBy && memberUids.includes(id));
}

export const settlementActivity = onDocumentWritten(
  "adventures/{aid}/settlements/{sid}",
  async (event) => {
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();
    if (!after) return;
    const adventureRef = getFirestore().doc(`adventures/${event.params.aid}`);
    const log = (type: string, actorUid: string) =>
      adventureRef.collection("activity").add({
        type,
        actorUid,
        subject: event.params.sid,
        createdAt: FieldValue.serverTimestamp(),
      });

    if (!before) {
      await log("settlement_recorded", after.recordedBy);
      const adventure = await adventureRef.get();
      const names = await Promise.all(
        [after.from, after.to].map(async (id: string) => {
          const user = await getFirestore().doc(`users/${id}`).get();
          if (user.exists) return String(user.get("name") ?? "Someone");
          const pal = await adventureRef.collection("pals").doc(id).get();
          return String(pal.get("nickname") ?? "Someone");
        }),
      );
      await sendPush(notifyFor(after as Settlement, adventure.get("memberUids") ?? []), {
        title: `${names[0]} paid ${names[1]}`,
        body: `Marked as settled in ${adventure.get("name")}`,
        data: { type: "settlement", adventureId: event.params.aid },
      });
    } else if (before.undone !== true && after.undone === true) {
      await log("settlement_undone", after.undoneBy);
    }
  },
);

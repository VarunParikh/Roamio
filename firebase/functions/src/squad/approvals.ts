import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { onDocumentWritten } from "firebase-functions/firestore";

const db = () => getFirestore();

type Squad = { leaderUid?: string; coLeadUids?: string[] };

const adminsOf = (s: Squad | undefined) =>
  s?.leaderUid ? [s.leaderUid, ...(s.coLeadUids ?? [])] : [];

/**
 * When a squad is left with one admin, that admin's own waiting tabs have
 * nobody to approve them, so they're approved (spec UC-21a). Other people's
 * tabs still wait for that admin.
 */
export const approveStrandedTabs = onDocumentWritten("adventures/{aid}", async (event) => {
  const before = event.data?.before?.data() as Squad | undefined;
  const after = event.data?.after?.data() as Squad | undefined;
  const admins = adminsOf(after);
  if (!before || admins.length !== 1) return;
  if (adminsOf(before).join() === admins.join()) return;
  const stranded = await db()
    .collection(`adventures/${event.params.aid}/tabs`)
    .where("createdBy", "==", admins[0])
    .where("status", "==", "waiting")
    .get();
  await Promise.all(
    stranded.docs.map((tab) =>
      tab.ref.update({
        status: "approved",
        decidedBy: "auto",
        decidedAt: FieldValue.serverTimestamp(),
      }),
    ),
  );
});

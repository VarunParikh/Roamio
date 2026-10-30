import { getFirestore } from "firebase-admin/firestore";
import { onDocumentWritten } from "firebase-functions/firestore";

// Who may see whose profile (follow-up S3b): only people who share a squad,
// now or in the past (someone who left still shows on old tabs).
// profileReaders/{uid}.uids is that list; the security rules read it. It is
// server-only, rebuilt whenever a squad's membership changes, and also
// updated straight away when someone joins (joinAdventure).

const db = () => getFirestore();

type Squad = { memberUids?: string[]; leftUids?: string[] };
const people = (squad?: Squad) => [...(squad?.memberUids ?? []), ...(squad?.leftUids ?? [])];

/** Everyone who shares, or shared, a squad with [uid]. */
export async function squadmatesOf(uid: string): Promise<string[]> {
  const [current, left] = await Promise.all([
    db().collection("adventures").where("memberUids", "array-contains", uid).get(),
    db().collection("adventures").where("leftUids", "array-contains", uid).get(),
  ]);
  const all = new Set<string>();
  for (const adventure of [...current.docs, ...left.docs]) {
    for (const other of people(adventure.data() as Squad)) all.add(other);
  }
  all.delete(uid);
  return [...all].sort();
}

/**
 * Rebuilds the list for each of [uids]; a deleted account gets none. The
 * profile is checked inside a transaction, so a rebuild that races an
 * account deletion can never bring the list back afterwards.
 */
export async function refreshProfileReaders(uids: string[]): Promise<void> {
  await Promise.all(
    uids.map(async (uid) => {
      const mates = await squadmatesOf(uid);
      const ref = db().doc(`profileReaders/${uid}`);
      await db().runTransaction(async (tx) => {
        if ((await tx.get(db().doc(`users/${uid}`))).exists) tx.set(ref, { uids: mates });
        else tx.delete(ref);
      });
    }),
  );
}

/** Rebuilds everyone's list when a squad's members or Left people change. */
export const profileReadersOnAdventure = onDocumentWritten("adventures/{aid}", async (event) => {
  const before = new Set(people(event.data?.before.data() as Squad | undefined));
  const after = new Set(people(event.data?.after.data() as Squad | undefined));
  if (before.size === after.size && [...after].every((uid) => before.has(uid))) return;
  await refreshProfileReaders([...new Set([...before, ...after])]);
});

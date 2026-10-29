import { getFirestore } from "firebase-admin/firestore";

/**
 * Queues an email in the `mail` collection, in the format of Firebase's
 * "Trigger Email" extension, which sends it once a provider is installed
 * (docs/SETUP.md). Clients can never read or write this collection.
 */
export async function queueMail(to: string, subject: string, text: string): Promise<void> {
  await getFirestore()
    .collection("mail")
    .add({ to, message: { subject, text }, createdAt: Date.now() });
}

/** The Hosting domain of the current project (spec §17: free web.app domain). */
export function siteUrl(): string {
  return `https://${process.env.GCLOUD_PROJECT}.web.app`;
}

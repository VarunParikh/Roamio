import { getFirestore, Timestamp } from "firebase-admin/firestore";

/** Sent emails are deleted after this long (privacy notice; a TTL policy on `expiresAt`). */
const KEEP_MAIL_DAYS = 30;

/**
 * Queues an email in the `mail` collection, in the format of Firebase's
 * "Trigger Email" extension, which sends it once a provider is installed
 * (docs/SETUP.md). Clients can never read or write this collection. A
 * Firestore TTL policy on `expiresAt` deletes each email after 30 days.
 */
export async function queueMail(to: string, subject: string, text: string): Promise<void> {
  await getFirestore()
    .collection("mail")
    .add({
      to,
      message: { subject, text },
      createdAt: Date.now(),
      expiresAt: Timestamp.fromMillis(Date.now() + KEEP_MAIL_DAYS * 86_400_000),
    });
}

/** The Hosting domain of the current project (spec §17: free web.app domain). */
export function siteUrl(): string {
  return `https://${process.env.GCLOUD_PROJECT}.web.app`;
}

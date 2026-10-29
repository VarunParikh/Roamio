import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";
import { logger } from "firebase-functions";

/** The parts of `users/{uid}/private/account` push needs. */
export type PushAccount = {
  fcmTokens?: string[];
  consents?: { notifications?: boolean };
};

export type PushMessage = { title: string; body: string; data: Record<string, string> };

/**
 * Device tokens of people who explicitly turned notifications on
 * (consent per purpose, spec §8). No answer yet means no push.
 */
export function pushTargets(accounts: PushAccount[]): string[] {
  const tokens = accounts
    .filter((a) => a.consents?.notifications === true)
    .flatMap((a) => a.fcmTokens ?? []);
  return [...new Set(tokens)];
}

// The emulators can't deliver push, so there it is logged instead.
const inEmulator = () =>
  process.env.FUNCTIONS_EMULATOR === "true" || Boolean(process.env.FIRESTORE_EMULATOR_HOST);

/**
 * Sends [message] to the consenting devices of [uids] and drops tokens
 * FCM says are gone. Returns the tokens it targeted. Never throws: a
 * failed push must not undo what triggered it.
 */
export async function sendPush(uids: string[], message: PushMessage): Promise<string[]> {
  const db = getFirestore();
  try {
    const accounts = await Promise.all(
      uids.map(async (uid) => ({
        uid,
        account: ((await db.doc(`users/${uid}/private/account`).get()).data() ?? {}) as PushAccount,
      })),
    );
    const tokens = pushTargets(accounts.map((a) => a.account));
    if (tokens.length === 0) return [];
    if (inEmulator()) {
      logger.info("Push (not sent in the emulator)", { tokens: tokens.length, ...message });
      return tokens;
    }

    // `fcmTokens` holds each phone's FCM installation ID (FID).
    const result = await getMessaging().sendEachForMulticast({
      fids: tokens,
      notification: { title: message.title, body: message.body },
      data: message.data,
      android: { priority: "high" },
    });
    const gone = tokens.filter((_, i) => {
      const code = result.responses[i].error?.code;
      return (
        code === "messaging/registration-token-not-registered" ||
        code === "messaging/invalid-registration-token"
      );
    });
    for (const { uid, account } of accounts) {
      const stale = (account.fcmTokens ?? []).filter((t) => gone.includes(t));
      if (stale.length > 0) {
        await db
          .doc(`users/${uid}/private/account`)
          .update({ fcmTokens: FieldValue.arrayRemove(...stale) });
      }
    }
    return tokens;
  } catch (e) {
    logger.warn("Push failed", { error: String(e) });
    return [];
  }
}

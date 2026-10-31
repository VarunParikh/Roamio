import type { RulesTestEnvironment } from "@firebase/rules-unit-testing";

/**
 * Empties the Firestore emulator. Triggers from the previous test can still
 * be writing, which makes the emulator answer "Transaction lock timeout", so
 * it tries again rather than failing a test that has nothing to do with it.
 */
export async function clearFirestore(env: RulesTestEnvironment): Promise<void> {
  for (let attempt = 1; ; attempt++) {
    try {
      return await env.clearFirestore();
    } catch (e) {
      if (attempt >= 5 || !String(e).includes("ABORTED")) throw e;
      await new Promise((r) => setTimeout(r, 500 * attempt));
    }
  }
}

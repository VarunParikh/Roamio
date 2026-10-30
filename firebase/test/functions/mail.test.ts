import { describe, expect, it } from "vitest";
import { getFirestore } from "../support/admin";
import "../support/callable";
import { queueMail } from "../../functions/src/mail";

describe("queueMail (follow-up S12: emails don't stay for ever)", () => {
  it("gives every queued email an expiry 30 days on, for the TTL policy", async () => {
    const to = `ttl.${Date.now()}@example.com`;
    const before = Date.now();
    await queueMail(to, "Hello", "Body");

    const [mail] = (await getFirestore().collection("mail").where("to", "==", to).get()).docs;
    const expiresAt = mail.get("expiresAt");
    // A Firestore timestamp: TTL policies only act on timestamp fields.
    expect(typeof expiresAt?.toMillis).toBe("function");
    const days = (expiresAt.toMillis() - before) / 86_400_000;
    expect(days).toBeGreaterThanOrEqual(29.99);
    expect(days).toBeLessThan(30.01);
  });
});

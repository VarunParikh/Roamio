import { describe, expect, it } from "vitest";
import { getFirestore, Timestamp } from "../support/admin";
import "../support/callable";
import { purgeOldAuditLog } from "../../functions/src/privacy/auditRetention";

const db = () => getFirestore();

async function entry(target: string, at: Date) {
  await db().collection("auditLog").add({
    actorUid: target,
    action: "data_exported",
    target,
    at: Timestamp.fromDate(at),
  });
}

const kept = async (target: string) =>
  (await db().collection("auditLog").where("target", "==", target).get()).size;

describe("purgeOldAuditLog (spec §8: audit log kept 1 year)", () => {
  it("deletes entries older than a year and keeps the rest", async () => {
    const now = new Date("2027-11-01T09:00:00Z");
    const t = `ret-${Date.now()}`;
    await entry(`${t}-old`, new Date("2026-10-31T09:00:00Z"));
    await entry(`${t}-old`, new Date("2025-01-01T00:00:00Z"));
    await entry(`${t}-edge`, new Date("2026-11-01T09:00:00Z"));
    await entry(`${t}-new`, new Date("2027-06-01T00:00:00Z"));

    const removed = await purgeOldAuditLog(now);

    expect(removed).toBeGreaterThanOrEqual(2);
    expect(await kept(`${t}-old`)).toBe(0);
    // Exactly a year old is still within the year.
    expect(await kept(`${t}-edge`)).toBe(1);
    expect(await kept(`${t}-new`)).toBe(1);
  });

  it("works through more entries than one batch", async () => {
    const now = new Date("2030-01-01T00:00:00Z");
    const t = `batch-${Date.now()}`;
    for (let i = 0; i < 7; i++) await entry(t, new Date("2028-01-01T00:00:00Z"));

    await purgeOldAuditLog(now, 3);

    expect(await kept(t)).toBe(0);
  });
});

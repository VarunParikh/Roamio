import { describe, expect, it } from "vitest";
import {
  BUDGET_THRESHOLDS,
  checkBudget,
  convertMinor,
  shareOf,
  thresholdsReached,
} from "../../functions/src/budget/budget";
import { getFirestore } from "../support/admin";
import { adventure, person } from "../support/callable";

const db = () => getFirestore();

/** Waits for triggers to settle: polls until [check] passes. */
async function eventually(check: () => Promise<void>, ms = 8000): Promise<void> {
  const until = Date.now() + ms;
  for (;;) {
    try {
      return await check();
    } catch (e) {
      if (Date.now() > until) throw e;
      await new Promise((r) => setTimeout(r, 200));
    }
  }
}

describe("budget maths (same rules as the app, spec §6, §9.1)", () => {
  it("shares follow the split engine: equal or basis points, spare units first", () => {
    const tab = { amountMinor: 1000, payers: [], participants: ["a", "b", "c"], percentBp: null };
    expect(shareOf(tab, 1000, "a")).toBe(334);
    expect(shareOf(tab, 1000, "c")).toBe(333);
    expect(shareOf({ ...tab, percentBp: { a: 5000, b: 2500, c: 2500 } }, 300000, "a")).toBe(150000);
    expect(shareOf(tab, 1000, "zed")).toBe(0);
  });

  it("converts exactly with each currency's decimals, rounding half to even", () => {
    const rates = { INR: "84", THB: "35", JPY: "150" };
    expect(convertMinor(50000, "INR", "THB", rates)).toBe(20833); // ₹500 → ฿208.33
    expect(convertMinor(120000, "THB", "INR", rates)).toBe(288000);
    expect(convertMinor(100, "USD", "JPY", rates)).toBe(150); // $1 → ¥150
    expect(convertMinor(5, "INR", "INR", {})).toBe(5);
    expect(() => convertMinor(1, "INR", "EUR", rates)).toThrow();
  });

  it("thresholds are crossed at exactly 80% and 100%", () => {
    expect(BUDGET_THRESHOLDS).toEqual([80, 100]);
    expect(thresholdsReached(7999, 10000)).toEqual([]);
    expect(thresholdsReached(8000, 10000)).toEqual([80]);
    expect(thresholdsReached(10000, 10000)).toEqual([80, 100]);
  });
});

/** Ari's budget of ₹10,000 on a trip with one tab Ari shares half of. */
async function trip(tabRupees: number, deleted = false, status?: string) {
  const ari = await person("Ari");
  const ben = await person("Ben");
  const id = await adventure(ari, {
    memberUids: [ari.uid, ben.uid],
    baseCurrency: "INR",
    name: "Goa trip",
  });
  await db()
    .doc(`adventures/${id}/budgets/${ari.uid}`)
    .set({ amountMinor: 1_000_000, currency: "INR" });
  const tab = db().collection(`adventures/${id}/tabs`).doc();
  await tab.set({
    amountMinor: tabRupees * 100,
    currency: "INR",
    date: "2026-10-27",
    fxDate: "2026-10-27",
    payers: [{ id: ben.uid, amountMinor: tabRupees * 100 }],
    participants: [ari.uid, ben.uid],
    percentBp: null,
    createdBy: ben.uid,
    deleted,
    ...(status ? { status } : {}),
  });
  return { ari, ben, id, tab };
}

const alerts = async (uid: string, id: string) =>
  (await db().collection(`users/${uid}/notifications`).where("adventureId", "==", id).get()).docs
    .filter((d) => d.get("type") === "budget_alert")
    .map((d) => d.get("threshold"))
    .sort();

// The emulator's triggers also react to the seeded data, so these check
// the end state, which is the same whoever runs the check first.
describe("checkBudget (spec UC-20)", () => {
  const sent = async (id: string, uid: string) =>
    (await db().doc(`adventures/${id}/budgets/${uid}`).get()).get("alertsSent") ?? [];

  it("79% sends nothing", async () => {
    const { ari, id } = await trip(15_800); // Ari's half: ₹7,900
    await checkBudget(id, ari.uid);
    await new Promise((r) => setTimeout(r, 1500)); // let triggers finish
    expect(await alerts(ari.uid, id)).toEqual([]);
    expect(await sent(id, ari.uid)).toEqual([]);
  });

  it("80% sends one alert, once, however often it is checked", async () => {
    const { ari, id } = await trip(16_000); // Ari's half: ₹8,000
    await Promise.all([checkBudget(id, ari.uid), checkBudget(id, ari.uid)]);
    await checkBudget(id, ari.uid);
    await eventually(async () => {
      expect(await sent(id, ari.uid)).toEqual([80]);
    });
    expect(await alerts(ari.uid, id)).toEqual([80]);
    // Once recorded, a repeat trigger has nothing new to send.
    expect(await checkBudget(id, ari.uid)).toEqual([]);
  });

  it("only the owner's own share counts, not what they paid", async () => {
    const { ben, id } = await trip(19_000);
    // Ben paid ₹19,000 but has no budget, so nothing to check.
    expect(await checkBudget(id, ben.uid)).toEqual([]);
  });

  it("converts tabs into the budget's currency at their day's rates", async () => {
    const { ari, id } = await trip(15_800); // ₹7,900: under ₹10,000's 80%
    await db().doc("fx_rates/2026-10-27").set({ date: "2026-10-27", rates: { INR: "84", THB: "35" } });
    // ฿4,000 budget; Ari's ₹7,900 = ฿3,291.67 → 82%.
    await db().doc(`adventures/${id}/budgets/${ari.uid}`).set({ amountMinor: 400_000, currency: "THB" });
    await checkBudget(id, ari.uid);
    await eventually(async () => {
      expect(await sent(id, ari.uid)).toEqual([80]);
    });
  });

  it("waiting and rejected tabs don't count", async () => {
    for (const status of ["waiting", "rejected"]) {
      const { ari, id } = await trip(16_000, false, status);
      await checkBudget(id, ari.uid);
      await new Promise((r) => setTimeout(r, 1500));
      expect(await alerts(ari.uid, id)).toEqual([]);
    }
  });

  it("approved and personal tabs count", async () => {
    for (const status of ["approved", "personal"]) {
      const { ari, id } = await trip(16_000, false, status);
      await checkBudget(id, ari.uid);
      expect(await sent(id, ari.uid)).toEqual([80]);
    }
  });

  it("deleted tabs don't count", async () => {
    const { ari, id } = await trip(16_000, true);
    await checkBudget(id, ari.uid);
    await new Promise((r) => setTimeout(r, 1500));
    expect(await alerts(ari.uid, id)).toEqual([]);
  });
});

describe("budget triggers", () => {
  it("a new tab alerts; changing the budget resets the alerts", async () => {
    const { ari, id } = await trip(16_000);
    await eventually(async () => {
      expect(await alerts(ari.uid, id)).toEqual([80]);
    });

    // A bigger budget: no longer at 80%, and the slate is clean.
    await db().doc(`adventures/${id}/budgets/${ari.uid}`).update({ amountMinor: 2_000_000 });
    await eventually(async () => {
      const b = (await db().doc(`adventures/${id}/budgets/${ari.uid}`).get()).data();
      expect(b?.alertsSent).toEqual([]);
    });

    // Back down: the 80% alert can fire again.
    await db().doc(`adventures/${id}/budgets/${ari.uid}`).update({ amountMinor: 1_000_000 });
    await eventually(async () => {
      const b = (await db().doc(`adventures/${id}/budgets/${ari.uid}`).get()).data();
      expect(b?.alertsSent).toEqual([80]);
    });
  });
});

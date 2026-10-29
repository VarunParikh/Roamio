import { describe, expect, it } from "vitest";
import { getFirestore } from "../support/admin";
import { tabProblem } from "../../functions/src/tabs/checkTab";
import { adventure, person } from "../support/callable";

const db = () => getFirestore();

/** Waits for a Firestore trigger to have run: polls until [check] passes. */
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

const tab = (by: string, extra: Record<string, unknown> = {}) => ({
  description: "Dinner",
  category: "food_dining",
  amountMinor: 90000,
  currency: "THB",
  date: "2026-12-02",
  fxDate: "2026-12-02",
  payers: [{ id: by, amountMinor: 90000 }],
  participants: [by],
  percentBp: null,
  memories: [],
  createdBy: by,
  deleted: false,
  ...extra,
});

async function squad() {
  const ari = await person("Ari");
  const bob = await person("Bob");
  const id = await adventure(ari, { memberUids: [ari.uid, bob.uid] });
  await db().doc(`adventures/${id}/pals/kiko`).set({ nickname: "Kiko", status: "active" });
  return { ari, bob, id };
}

describe("tab check trigger (DATA_MODEL: what rules can't check)", () => {
  it("marks the adventure as having tabs and keeps a valid tab", async () => {
    const { ari, bob, id } = await squad();
    const ref = db().collection(`adventures/${id}/tabs`).doc();
    await ref.set(tab(ari.uid, { participants: [ari.uid, bob.uid, "kiko"] }));

    await eventually(async () => {
      expect((await db().doc(`adventures/${id}`).get()).get("hasTabs")).toBe(true);
    });
    expect((await ref.get()).get("deleted")).toBe(false);
  });

  it("soft-deletes a tab whose payments don't add up, and logs why", async () => {
    const { ari, bob, id } = await squad();
    const ref = db().collection(`adventures/${id}/tabs`).doc();
    await ref.set(
      tab(ari.uid, {
        payers: [
          { id: ari.uid, amountMinor: 50000 },
          { id: bob.uid, amountMinor: 30000 },
        ],
        participants: [ari.uid, bob.uid],
      }),
    );

    await eventually(async () => {
      expect((await ref.get()).get("deleted")).toBe(true);
    });
    const log = await db().collection(`adventures/${id}/activity`).where("subject", "==", ref.id).get();
    expect(log.docs.map((d) => d.get("type"))).toEqual(["tab_rejected"]);
  });

  it("rejects outsiders as payers or participants, and pals as payers", async () => {
    const { ari, id } = await squad();
    const eve = await person("Eve");
    const bad = [
      tab(ari.uid, { participants: [ari.uid, eve.uid] }),
      tab(ari.uid, { payers: [{ id: eve.uid, amountMinor: 90000 }] }),
      tab(ari.uid, { payers: [{ id: "kiko", amountMinor: 90000 }] }),
      tab(ari.uid, { participants: [ari.uid, ari.uid] }),
    ];
    const refs = await Promise.all(
      bad.map(async (t) => {
        const ref = db().collection(`adventures/${id}/tabs`).doc();
        await ref.set(t);
        return ref;
      }),
    );
    for (const ref of refs) {
      await eventually(async () => {
        expect((await ref.get()).get("deleted")).toBe(true);
      });
    }
  });

  it("checks custom percentages add up to 100% over the participants", async () => {
    const { ari, bob, id } = await squad();
    const good = db().collection(`adventures/${id}/tabs`).doc();
    const bad = db().collection(`adventures/${id}/tabs`).doc();
    await good.set(
      tab(ari.uid, { participants: [ari.uid, bob.uid], percentBp: { [ari.uid]: 7500, [bob.uid]: 2500 } }),
    );
    await bad.set(
      tab(ari.uid, { participants: [ari.uid, bob.uid], percentBp: { [ari.uid]: 7500, [bob.uid]: 2000 } }),
    );

    await eventually(async () => {
      expect((await bad.get()).get("deleted")).toBe(true);
    });
    expect((await good.get()).get("deleted")).toBe(false);
  });

  it("leaves tabs alone that a lead already deleted", async () => {
    const { ari, id } = await squad();
    const ref = db().collection(`adventures/${id}/tabs`).doc();
    await ref.set(tab(ari.uid, { deleted: true, amountMinor: 1 }));
    await eventually(async () => {
      expect((await db().doc(`adventures/${id}`).get()).get("hasTabs")).toBe(true);
    });
    const log = await db().collection(`adventures/${id}/activity`).get();
    expect(log.empty).toBe(true);
  });
});

describe("tabProblem when a tab is edited", () => {
  const t = tab("ari", { participants: ["ari", "bob"] });
  const isMember = (id: string) => id === "ari";

  it("keeps someone who has since left on a tab they were already on", () => {
    expect(tabProblem(t, new Set(["ari"]), isMember, t)).toBeNull();
  });

  it("won't add someone who has left to a tab", () => {
    const before = tab("ari", { participants: ["ari"] });
    expect(tabProblem(t, new Set(["ari"]), isMember, before)).toContain("squad");
  });
});

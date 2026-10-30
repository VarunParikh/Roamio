import { describe, expect, it } from "vitest";
import { getFirestore, Timestamp } from "../support/admin";
import { tabProblem, replacedEdit } from "../../functions/src/tabs/checkTab";
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

describe("deleting a tab", () => {
  it("logs who deleted it in the activity (spec UC-22)", async () => {
    const { ari, id } = await squad();
    const ref = db().collection(`adventures/${id}/tabs`).doc();
    await ref.set(tab(ari.uid));
    await eventually(async () => {
      expect((await db().doc(`adventures/${id}`).get()).get("hasTabs")).toBe(true);
    });
    await ref.update({ deleted: true, deletedBy: ari.uid });

    await eventually(async () => {
      const log = await db().collection(`adventures/${id}/activity`).where("subject", "==", ref.id).get();
      expect(log.docs.map((d) => [d.get("type"), d.get("actorUid")])).toEqual([["tab_deleted", ari.uid]]);
    });
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

describe("tabProblem: the rate day (follow-up C14)", () => {
  const active = new Set(["ari"]);
  const isMember = (id: string) => id === "ari";

  it("accepts the tab's own day or an earlier rates day within a week", () => {
    expect(tabProblem(tab("ari"), active, isMember)).toBeNull();
    expect(tabProblem(tab("ari", { fxDate: "2026-12-01" }), active, isMember)).toBeNull();
    expect(tabProblem(tab("ari", { fxDate: "2026-11-25" }), active, isMember)).toBeNull();
  });

  it("refuses a rates day after the tab, or backdated more than a week", () => {
    expect(tabProblem(tab("ari", { fxDate: "2026-12-03" }), active, isMember)).toContain("rates");
    expect(tabProblem(tab("ari", { fxDate: "2026-11-24" }), active, isMember)).toContain("rates");
  });

  it("keeps an old tab's rate day when someone else's edit doesn't touch it", () => {
    const old = tab("ari", { fxDate: "2026-11-01" });
    expect(tabProblem({ ...old, description: "Lunch" }, active, isMember, old)).toBeNull();
  });
});

describe("replacedEdit (spec UC-32)", () => {
  const at = (s: number) => Timestamp.fromMillis(s * 1000);

  it("flags an edit made from an older version than the one it replaced", () => {
    expect(replacedEdit({ updatedAt: at(5) }, { updatedAt: at(9), baseUpdatedAt: at(3) })).toBe(true);
  });

  it("is quiet when the edit was based on the version it replaced", () => {
    expect(replacedEdit({ updatedAt: at(5) }, { updatedAt: at(9), baseUpdatedAt: at(5) })).toBe(false);
  });

  it("is quiet without a base (made offline twice) or a previous version (new tab)", () => {
    expect(replacedEdit({ updatedAt: at(5) }, { updatedAt: at(9) })).toBe(false);
    expect(replacedEdit(undefined, { updatedAt: at(9), baseUpdatedAt: at(3) })).toBe(false);
  });

  it("ignores writes that did not change updatedAt, such as a photo link", () => {
    expect(replacedEdit({ updatedAt: at(5) }, { updatedAt: at(5), baseUpdatedAt: at(3) })).toBe(false);
  });
});

describe("a replaced edit is logged (spec UC-32)", () => {
  it("writes tab_edit_replaced once, and none for a normal edit", async () => {
    const { ari, id } = await squad();
    const ref = db().collection(`adventures/${id}/tabs`).doc();
    await ref.set(tab(ari.uid, { updatedAt: Timestamp.fromMillis(5000) }));
    await eventually(async () => {
      expect((await db().doc(`adventures/${id}`).get()).get("hasTabs")).toBe(true);
    });

    // based on the version it replaces: nothing to say
    await ref.update({ amountMinor: 80000, payers: [{ id: ari.uid, amountMinor: 80000 }],
      updatedAt: Timestamp.fromMillis(6000), baseUpdatedAt: Timestamp.fromMillis(5000) });
    // based on an older version: it overwrote someone's change
    await ref.update({ amountMinor: 70000, payers: [{ id: ari.uid, amountMinor: 70000 }],
      updatedAt: Timestamp.fromMillis(7000), baseUpdatedAt: Timestamp.fromMillis(5000) });

    await eventually(async () => {
      const log = await db().collection(`adventures/${id}/activity`).where("subject", "==", ref.id).get();
      expect(log.docs.map((d) => [d.get("type"), d.get("actorUid")])).toEqual([["tab_edit_replaced", ari.uid]]);
    });
  });
});

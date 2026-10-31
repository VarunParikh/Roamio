import { describe, expect, it } from "vitest";
import { getFirestore, Timestamp } from "../support/admin";
import { moneyChanged, tabProblem, replacedEdit, windowProblem } from "../../functions/src/tabs/checkTab";
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

  it("tells the creator when it removes their tab (item 2)", async () => {
    const { ari, id } = await squad();
    const ref = db().collection(`adventures/${id}/tabs`).doc();
    await ref.set(tab(ari.uid, { amountMinor: 1, description: "Dinner" }));

    await eventually(async () => {
      const notice = await db().doc(`users/${ari.uid}/notifications/${id}_removed_${ref.id}`).get();
      expect(notice.get("type")).toBe("tab_removed");
      expect(notice.get("description")).toBe("Dinner");
      expect(notice.get("adventureId")).toBe(id);
    });
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

  it("keeps a tab saved with an old offline rates day, when those rates exist", async () => {
    const { ari, id } = await squad();
    await db().doc("fx_rates/2026-09-01").set({ date: "2026-09-01" });
    const ref = db().collection(`adventures/${id}/tabs`).doc();
    await ref.set(tab(ari.uid, { date: "2026-12-02", fxDate: "2026-09-01" }));

    await new Promise((r) => setTimeout(r, 1500));
    expect((await ref.get()).get("deleted")).toBe(false);
  });

  it("soft-deletes a tab backdated to a rates day with no rates behind it", async () => {
    const { ari, id } = await squad();
    const ref = db().collection(`adventures/${id}/tabs`).doc();
    await ref.set(tab(ari.uid, { date: "2026-12-02", fxDate: "2026-08-15" }));

    await eventually(async () => {
      expect((await ref.get()).get("deleted")).toBe(true);
    });
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

describe("personal tabs stay out of what the squad sees (spec UC-21a)", () => {
  it("don't lock the trip's currency", async () => {
    const { ari, id } = await squad();
    await db()
      .collection(`adventures/${id}/tabs`)
      .add(tab(ari.uid, { status: "personal", participants: [ari.uid] }));
    await new Promise((r) => setTimeout(r, 1500));
    expect((await db().doc(`adventures/${id}`).get()).get("hasTabs")).not.toBe(true);
  });

  it("deleting one logs nothing in the activity", async () => {
    const { ari, id } = await squad();
    const ref = db().collection(`adventures/${id}/tabs`).doc();
    await ref.set(tab(ari.uid, { status: "personal", participants: [ari.uid] }));
    await ref.update({ deleted: true, deletedBy: ari.uid });
    await new Promise((r) => setTimeout(r, 1500));
    const activity = await db().collection(`adventures/${id}/activity`).get();
    expect(activity.docs.filter((d) => d.get("subject") === ref.id)).toEqual([]);
  });
});

describe("moneyChanged (spec UC-21a)", () => {
  const before = {
    amountMinor: 100,
    currency: "THB",
    payers: [{ id: "a", amountMinor: 100, method: "cash" }],
    participants: ["a", "b"],
    percentBp: null,
  };

  it("spots the amount, currency, payers and shares", () => {
    expect(moneyChanged(before, { ...before, amountMinor: 200 })).toBe(true);
    expect(moneyChanged(before, { ...before, currency: "INR" })).toBe(true);
    expect(moneyChanged(before, { ...before, participants: ["a"] })).toBe(true);
    expect(moneyChanged(before, { ...before, percentBp: { a: 5000, b: 5000 } })).toBe(true);
    expect(
      moneyChanged(before, { ...before, payers: [{ id: "b", amountMinor: 100, method: "cash" }] }),
    ).toBe(true);
  });

  it("ignores the description, category and how someone paid", () => {
    expect(moneyChanged(before, { ...before, description: "New", category: "x" })).toBe(false);
    expect(
      moneyChanged(before, { ...before, payers: [{ id: "a", amountMinor: 100, method: "card" }] }),
    ).toBe(false);
  });
});

describe("editing an approved tab (spec UC-21a)", () => {
  const approved = async () => {
    const { ari, bob, id } = await squad();
    await db().doc(`adventures/${id}`).update({ coLeadUids: [bob.uid] });
    const ref = db().collection(`adventures/${id}/tabs`).doc();
    await ref.set(
      tab(bob.uid, { status: "approved", decidedBy: ari.uid, participants: [ari.uid, bob.uid] }),
    );
    await new Promise((r) => setTimeout(r, 800));
    return { ari, bob, id, ref };
  };

  it("a money edit sends it back to waiting", async () => {
    const { bob, ref } = await approved();
    await ref.update({ amountMinor: 50000, payers: [{ id: bob.uid, amountMinor: 50000 }] });
    await eventually(async () => {
      const after = await ref.get();
      expect(after.get("status")).toBe("waiting");
      expect(after.get("decidedBy")).toBeUndefined();
    });
  });

  it("a description edit keeps it approved", async () => {
    const { ref } = await approved();
    await ref.update({ description: "Noodles" });
    await new Promise((r) => setTimeout(r, 1500));
    expect((await ref.get()).get("status")).toBe("approved");
  });

  it("the only admin's money edit stays approved", async () => {
    const { ari, id } = await squad();
    const ref = db().collection(`adventures/${id}/tabs`).doc();
    await ref.set(tab(ari.uid, { status: "approved", participants: [ari.uid, "x"] }));
    await new Promise((r) => setTimeout(r, 800));
    await ref.update({ amountMinor: 50000, payers: [{ id: ari.uid, amountMinor: 50000 }] });
    await new Promise((r) => setTimeout(r, 1500));
    expect((await ref.get()).get("status")).toBe("approved");
  });
});

describe("rejecting a tab", () => {
  it("logs it with its own type, without the reason", async () => {
    const { ari, bob, id } = await squad();
    const ref = db().collection(`adventures/${id}/tabs`).doc();
    await ref.set(tab(bob.uid, { status: "waiting", participants: [ari.uid, bob.uid] }));
    await ref.update({ status: "rejected", decidedBy: ari.uid, rejectReason: "Wrong trip" });
    await eventually(async () => {
      const log = await db().collection(`adventures/${id}/activity`).get();
      const entry = log.docs.find((d) => d.get("type") === "tab_declined");
      expect(entry?.get("actorUid")).toBe(ari.uid);
      expect(entry?.get("reason")).toBeUndefined();
    });
  });
});

describe("Paid with is never a reason to remove a tab (spec UC-21)", () => {
  const paid = (method: unknown) =>
    tab("ari", { payers: [{ id: "ari", amountMinor: 90000, method }] });
  const active = new Set(["ari"]);
  const isMember = (id: string) => id === "ari";

  it("accepts every method, a missing one, and values it doesn't know", () => {
    for (const method of [
      "cash",
      "card",
      "upi",
      "cheque",
      "bank_transfer",
      "other",
      undefined,
      null,
      "",
      "crypto",
      42,
      { a: 1 },
    ]) {
      expect(tabProblem(paid(method), active, isMember)).toBeNull();
    }
    expect(tabProblem(tab("ari"), active, isMember)).toBeNull();
  });

  it("keeps a saved tab with an unknown or missing method", async () => {
    const { ari, id } = await squad();
    const unknown = db().collection(`adventures/${id}/tabs`).doc();
    const missing = db().collection(`adventures/${id}/tabs`).doc();
    await unknown.set(
      tab(ari.uid, { payers: [{ id: ari.uid, amountMinor: 90000, method: "crypto" }] }),
    );
    await missing.set(tab(ari.uid));

    // Both have been through the trigger once the adventure says it has tabs.
    await eventually(async () => {
      expect((await db().doc(`adventures/${id}`).get()).get("hasTabs")).toBe(true);
    });
    expect((await unknown.get()).get("deleted")).toBe(false);
    expect((await missing.get()).get("deleted")).toBe(false);
    const rejected = await db()
      .collection(`adventures/${id}/activity`)
      .where("type", "==", "tab_rejected")
      .get();
    expect(rejected.empty).toBe(true);
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

describe("tabProblem: the rate day (follow-up C14, offline)", () => {
  const active = new Set(["ari"]);
  const isMember = (id: string) => id === "ari";

  it("accepts the tab's own day, with or without rates behind it", () => {
    expect(tabProblem(tab("ari"), active, isMember)).toBeNull();
    expect(tabProblem(tab("ari"), active, isMember, undefined, false)).toBeNull();
  });

  it("accepts an earlier rates day however old, as long as those rates exist", () => {
    // An offline phone can be weeks behind; its last rates still count.
    const old = tab("ari", { fxDate: "2026-09-01" });
    expect(tabProblem(old, active, isMember, undefined, true)).toBeNull();
    expect(tabProblem(tab("ari", { fxDate: "2026-11-25" }), active, isMember, undefined, true)).toBeNull();
  });

  it("refuses an earlier rates day with no rates behind it (backdating)", () => {
    expect(tabProblem(tab("ari", { fxDate: "2026-12-01" }), active, isMember)).toContain("rates");
    expect(tabProblem(tab("ari", { fxDate: "2026-09-01" }), active, isMember, undefined, false)).toContain("rates");
  });

  it("refuses a rates day after the tab", () => {
    expect(tabProblem(tab("ari", { fxDate: "2026-12-03" }), active, isMember, undefined, true)).toContain("rates");
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

describe("windowProblem: when tabs can be added (spec UC-11, item 17)", () => {
  // Trip ends 8 December; ari leads, cara co-leads, bob is a member.
  const trip = { endDate: "2026-12-08", leaderUid: "ari", coLeadUids: ["cara"] };
  const added = (by: string, date: string) => tab(by, { createdBy: by, date });

  it("members can add a tab dated up to the last day of the trip", () => {
    expect(windowProblem(added("bob", "2026-12-08"), undefined, trip)).toBeNull();
    expect(windowProblem(added("bob", "2026-12-09"), undefined, trip)).toContain("trip");
  });

  it("leads and co-leads can add tabs dated up to 7 days after", () => {
    expect(windowProblem(added("ari", "2026-12-15"), undefined, trip)).toBeNull();
    expect(windowProblem(added("cara", "2026-12-15"), undefined, trip)).toBeNull();
    expect(windowProblem(added("ari", "2026-12-16"), undefined, trip)).toContain("trip");
  });

  it("goes by the tab's day, so a tab that syncs weeks later is kept", () => {
    // The check takes no "today": a phone offline on the last day isn't punished.
    expect(windowProblem.length).toBe(3);
  });

  it("a trip with no readable end date refuses nothing, and doesn't crash", () => {
    const undated = { leaderUid: "ari" };
    expect(windowProblem(added("bob", "2026-12-20"), undefined, undated)).toBeNull();
    expect(windowProblem(added("bob", "2026-12-20"), undefined, { ...undated, endDate: "soon" })).toBeNull();
  });

  it("never refuses an edit of a tab that already exists", () => {
    const before = added("bob", "2026-12-20");
    expect(windowProblem(before, before, trip)).toBeNull();
  });
});

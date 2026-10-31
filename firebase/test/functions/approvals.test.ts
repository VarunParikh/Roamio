import { describe, expect, it } from "vitest";
import { getFirestore } from "../support/admin";
import { adventure, person, type Person } from "../support/callable";

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

async function waitingTab(id: string, by: Person): Promise<FirebaseFirestore.DocumentReference> {
  const tab = db().collection(`adventures/${id}/tabs`).doc();
  await tab.set({
    amountMinor: 1000,
    currency: "THB",
    date: "2026-12-02",
    fxDate: "2026-12-02",
    payers: [{ id: by.uid, amountMinor: 1000 }],
    participants: [by.uid],
    percentBp: null,
    createdBy: by.uid,
    deleted: false,
    status: "waiting",
  });
  return tab;
}

const statusOf = async (tab: FirebaseFirestore.DocumentReference) =>
  (await tab.get()).get("status");

describe("tabs left with nobody to approve them (spec UC-21a)", () => {
  it("when the second admin leaves, the remaining admin's tabs are approved", async () => {
    const ari = await person("Ari");
    const cara = await person("Cara");
    const bob = await person("Bob");
    const id = await adventure(ari, {
      coLeadUids: [cara.uid],
      memberUids: [ari.uid, cara.uid, bob.uid],
    });
    const aris = await waitingTab(id, ari);
    const bobs = await waitingTab(id, bob);

    await db().doc(`adventures/${id}`).update({ coLeadUids: [] });

    await eventually(async () => expect(await statusOf(aris)).toBe("approved"));
    // Someone else's tab can still be decided by the remaining admin.
    expect(await statusOf(bobs)).toBe("waiting");
  });

  it("a member handed the leadership, alone, has their tabs approved", async () => {
    const ari = await person("Ari");
    const bob = await person("Bob");
    const id = await adventure(ari, { memberUids: [ari.uid, bob.uid] });
    const bobs = await waitingTab(id, bob);

    await db().doc(`adventures/${id}`).update({ leaderUid: bob.uid });

    await eventually(async () => expect(await statusOf(bobs)).toBe("approved"));
  });

  it("with another admin still there, nothing changes", async () => {
    const ari = await person("Ari");
    const cara = await person("Cara");
    const dan = await person("Dan");
    const id = await adventure(ari, {
      coLeadUids: [cara.uid, dan.uid],
      memberUids: [ari.uid, cara.uid, dan.uid],
    });
    const aris = await waitingTab(id, ari);

    await db().doc(`adventures/${id}`).update({ coLeadUids: [cara.uid] });

    await new Promise((r) => setTimeout(r, 1500));
    expect(await statusOf(aris)).toBe("waiting");
  });
});

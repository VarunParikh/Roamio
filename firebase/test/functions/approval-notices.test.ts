import { describe, expect, it } from "vitest";
import {
  approvalState,
  rejectionRecipient,
  waitingRecipients,
} from "../../functions/src/tabs/approvalNotices";
import { getFirestore } from "../support/admin";
import { adventure, person, type Person } from "../support/callable";

const db = () => getFirestore();

/** Waits for triggers to settle: polls until [check] passes. */
async function eventually(
  check: () => Promise<void>,
  ms = 8000,
): Promise<void> {
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

describe("who hears about a tab (spec UC-21a)", () => {
  const squad = {
    leaderUid: "ari",
    coLeadUids: ["cara"],
    memberUids: ["ari", "cara", "bob"],
  };

  it("a tab waits only while it's undeleted and marked waiting", () => {
    expect(approvalState({ status: "waiting", deleted: false })).toBe(
      "waiting",
    );
    expect(approvalState({ status: "rejected", deleted: false })).toBe(
      "rejected",
    );
    expect(approvalState({ status: "waiting", deleted: true })).toBe("other");
    expect(approvalState({ status: "rejected", deleted: true })).toBe("other");
    expect(approvalState({ status: "approved", deleted: false })).toBe("other");
    expect(approvalState({ status: "personal", deleted: false })).toBe("other");
    expect(approvalState(undefined)).toBe("other");
  });

  it("every admin hears about a waiting tab, members don't", () => {
    expect(waitingRecipients(squad, "bob")).toEqual(["ari", "cara"]);
  });

  it("the creator never hears about their own waiting tab", () => {
    expect(waitingRecipients(squad, "cara")).toEqual(["ari"]);
    expect(waitingRecipients(squad, "ari")).toEqual(["cara"]);
    expect(
      waitingRecipients({ leaderUid: "ari", coLeadUids: [] }, "ari"),
    ).toEqual([]);
  });

  it("the creator hears about a rejection, unless they rejected it or have gone", () => {
    expect(
      rejectionRecipient(squad, { createdBy: "bob", decidedBy: "ari" }),
    ).toBe("bob");
    expect(
      rejectionRecipient(squad, { createdBy: "ari", decidedBy: "ari" }),
    ).toBeNull();
    expect(
      rejectionRecipient(squad, { createdBy: "zed", decidedBy: "ari" }),
    ).toBeNull();
  });
});

const notices = async (who: Person, type: string) =>
  (
    await db()
      .collection(`users/${who.uid}/notifications`)
      .where("type", "==", type)
      .get()
  ).docs;

const card = (
  who: Person,
  id: string,
  tab: FirebaseFirestore.DocumentReference,
  kind: string,
) => db().doc(`users/${who.uid}/notifications/${id}_${kind}_${tab.id}`);

async function addTab(id: string, by: Person, status = "waiting") {
  const tab = db().collection(`adventures/${id}/tabs`).doc();
  await tab.set({
    description: "Dinner",
    amountMinor: 1000,
    currency: "THB",
    date: "2026-12-02",
    fxDate: "2026-12-02",
    payers: [{ id: by.uid, amountMinor: 1000 }],
    participants: [by.uid],
    percentBp: null,
    createdBy: by.uid,
    deleted: false,
    status,
  });
  return tab;
}

/** Ari leads, Cara is co-lead, Bob is a member. */
async function squad() {
  const ari = await person("Ari");
  const cara = await person("Cara");
  const bob = await person("Bob");
  const id = await adventure(ari, {
    name: "Goa trip",
    coLeadUids: [cara.uid],
    memberUids: [ari.uid, cara.uid, bob.uid],
  });
  return { ari, cara, bob, id };
}

describe("a tab starts waiting", () => {
  it("gives each admin a card, and neither the creator nor other members", async () => {
    const { ari, cara, bob, id } = await squad();
    const tab = await addTab(id, bob);
    await eventually(async () => {
      expect(
        (await card(ari, id, tab, "tabwaiting").get()).data(),
      ).toMatchObject({
        type: "tab_waiting",
        adventureId: id,
        adventureName: "Goa trip",
        tabId: tab.id,
      });
      expect((await card(cara, id, tab, "tabwaiting").get()).exists).toBe(true);
    });
    expect(await notices(bob, "tab_waiting")).toHaveLength(0);
  });

  it("an admin's own tab goes only to the other admin", async () => {
    const { ari, cara, bob, id } = await squad();
    const tab = await addTab(id, cara);
    await eventually(async () => {
      expect((await card(ari, id, tab, "tabwaiting").get()).exists).toBe(true);
    });
    expect(await notices(cara, "tab_waiting")).toHaveLength(0);
    expect(await notices(bob, "tab_waiting")).toHaveLength(0);
  });

  it("any later change into waiting tells the admins again", async () => {
    const { ari, bob, id } = await squad();
    const tab = await addTab(id, bob, "approved");
    await new Promise((r) => setTimeout(r, 1000));
    expect(await notices(ari, "tab_waiting")).toHaveLength(0);
    await tab.update({ status: "waiting" });
    await eventually(async () => {
      expect((await card(ari, id, tab, "tabwaiting").get()).exists).toBe(true);
    });
  });

  it("an approved tab from the only admin tells nobody", async () => {
    const ari = await person("Ari");
    const bob = await person("Bob");
    const id = await adventure(ari, { memberUids: [ari.uid, bob.uid] });
    await addTab(id, ari, "approved");
    await new Promise((r) => setTimeout(r, 1000));
    expect(await notices(ari, "tab_waiting")).toHaveLength(0);
    expect(await notices(bob, "tab_waiting")).toHaveLength(0);
  });

  it("a personal tab tells nobody", async () => {
    const { ari, cara, bob, id } = await squad();
    await addTab(id, bob, "personal");
    await new Promise((r) => setTimeout(r, 1000));
    expect(await notices(ari, "tab_waiting")).toHaveLength(0);
    expect(await notices(cara, "tab_waiting")).toHaveLength(0);
  });
});

describe("a waiting tab's cards never go stale", () => {
  async function waitingFor(
    admins: Person[],
    id: string,
    tab: FirebaseFirestore.DocumentReference,
  ) {
    await eventually(async () => {
      for (const a of admins) {
        expect((await card(a, id, tab, "tabwaiting").get()).exists).toBe(true);
      }
    });
  }

  async function goneFor(
    admins: Person[],
    id: string,
    tab: FirebaseFirestore.DocumentReference,
  ) {
    await eventually(async () => {
      for (const a of admins) {
        expect((await card(a, id, tab, "tabwaiting").get()).exists).toBe(false);
      }
    });
  }

  it("one admin's approval clears it for both, and tells the creator nothing", async () => {
    const { ari, cara, bob, id } = await squad();
    const tab = await addTab(id, bob);
    await waitingFor([ari, cara], id, tab);
    await tab.update({ status: "approved", decidedBy: ari.uid });
    await goneFor([ari, cara], id, tab);
    expect(await notices(bob, "tab_rejected")).toHaveLength(0);
  });

  it("a soft delete clears it", async () => {
    const { ari, cara, bob, id } = await squad();
    const tab = await addTab(id, bob);
    await waitingFor([ari, cara], id, tab);
    await tab.update({ deleted: true, deletedBy: ari.uid });
    await goneFor([ari, cara], id, tab);
  });

  it("clears it for an admin who has since been demoted", async () => {
    const { ari, cara, bob, id } = await squad();
    const tab = await addTab(id, bob);
    await waitingFor([ari, cara], id, tab);
    await db().doc(`adventures/${id}`).update({ coLeadUids: [] });
    await tab.update({ status: "approved", decidedBy: ari.uid });
    await goneFor([ari, cara], id, tab);
  });

  it("a new co-lead gets cards for tabs already waiting, except their own", async () => {
    const { ari, bob, id } = await squad();
    const dee = await person("Dee");
    await db()
      .doc(`adventures/${id}`)
      .update({ memberUids: [ari.uid, bob.uid, dee.uid], coLeadUids: [] });
    const bobs = await addTab(id, bob);
    const dees = await addTab(id, dee);
    await waitingFor([ari], id, bobs);
    await db()
      .doc(`adventures/${id}`)
      .update({ coLeadUids: [dee.uid] });
    await waitingFor([dee], id, bobs);
    expect((await card(dee, id, dees, "tabwaiting").get()).exists).toBe(false);
  });

  it("an automatic approval clears the cards and tells nobody", async () => {
    const { ari, cara, id } = await squad();
    const tab = await addTab(id, cara);
    await waitingFor([ari], id, tab);
    await tab.update({ status: "approved", decidedBy: "auto" });
    await goneFor([ari], id, tab);
    expect(await notices(cara, "tab_rejected")).toHaveLength(0);
    expect(await notices(ari, "tab_rejected")).toHaveLength(0);
  });
});

describe("a tab is rejected", () => {
  it("tells its creator, clears the admins' cards and tells no one else", async () => {
    const { ari, cara, bob, id } = await squad();
    const tab = await addTab(id, bob);
    await tab.update({ status: "rejected", decidedBy: ari.uid });
    await eventually(async () => {
      expect(
        (await card(bob, id, tab, "tabrejected").get()).data(),
      ).toMatchObject({
        type: "tab_rejected",
        adventureId: id,
        adventureName: "Goa trip",
        tabId: tab.id,
        description: "Dinner",
      });
      expect((await card(ari, id, tab, "tabwaiting").get()).exists).toBe(false);
      expect((await card(cara, id, tab, "tabwaiting").get()).exists).toBe(
        false,
      );
    });
    expect(await notices(ari, "tab_rejected")).toHaveLength(0);
    expect(await notices(cara, "tab_rejected")).toHaveLength(0);
  });

  it("the only admin rejecting their own tab hears nothing", async () => {
    const ari = await person("Ari");
    const id = await adventure(ari);
    const tab = await addTab(id, ari);
    await tab.update({ status: "rejected", decidedBy: ari.uid });
    await new Promise((r) => setTimeout(r, 1000));
    expect(await notices(ari, "tab_rejected")).toHaveLength(0);
  });

  it("the rejected card goes when the tab returns to waiting or is deleted", async () => {
    const { ari, bob, id } = await squad();
    const edited = await addTab(id, bob);
    const deleted = await addTab(id, bob);
    await edited.update({ status: "rejected", decidedBy: ari.uid });
    await deleted.update({ status: "rejected", decidedBy: ari.uid });
    await eventually(async () => {
      expect(await notices(bob, "tab_rejected")).toHaveLength(2);
    });
    await edited.update({ status: "waiting" });
    await deleted.update({ deleted: true, deletedBy: ari.uid });
    await eventually(async () => {
      expect(await notices(bob, "tab_rejected")).toHaveLength(0);
      expect((await card(ari, id, edited, "tabwaiting").get()).exists).toBe(
        true,
      );
    });
  });
});

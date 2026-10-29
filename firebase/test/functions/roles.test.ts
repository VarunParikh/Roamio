import { describe, expect, it } from "vitest";
import { getFirestore } from "../support/admin";
import { adventure, call, person } from "../support/callable";

const db = () => getFirestore();
const adv = async (id: string) => (await db().doc(`adventures/${id}`).get()).data();
const member = async (id: string, uid: string) =>
  (await db().doc(`adventures/${id}/members/${uid}`).get()).data();

/** Ari leads, Cara is co-lead, Bob and Dan are members. */
async function squad() {
  const [ari, cara, bob, dan] = await Promise.all(
    ["Ari", "Cara", "Bob", "Dan"].map((n) => person(n)),
  );
  const id = await adventure(ari, {
    coLeadUids: [cara.uid],
    memberUids: [ari.uid, cara.uid, bob.uid, dan.uid],
  });
  return { ari, cara, bob, dan, id };
}

describe("demoteCoLead (spec UC-15)", () => {
  it("lets the leader turn a co-lead back into a member", async () => {
    const { ari, cara, id } = await squad();
    expect((await call("demoteCoLead", { adventureId: id, memberUid: cara.uid }, ari)).error).toBeUndefined();
    expect((await adv(id))?.coLeadUids).toEqual([]);
    expect((await adv(id))?.memberUids).toContain(cara.uid);
    expect((await member(id, cara.uid))?.role).toBe("member");
  });

  it("is for the leader only, and only on co-leads", async () => {
    const { ari, cara, bob, id } = await squad();
    expect((await call("demoteCoLead", { adventureId: id, memberUid: ari.uid }, cara)).error?.status).toBe(
      "PERMISSION_DENIED",
    );
    expect((await call("demoteCoLead", { adventureId: id, memberUid: cara.uid }, bob)).error?.status).toBe(
      "PERMISSION_DENIED",
    );
    expect((await call("demoteCoLead", { adventureId: id, memberUid: bob.uid }, ari)).error?.status).toBe(
      "FAILED_PRECONDITION",
    );
    expect((await adv(id))?.coLeadUids).toEqual([cara.uid]);
  });
});

describe("removeMember: who can remove whom (spec UC-16)", () => {
  it("the leader can remove a co-lead", async () => {
    const { ari, cara, id } = await squad();
    expect((await call("removeMember", { adventureId: id, memberUid: cara.uid }, ari)).error).toBeUndefined();
    expect((await adv(id))?.coLeadUids).toEqual([]);
    expect((await adv(id))?.memberUids).not.toContain(cara.uid);
  });

  it("co-leads remove members but not other leads; nobody removes the leader or themselves", async () => {
    const { ari, cara, bob, id } = await squad();
    const cola = await person("Cola");
    await db()
      .doc(`adventures/${id}`)
      .update({ coLeadUids: [cara.uid, cola.uid], memberUids: [ari.uid, cara.uid, bob.uid, cola.uid] });

    for (const [by, target] of [
      [cara, cola],
      [cara, ari],
      [ari, ari],
      [cara, cara],
    ]) {
      const r = await call("removeMember", { adventureId: id, memberUid: target.uid }, by);
      expect(r.error?.status, `${by.uid} removing ${target.uid}`).toMatch(/PERMISSION_DENIED|FAILED_PRECONDITION/);
    }
    expect((await adv(id))?.memberUids).toEqual([ari.uid, cara.uid, bob.uid, cola.uid]);

    expect((await call("removeMember", { adventureId: id, memberUid: bob.uid }, cara)).error).toBeUndefined();
  });
});

describe("leaveAdventure (spec UC-16, UC-17)", () => {
  it("members and co-leads can leave; tab history keeps them as Left", async () => {
    const { ari, cara, bob, dan, id } = await squad();
    await db().doc(`adventures/${id}`).update({ hasTabs: true });
    await db()
      .doc(`adventures/${id}/tabs/t1`)
      .set({ payers: [{ id: bob.uid, amountMinor: 500 }], participants: [ari.uid] });

    expect((await call("leaveAdventure", { adventureId: id }, cara)).error).toBeUndefined();
    expect((await call("leaveAdventure", { adventureId: id }, bob)).error).toBeUndefined();

    const after = await adv(id);
    expect(after?.memberUids).toEqual([ari.uid, dan.uid]);
    expect(after?.coLeadUids).toEqual([]);
    expect(await member(id, cara.uid)).toBeUndefined();
    expect((await member(id, bob.uid))?.status).toBe("left");
  });

  it("the leader must hand over first while others remain", async () => {
    const { ari, id } = await squad();
    const r = await call("leaveAdventure", { adventureId: id }, ari);
    expect(r.error?.status).toBe("FAILED_PRECONDITION");
    expect(r.error?.message).toContain("squad leader");
    expect((await adv(id))?.leaderUid).toBe(ari.uid);
  });

  it("a leader on their own archives the adventure", async () => {
    const ari = await person("Ari");
    const id = await adventure(ari);
    expect((await call("leaveAdventure", { adventureId: id }, ari)).error).toBeUndefined();
    const after = await adv(id);
    expect(after?.archived).toBe(true);
    expect(after?.memberUids).toEqual([]);
  });

  it("outsiders can't leave what they're not in", async () => {
    const { id } = await squad();
    const eve = await person("Eve");
    expect((await call("leaveAdventure", { adventureId: id }, eve)).error?.status).toBe("FAILED_PRECONDITION");
  });
});

describe("handOverLeadership (spec UC-17)", () => {
  it("makes a member the leader; the old leader becomes a co-lead", async () => {
    const { ari, cara, bob, id } = await squad();
    expect((await call("handOverLeadership", { adventureId: id, memberUid: bob.uid }, ari)).error).toBeUndefined();
    const after = await adv(id);
    expect(after?.leaderUid).toBe(bob.uid);
    expect(after?.coLeadUids).toEqual([cara.uid, ari.uid]);
    expect((await member(id, bob.uid))?.role).toBe("leader");
    expect((await member(id, ari.uid))?.role).toBe("co_lead");

    // Now Ari can leave.
    expect((await call("leaveAdventure", { adventureId: id }, ari)).error).toBeUndefined();
  });

  it("works on a co-lead, who stops being listed as co-lead", async () => {
    const { ari, cara, id } = await squad();
    await call("handOverLeadership", { adventureId: id, memberUid: cara.uid }, ari);
    const after = await adv(id);
    expect(after?.leaderUid).toBe(cara.uid);
    expect(after?.coLeadUids).toEqual([ari.uid]);
  });

  it("is for the leader only, to a current member", async () => {
    const { ari, cara, bob, id } = await squad();
    const eve = await person("Eve");
    expect((await call("handOverLeadership", { adventureId: id, memberUid: cara.uid }, cara)).error?.status).toBe(
      "PERMISSION_DENIED",
    );
    expect((await call("handOverLeadership", { adventureId: id, memberUid: bob.uid }, cara)).error?.status).toBe(
      "PERMISSION_DENIED",
    );
    expect((await call("handOverLeadership", { adventureId: id, memberUid: eve.uid }, ari)).error?.status).toBe(
      "FAILED_PRECONDITION",
    );
    expect((await call("handOverLeadership", { adventureId: id, memberUid: ari.uid }, ari)).error?.status).toBe(
      "FAILED_PRECONDITION",
    );
    expect((await adv(id))?.leaderUid).toBe(ari.uid);
  });
});

describe("joining an archived adventure", () => {
  it("is refused", async () => {
    const ari = await person("Ari");
    const bob = await person("Bob");
    const id = await adventure(ari);
    const code = String((await call("createInvite", { adventureId: id }, ari)).result?.code);
    await db().doc(`adventures/${id}`).update({ archived: true });
    expect((await call("joinAdventure", { code }, bob)).error?.status).toBe("FAILED_PRECONDITION");
  });
});

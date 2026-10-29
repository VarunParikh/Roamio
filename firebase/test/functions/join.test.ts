import { describe, expect, it } from "vitest";
import { getFirestore } from "../support/admin";
import { adventure, call, type Person, person } from "../support/callable";

const db = () => getFirestore();

async function inviteTo(id: string, lead: Person): Promise<string> {
  return String((await call("createInvite", { adventureId: id }, lead)).result?.code);
}

const card = (leadUid: string, id: string, memberUid: string) =>
  db().doc(`users/${leadUid}/notifications/${id}_joined_${memberUid}`).get();

describe("joinAdventure (spec UC-13, UC-14)", () => {
  it("adds the invitee as a member and gives every lead a card", async () => {
    const ari = await person("Ari");
    const cara = await person("Cara");
    const bob = await person("Bob Lee");
    const id = await adventure(ari, { coLeadUids: [cara.uid], memberUids: [ari.uid, cara.uid] });
    const code = await inviteTo(id, ari);

    const r = await call("joinAdventure", { code }, bob);
    expect(r.result).toEqual({ adventureId: id, alreadyMember: false });

    const adv = (await db().doc(`adventures/${id}`).get()).data();
    expect(adv?.memberUids).toEqual([ari.uid, cara.uid, bob.uid]);
    expect(adv?.coLeadUids).toEqual([cara.uid]);
    const member = (await db().doc(`adventures/${id}/members/${bob.uid}`).get()).data();
    expect(member).toMatchObject({ role: "member", status: "active" });

    for (const lead of [ari, cara]) {
      expect((await card(lead.uid, id, bob.uid)).data()).toMatchObject({
        type: "member_joined",
        adventureId: id,
        adventureName: "College group Bangkok adventure",
        memberUid: bob.uid,
        memberName: "Bob Lee",
      });
    }
    const activity = await db().collection(`adventures/${id}/activity`).get();
    expect(activity.docs.map((d) => d.get("type"))).toEqual(["member_joined"]);
  });

  it("someone who left and rejoins is no longer listed as Left", async () => {
    const ari = await person("Ari");
    const bob = await person("Bob");
    const id = await adventure(ari, { leftUids: [bob.uid] });
    const code = await inviteTo(id, ari);

    expect((await call("joinAdventure", { code }, bob)).error).toBeUndefined();

    const adv = (await db().doc(`adventures/${id}`).get()).data();
    expect(adv?.memberUids).toEqual([ari.uid, bob.uid]);
    expect(adv?.leftUids).toEqual([]);
  });

  it("is a no-op for someone already in the squad", async () => {
    const ari = await person("Ari");
    const bob = await person("Bob");
    const id = await adventure(ari);
    const code = await inviteTo(id, ari);
    await call("joinAdventure", { code }, bob);
    await (await card(ari.uid, id, bob.uid)).ref.delete();

    const again = await call("joinAdventure", { code }, bob);
    expect(again.result).toEqual({ adventureId: id, alreadyMember: true });
    const adv = (await db().doc(`adventures/${id}`).get()).data();
    expect(adv?.memberUids).toEqual([ari.uid, bob.uid]);
    expect((await card(ari.uid, id, bob.uid)).exists).toBe(false);

    const own = await call("joinAdventure", { code }, ari);
    expect(own.result).toEqual({ adventureId: id, alreadyMember: true });
  });

  it("refuses an adventure that has already ended", async () => {
    const ari = await person("Ari");
    const bob = await person("Bob");
    const id = await adventure(ari);
    const code = await inviteTo(id, ari);
    await db().doc(`adventures/${id}`).update({ endDate: "2020-01-08" });

    const r = await call("joinAdventure", { code }, bob);
    expect(r.error?.status).toBe("FAILED_PRECONDITION");
    expect(r.error?.message).toContain("ended");
    expect((await db().doc(`adventures/${id}`).get()).get("memberUids")).toEqual([ari.uid]);
  });

  it("refuses a minor still waiting for a parent's OK, and frozen accounts", async () => {
    const ari = await person("Ari");
    const pete = await person("Pete", "minor_pending");
    const fay = await person("Fay", "minor_frozen");
    const mia = await person("Mia", "minor_active");
    const id = await adventure(ari);
    const code = await inviteTo(id, ari);

    for (const who of [pete, fay]) {
      const r = await call("joinAdventure", { code }, who);
      expect(r.error?.status).toBe("FAILED_PRECONDITION");
      expect((await db().doc(`adventures/${id}/members/${who.uid}`).get()).exists).toBe(false);
    }
    expect((await call("joinAdventure", { code }, mia)).result?.alreadyMember).toBe(false);
  });

  it("refuses revoked codes and anonymous callers", async () => {
    const ari = await person("Ari");
    const bob = await person("Bob");
    const id = await adventure(ari);
    const code = await inviteTo(id, ari);
    expect((await call("joinAdventure", { code })).error?.status).toBe("UNAUTHENTICATED");

    await call("revokeInvite", { adventureId: id }, ari);
    expect((await call("joinAdventure", { code }, bob)).error?.status).toBe("FAILED_PRECONDITION");
  });
});

/** A squad where Bob has just joined via the invite. */
async function squadWithNewcomer() {
  const ari = await person("Ari");
  const cara = await person("Cara");
  const bob = await person("Bob");
  const id = await adventure(ari, { coLeadUids: [cara.uid], memberUids: [ari.uid, cara.uid] });
  await db().doc(`adventures/${id}/members/${cara.uid}`).set({ role: "co_lead", status: "active" });
  await call("joinAdventure", { code: await inviteTo(id, ari) }, bob);
  return { ari, cara, bob, id };
}

describe("makeCoLead (card action, spec UC-14, UC-15)", () => {
  it("lets the leader promote a member and clears every lead's card", async () => {
    const { ari, cara, bob, id } = await squadWithNewcomer();

    expect((await call("makeCoLead", { adventureId: id, memberUid: bob.uid }, ari)).error).toBeUndefined();
    const adv = (await db().doc(`adventures/${id}`).get()).data();
    expect(adv?.coLeadUids).toEqual([cara.uid, bob.uid]);
    expect((await db().doc(`adventures/${id}/members/${bob.uid}`).get()).get("role")).toBe("co_lead");
    expect((await card(ari.uid, id, bob.uid)).exists).toBe(false);
    expect((await card(cara.uid, id, bob.uid)).exists).toBe(false);
  });

  it("is for the squad leader only", async () => {
    const { cara, bob, id } = await squadWithNewcomer();
    const dan = await person("Dan");
    for (const who of [cara, bob, dan]) {
      const r = await call("makeCoLead", { adventureId: id, memberUid: bob.uid }, who);
      expect(r.error?.status).toBe("PERMISSION_DENIED");
    }
    expect((await db().doc(`adventures/${id}`).get()).get("coLeadUids")).toEqual([cara.uid]);
  });

  it("only promotes current members", async () => {
    const { ari, id } = await squadWithNewcomer();
    const dan = await person("Dan");
    const r = await call("makeCoLead", { adventureId: id, memberUid: dan.uid }, ari);
    expect(r.error?.status).toBe("FAILED_PRECONDITION");
  });
});

describe("removeMember (card action, spec UC-14, UC-16)", () => {
  it("lets a lead remove a newcomer with no tabs, and clears the cards", async () => {
    const { ari, cara, bob, id } = await squadWithNewcomer();

    expect((await call("removeMember", { adventureId: id, memberUid: bob.uid }, cara)).error).toBeUndefined();
    expect((await db().doc(`adventures/${id}`).get()).get("memberUids")).toEqual([ari.uid, cara.uid]);
    expect((await db().doc(`adventures/${id}/members/${bob.uid}`).get()).exists).toBe(false);
    expect((await card(ari.uid, id, bob.uid)).exists).toBe(false);
    expect((await card(cara.uid, id, bob.uid)).exists).toBe(false);
  });

  it("marks someone on a tab as Left instead of deleting them", async () => {
    const { ari, bob, id } = await squadWithNewcomer();
    await db().doc(`adventures/${id}`).update({ hasTabs: true });
    await db().doc(`adventures/${id}/tabs/t1`).set({
      payers: [{ id: ari.uid, amountMinor: 1000 }],
      participants: [ari.uid, bob.uid],
    });

    await call("removeMember", { adventureId: id, memberUid: bob.uid }, ari);
    expect((await db().doc(`adventures/${id}`).get()).get("memberUids")).not.toContain(bob.uid);
    expect((await db().doc(`adventures/${id}/members/${bob.uid}`).get()).data()).toMatchObject({
      role: "member",
      status: "left",
    });
  });

  it("can't be used by members, or on leads", async () => {
    const { ari, cara, bob, id } = await squadWithNewcomer();
    const r = await call("removeMember", { adventureId: id, memberUid: cara.uid }, bob);
    expect(r.error?.status).toBe("PERMISSION_DENIED");

    for (const target of [ari, cara]) {
      const s = await call("removeMember", { adventureId: id, memberUid: target.uid }, cara);
      expect(s.error?.status).toBe("FAILED_PRECONDITION");
    }
    expect((await db().doc(`adventures/${id}`).get()).get("memberUids")).toEqual([
      ari.uid,
      cara.uid,
      bob.uid,
    ]);
  });
});

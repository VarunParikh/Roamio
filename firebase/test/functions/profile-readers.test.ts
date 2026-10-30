import { describe, expect, it } from "vitest";
import { getFirestore } from "../support/admin";
import { adventure, call, type Person, person } from "../support/callable";
import { eraseAccount } from "../../functions/src/privacy/deleteAccount";

// Follow-up S3b: profiles are visible only to people who share a squad.
// profileReaders/{uid}.uids is that list, kept by the server.

const db = () => getFirestore();
const readers = async (uid: string): Promise<string[]> =>
  ((await db().doc(`profileReaders/${uid}`).get()).get("uids") as string[]) ?? [];

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

async function join(id: string, lead: Person, who: Person) {
  const code = (await call("createInvite", { adventureId: id }, lead)).result?.code;
  expect((await call("joinAdventure", { code }, who)).error).toBeUndefined();
}

describe("profileReaders (follow-up S3b)", () => {
  it("joining lets the newcomer and the squad see each other at once", async () => {
    const ari = await person("Ari");
    const cara = await person("Cara");
    const bob = await person("Bob");
    const id = await adventure(ari, { memberUids: [ari.uid, cara.uid] });

    await join(id, ari, bob);

    // Straight away, not after a trigger: the joiner opens the squad next.
    expect(await readers(bob.uid)).toEqual(expect.arrayContaining([ari.uid, cara.uid]));
    expect(await readers(ari.uid)).toContain(bob.uid);
    expect(await readers(cara.uid)).toContain(bob.uid);
  });

  it("follows the squads: someone removed with no tabs stops being visible", async () => {
    const ari = await person("Ari");
    const bob = await person("Bob");
    const id = await adventure(ari);
    await join(id, ari, bob);

    expect((await call("removeMember", { adventureId: id, memberUid: bob.uid }, ari)).error)
      .toBeUndefined();

    await eventually(async () => {
      expect(await readers(ari.uid)).not.toContain(bob.uid);
      expect(await readers(bob.uid)).not.toContain(ari.uid);
    });
  });

  it("keeps people who left but are on a tab (they still appear on it)", async () => {
    const ari = await person("Ari");
    const bob = await person("Bob");
    const id = await adventure(ari);
    await join(id, ari, bob);
    await db()
      .doc(`adventures/${id}/tabs/t1`)
      .set({ payers: [{ id: bob.uid, amountMinor: 500 }], participants: [ari.uid, bob.uid] });

    expect((await call("leaveAdventure", { adventureId: id }, bob)).error).toBeUndefined();
    // Give the trigger time to run, then check nothing was taken away.
    await new Promise((r) => setTimeout(r, 1500));
    expect(await readers(ari.uid)).toContain(bob.uid);
    expect(await readers(bob.uid)).toContain(ari.uid);
  });

  it("is deleted with the account", async () => {
    const ari = await person("Ari");
    const bob = await person("Bob");
    const id = await adventure(ari);
    await join(id, ari, bob);

    await eraseAccount(bob.uid, { removeAvatars: async () => {} });

    expect((await db().doc(`profileReaders/${bob.uid}`).get()).exists).toBe(false);
  });
});

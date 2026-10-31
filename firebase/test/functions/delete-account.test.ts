import { describe, expect, it } from "vitest";
import { getAuth, getFirestore, getStorage } from "../support/admin";
import { adventure, call, person } from "../support/callable";
import { eraseAccount } from "../../functions/src/privacy/deleteAccount";

const db = () => getFirestore();

/** Stands in for Cloud Storage, which isn't in every test environment. */
function files() {
  const removed: string[] = [];
  return { removed, removeAvatars: async (uid: string) => void removed.push(uid) };
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

describe("eraseAccount (spec §8: erasure)", () => {
  it("erases profile, budgets, photos and sign-in, but tabs and balances stay", async () => {
    const ari = await person("Ari");
    const bob = await person("Bob");
    const id = await adventure(ari, { memberUids: [ari.uid, bob.uid], hasTabs: true });
    const tabRef = db().collection(`adventures/${id}/tabs`).doc();
    await tabRef.set(tab(bob.uid, { participants: [ari.uid, bob.uid] }));
    await db().doc(`adventures/${id}/budgets/${bob.uid}`).set({ amountMinor: 50000, currency: "THB" });
    await db().doc(`users/${bob.uid}/notifications/n1`).set({ type: "budget_alert" });
    const f = files();

    await db().doc(`rate_rechecks/${id}_${bob.uid}`).set({ aid: id, uid: bob.uid });
    await eraseAccount(bob.uid, f);

    expect((await db().doc(`users/${bob.uid}`).get()).exists).toBe(false);
    expect((await db().doc(`users/${bob.uid}/private/account`).get()).exists).toBe(false);
    expect((await db().doc(`users/${bob.uid}/notifications/n1`).get()).exists).toBe(false);
    expect((await db().doc(`adventures/${id}/budgets/${bob.uid}`).get()).exists).toBe(false);
    expect((await db().doc(`rate_rechecks/${id}_${bob.uid}`).get()).exists).toBe(false);
    await expect(getAuth().getUser(bob.uid)).rejects.toThrow();
    expect(f.removed).toEqual([bob.uid]);

    // The tab, who paid and who shared are untouched, so every balance is too.
    const kept = (await tabRef.get()).data();
    expect(kept?.payers).toEqual([{ id: bob.uid, amountMinor: 90000 }]);
    expect(kept?.participants).toEqual([ari.uid, bob.uid]);
    // They are out of the squad but kept as Left, because they are on a tab.
    const adv = (await db().doc(`adventures/${id}`).get()).data();
    expect(adv?.memberUids).toEqual([ari.uid]);
    expect((await db().doc(`adventures/${id}/members/${bob.uid}`).get()).data()?.status).toBe("left");
  });

  it("removes a member with no tab history outright", async () => {
    const ari = await person("Ari");
    const dan = await person("Dan");
    const id = await adventure(ari, { memberUids: [ari.uid, dan.uid] });
    await db().doc(`adventures/${id}/members/${dan.uid}`).set({ role: "member", status: "active" });

    await eraseAccount(dan.uid, files());

    expect((await db().doc(`adventures/${id}`).get()).get("memberUids")).toEqual([ari.uid]);
    expect((await db().doc(`adventures/${id}/members/${dan.uid}`).get()).exists).toBe(false);
  });

  it("records who deleted what, and when, in the audit log (kept a year)", async () => {
    const eve = await person("Eve");
    await eraseAccount(eve.uid, files());
    const log = await db().collection("auditLog").where("target", "==", eve.uid).get();
    expect(log.docs.map((d) => [d.get("action"), d.get("actorUid")])).toEqual([
      ["account_deleted", eve.uid],
    ]);
    expect(log.docs[0].get("at")).toBeDefined();
  });

  it("makes a squad leader hand over first, and erases nothing meanwhile", async () => {
    const ari = await person("Ari");
    const bob = await person("Bob");
    await adventure(ari, { memberUids: [ari.uid, bob.uid] });
    const f = files();

    await expect(eraseAccount(ari.uid, f)).rejects.toMatchObject({ code: "failed-precondition" });

    expect((await db().doc(`users/${ari.uid}`).get()).exists).toBe(true);
    await expect(getAuth().getUser(ari.uid)).resolves.toBeDefined();
    expect(f.removed).toEqual([]);
  });

  it("archives an adventure when its only member deletes their account", async () => {
    const ari = await person("Ari");
    const id = await adventure(ari);
    await eraseAccount(ari.uid, files());
    expect((await db().doc(`adventures/${id}`).get()).get("archived")).toBe(true);
  });

  it("asks a parent to confirm before their linked children are left", async () => {
    const parent = await person("Pia");
    const child = await person("Mia", "minor_active");
    await db().doc(`parentalConsents/${child.uid}`).set({ status: "granted", parentUid: parent.uid });

    await expect(eraseAccount(parent.uid, files())).rejects.toMatchObject({
      code: "failed-precondition",
    });
    await expect(
      eraseAccount(parent.uid, { ...files(), confirmLinkedChildren: true }),
    ).resolves.toBeUndefined();

    // The child's consent record stays valid (spec §7.5).
    expect((await db().doc(`parentalConsents/${child.uid}`).get()).get("status")).toBe("granted");
  });
});

describe("deleteMyAccount (callable)", () => {
  it("needs a signed-in caller", async () => {
    expect((await call("deleteMyAccount", {})).error?.status).toBe("UNAUTHENTICATED");
  });

  it("tells a squad leader to hand over first", async () => {
    const ari = await person("Ari");
    const bob = await person("Bob");
    await adventure(ari, { memberUids: [ari.uid, bob.uid] });
    const res = await call("deleteMyAccount", {}, ari);
    expect(res.error?.status).toBe("FAILED_PRECONDITION");
    expect(res.error?.message).toContain("squad leader");
  });
});

// Needs the Storage emulator, which CI runs; some machines can't download it.
describe.skipIf(!process.env.FIREBASE_STORAGE_EMULATOR_HOST)("deleteMyAccount with photos", () => {
  it("removes the profile photo from Cloud Storage and the account entirely", async () => {
    const ari = await person("Ari");
    const bucket = getStorage().bucket("demo-roamio.appspot.com");
    const mine = bucket.file(`users/${ari.uid}/avatar/a.webp`);
    const other = bucket.file(`users/someone-else/avatar/a.webp`);
    await mine.save("x");
    await other.save("x");

    expect((await call("deleteMyAccount", {}, ari)).error).toBeUndefined();

    expect((await mine.exists())[0]).toBe(false);
    expect((await other.exists())[0]).toBe(true);
    expect((await db().doc(`users/${ari.uid}`).get()).exists).toBe(false);
    await expect(getAuth().getUser(ari.uid)).rejects.toThrow();
  });
});

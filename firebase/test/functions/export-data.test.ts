import { execFileSync } from "node:child_process";
import { mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { describe, expect, it } from "vitest";
import { getFirestore, Timestamp } from "../support/admin";
import { adventure, call, person } from "../support/callable";
import {
  collectData,
  photoParts,
  photoPrefixes,
  zipStored,
} from "../../functions/src/privacy/exportData";

const db = () => getFirestore();

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

/** Links a child to a parent the way a granted consent does. */
async function linkChild(
  childUid: string,
  parentUid: string,
  status = "granted",
) {
  await db().doc(`parentalConsents/${childUid}`).set({
    childUid,
    parentUid,
    parentEmail: "parent@example.com",
    status,
    tokenHash: "secret-hash",
    decidedAt: Timestamp.now(),
  });
}

describe("collectData (spec UC-29: download my data)", () => {
  it("has the person's own records, and only the tabs, payments and budget that are theirs", async () => {
    const ari = await person("Ari");
    const bob = await person("Bob");
    const cat = await person("Cat");
    const id = await adventure(ari, {
      memberUids: [ari.uid, bob.uid, cat.uid],
    });
    await db()
      .doc(`adventures/${id}/members/${bob.uid}`)
      .set({ role: "member", status: "active" });
    await db().doc(`adventures/${id}/tabs/mine`).set(tab(bob.uid));
    await db()
      .doc(`adventures/${id}/tabs/shared`)
      .set(tab(ari.uid, { participants: [ari.uid, bob.uid] }));
    await db()
      .doc(`adventures/${id}/tabs/notMine`)
      .set(tab(ari.uid, { participants: [ari.uid, cat.uid] }));
    await db()
      .doc(`adventures/${id}/settlements/s1`)
      .set({
        from: bob.uid,
        to: ari.uid,
        amountMinor: 100,
        recordedBy: bob.uid,
      });
    await db()
      .doc(`adventures/${id}/settlements/s2`)
      .set({
        from: cat.uid,
        to: ari.uid,
        amountMinor: 100,
        recordedBy: cat.uid,
      });
    await db()
      .doc(`adventures/${id}/budgets/${bob.uid}`)
      .set({ amountMinor: 50000, currency: "THB" });
    await db()
      .doc(`adventures/${id}/budgets/${cat.uid}`)
      .set({ amountMinor: 70000, currency: "THB" });
    await db()
      .doc(`users/${bob.uid}/notifications/n1`)
      .set({ type: "budget_alert", createdAt: Timestamp.now() });

    const data = await collectData(bob.uid);

    expect(data.you.uid).toBe(bob.uid);
    expect(data.you.profile?.name).toBe("Bob");
    expect(data.you.account?.dob).toBe("2000-01-01");
    expect(data.you.notifications.map((n) => n.id)).toEqual(["n1"]);
    // Firestore times come out as readable ISO text.
    expect(data.you.notifications[0].createdAt).toMatch(/^\d{4}-\d\d-\d\dT/);
    const [adv] = data.adventures;
    expect(adv.id).toBe(id);
    expect(adv.role).toBe("member");
    expect(adv.tabs.map((t) => t.id).sort()).toEqual(["mine", "shared"]);
    expect(adv.settlements.map((s) => s.id)).toEqual(["s1"]);
    expect(adv.budget?.amountMinor).toBe(50000);
    // Nobody else's budget leaks into the file.
    expect(JSON.stringify(data)).not.toContain("70000");
  });

  it("includes a child's own consent record without the link secret, and a parent's linked children", async () => {
    const mum = await person("Mum");
    const kid = await person("Kid", "minor_active");
    await linkChild(kid.uid, mum.uid);

    const kidData = await collectData(kid.uid);
    expect(kidData.parentalConsent?.status).toBe("granted");
    expect(JSON.stringify(kidData)).not.toContain("secret-hash");

    const mumData = await collectData(mum.uid);
    expect(mumData.linkedChildren.map((c) => [c.childUid, c.status])).toEqual([
      [kid.uid, "granted"],
    ]);
    expect(JSON.stringify(mumData)).not.toContain("secret-hash");
  });
});

describe("exportMyData callable (who may download what)", () => {
  it("needs a signed-in caller", async () => {
    const res = await call("exportMyData", {});
    expect(res.error?.status).toBe("UNAUTHENTICATED");
  });

  it("gives a person their own data and records the download in the audit log", async () => {
    const eve = await person("Eve");
    const res = await call("exportMyData", {}, eve);
    expect(res.error).toBeUndefined();
    const data = res.result?.data as { you: { uid: string } };
    expect(data.you.uid).toBe(eve.uid);
    expect(res.result?.photoParts).toBe(0);

    const log = await db()
      .collection("auditLog")
      .where("target", "==", eve.uid)
      .get();
    expect(log.docs.map((d) => [d.get("action"), d.get("actorUid")])).toEqual([
      ["data_exported", eve.uid],
    ]);
  });

  it("lets a parent download a linked child's data, budget included (spec §7.2, §7.3)", async () => {
    const mum = await person("Mum");
    const kid = await person("Kid", "minor_active");
    await linkChild(kid.uid, mum.uid);
    const id = await adventure(kid);
    await db()
      .doc(`adventures/${id}/budgets/${kid.uid}`)
      .set({ amountMinor: 1200, currency: "THB" });

    const res = await call("exportMyData", { childUid: kid.uid }, mum);

    expect(res.error).toBeUndefined();
    const data = res.result?.data as {
      you: { uid: string };
      adventures: { budget: { amountMinor: number } }[];
    };
    expect(data.you.uid).toBe(kid.uid);
    expect(data.adventures[0].budget.amountMinor).toBe(1200);
    const log = await db()
      .collection("auditLog")
      .where("target", "==", kid.uid)
      .get();
    expect(log.docs.map((d) => [d.get("action"), d.get("actorUid")])).toEqual([
      ["data_exported", mum.uid],
    ]);
  });

  it("refuses anyone else's data: a stranger, or a parent whose consent isn't granted", async () => {
    const mum = await person("Mum");
    const stranger = await person("Sam");
    const kid = await person("Kid", "minor_active");
    await linkChild(kid.uid, mum.uid);
    const other = await person("Other");

    expect(
      (await call("exportMyData", { childUid: kid.uid }, stranger)).error
        ?.status,
    ).toBe("PERMISSION_DENIED");
    // An adult isn't anyone's linked child.
    expect(
      (await call("exportMyData", { childUid: other.uid }, mum)).error?.status,
    ).toBe("PERMISSION_DENIED");
    for (const status of ["requested", "declined", "withdrawn", "aged_out"]) {
      await linkChild(kid.uid, mum.uid, status);
      expect(
        (await call("exportMyData", { childUid: kid.uid }, mum)).error?.status,
      ).toBe("PERMISSION_DENIED");
    }
    const log = await db()
      .collection("auditLog")
      .where("target", "==", kid.uid)
      .get();
    expect(log.empty).toBe(true);
  });

  it("rejects a photo part that doesn't exist", async () => {
    const eve = await person("Eve");
    const res = await call("exportMyData", { photosPart: 0 }, eve);
    expect(res.error?.status).toBe("INVALID_ARGUMENT");
  });
});

describe("photos zip", () => {
  it("looks for the profile photos and the memories on tabs the person added", async () => {
    const ari = await person("Ari");
    const bob = await person("Bob");
    const id = await adventure(ari, { memberUids: [ari.uid, bob.uid] });
    await db().doc(`adventures/${id}/tabs/byBob`).set(tab(bob.uid));
    await db()
      .doc(`adventures/${id}/tabs/byAri`)
      .set(tab(ari.uid, { participants: [ari.uid, bob.uid] }));

    expect(await photoPrefixes(bob.uid)).toEqual([
      `users/${bob.uid}/avatar/`,
      `adventures/${id}/tabs/byBob/`,
    ]);
  });

  it("packs photos into parts under the size limit, each photo exactly once", () => {
    const files = [
      { name: "a.webp", size: 400 },
      { name: "b.webp", size: 400 },
      { name: "c.webp", size: 300 },
      { name: "big.webp", size: 1500 },
      { name: "d.webp", size: 100 },
    ];
    const parts = photoParts(files, 1000);
    expect(parts.map((p) => p.map((f) => f.name))).toEqual([
      ["a.webp", "b.webp"],
      ["c.webp"],
      ["big.webp"],
      ["d.webp"],
    ]);
    expect(photoParts([], 1000)).toEqual([]);
  });

  it("writes a zip that unzip accepts, with every file intact", () => {
    const zip = zipStored([
      { name: "users/u1/avatar/one.webp", data: Buffer.from("RIFF-photo-one") },
      { name: "adventures/a/tabs/t/two.webp", data: Buffer.alloc(70_000, 7) },
    ]);
    const dir = mkdtempSync(join(tmpdir(), "roamio-zip-"));
    const file = join(dir, "photos.zip");
    writeFileSync(file, zip);

    expect(execFileSync("unzip", ["-t", file]).toString()).toContain(
      "No errors detected",
    );
    expect(
      execFileSync("unzip", [
        "-p",
        file,
        "users/u1/avatar/one.webp",
      ]).toString(),
    ).toBe("RIFF-photo-one");
  });
});

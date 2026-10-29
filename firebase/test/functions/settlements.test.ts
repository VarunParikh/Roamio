import { describe, expect, it } from "vitest";
import { notifyFor } from "../../functions/src/splits/settlements";
import { getFirestore } from "../support/admin";
import { adventure, person } from "../support/callable";

const db = () => getFirestore();

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

describe("notifyFor (spec UC-26a: the other member gets a notification)", () => {
  const members = ["ari", "ben", "cara"];

  it("tells the other party when one of them records it", () => {
    expect(notifyFor({ from: "ben", to: "ari", recordedBy: "ben" }, members)).toEqual(["ari"]);
    expect(notifyFor({ from: "ben", to: "ari", recordedBy: "ari" }, members)).toEqual(["ben"]);
  });

  it("tells the member involved when a lead records a pal's payment", () => {
    expect(notifyFor({ from: "kiko", to: "ari", recordedBy: "cara" }, members)).toEqual(["ari"]);
  });

  it("never notifies pals or the person who recorded it", () => {
    expect(notifyFor({ from: "kiko", to: "ari", recordedBy: "ari" }, members)).toEqual([]);
  });
});

describe("settlement activity (spec UC-26a)", () => {
  it("logs who recorded it, and who undid it", async () => {
    const ari = await person("Ari");
    const ben = await person("Ben");
    const id = await adventure(ari, { memberUids: [ari.uid, ben.uid] });
    const ref = db().collection(`adventures/${id}/settlements`).doc();
    await ref.set({
      from: ben.uid,
      to: ari.uid,
      amountMinor: 50000,
      currency: "INR",
      date: "2026-10-29",
      recordedBy: ben.uid,
      undone: false,
    });
    const log = async () =>
      (await db().collection(`adventures/${id}/activity`).where("subject", "==", ref.id).get()).docs
        .map((d) => [d.get("type"), d.get("actorUid")])
        .sort();

    await eventually(async () => {
      expect(await log()).toEqual([["settlement_recorded", ben.uid]]);
    });

    await ref.update({ undone: true, undoneBy: ari.uid });
    await eventually(async () => {
      expect(await log()).toEqual([
        ["settlement_recorded", ben.uid],
        ["settlement_undone", ari.uid],
      ]);
    });
  });
});

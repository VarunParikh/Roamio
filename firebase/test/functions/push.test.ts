import { describe, expect, it } from "vitest";
import { pushTargets, sendPush } from "../../functions/src/notify/push";
import { getFirestore } from "../support/admin";
import { adventure, call, person } from "../support/callable";

const db = () => getFirestore();

describe("pushTargets (consent per purpose, spec §8)", () => {
  it("only devices of people who turned notifications on", () => {
    expect(
      pushTargets([
        { fcmTokens: ["a1", "a2"], consents: { notifications: true } },
        { fcmTokens: ["b1"], consents: { notifications: false } },
        { fcmTokens: ["c1"], consents: {} },
        { fcmTokens: ["c2"] },
        { consents: { notifications: true } },
        { fcmTokens: ["a2", "d1"], consents: { notifications: true } },
      ]),
    ).toEqual(["a1", "a2", "d1"]);
  });
});

describe("sendPush", () => {
  it("targets consenting leads' devices (logged, not sent, in the emulator)", async () => {
    const ari = await person("Ari");
    const cara = await person("Cara");
    await db()
      .doc(`users/${ari.uid}/private/account`)
      .set({ fcmTokens: ["ari-phone"], consents: { notifications: true } }, { merge: true });
    await db()
      .doc(`users/${cara.uid}/private/account`)
      .set({ fcmTokens: ["cara-phone"], consents: { notifications: false } }, { merge: true });

    const sent = await sendPush([ari.uid, cara.uid, "nobody"], {
      title: "Bob joined your squad",
      body: "Bangkok",
      data: { type: "member_joined" },
    });
    expect(sent).toEqual(["ari-phone"]);
  });
});

describe("joinAdventure still joins when push can't be sent", () => {
  it("adds the member", async () => {
    const ari = await person("Ari");
    const bob = await person("Bob");
    await db()
      .doc(`users/${ari.uid}/private/account`)
      .set({ fcmTokens: ["ari-phone"], consents: { notifications: true } }, { merge: true });
    const id = await adventure(ari);
    const code = String((await call("createInvite", { adventureId: id }, ari)).result?.code);
    expect((await call("joinAdventure", { code }, bob)).result?.alreadyMember).toBe(false);
  });
});

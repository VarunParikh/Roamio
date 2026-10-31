import { describe, expect, it } from "vitest";
import { formatCode, normaliseCode } from "../../functions/src/invites/code";
import { adventure, call, FUNCTIONS, person } from "../support/callable";
import { getFirestore, Timestamp } from "../support/admin";

describe("invite codes", () => {
  it("are typed back loosely and shown in two groups", () => {
    expect(normaliseCode(" 7kq2-m9xa ")).toBe("7KQ2M9XA");
    expect(normaliseCode("https://roamio-dev-varun.web.app/i/7KQ2M9XA")).toBe(
      "7KQ2M9XA",
    );
    expect(normaliseCode("7KQ2 M9XA")).toBe("7KQ2M9XA");
    expect(normaliseCode("hello")).toBeNull();
    expect(normaliseCode("7KQ2M9X0")).toBeNull(); // 0 is never used: looks like O
    expect(formatCode("7KQ2M9XA")).toBe("7KQ2-M9XA");
  });
});

describe("createInvite (spec UC-9)", () => {
  it("gives a lead an 8-character code valid for 14 days, reused until it changes", async () => {
    const ari = await person("Ari");
    const id = await adventure(ari);

    const first = await call("createInvite", { adventureId: id }, ari);
    const code = String(first.result?.code);
    expect(code).toMatch(/^[A-HJ-NP-Z2-9]{8}$/);
    const invite = (await getFirestore().doc(`invites/${code}`).get()).data();
    expect(invite?.adventureId).toBe(id);
    expect(invite?.adventureName).toBe("College group Bangkok adventure");
    expect(invite?.leaderName).toBe("Ari");
    const days =
      ((invite?.expiresAt as Timestamp).toMillis() - Date.now()) / 86_400_000;
    expect(days).toBeGreaterThan(13.9);
    expect(days).toBeLessThanOrEqual(14);

    const again = await call("createInvite", { adventureId: id }, ari);
    expect(again.result?.code).toBe(code);
  });

  it("lets co-leads share too, but not members or outsiders", async () => {
    const ari = await person("Ari");
    const cara = await person("Cara");
    const bob = await person("Bob");
    const dan = await person("Dan");
    const id = await adventure(ari, {
      coLeadUids: [cara.uid],
      memberUids: [ari.uid, cara.uid, bob.uid],
    });

    expect(
      (await call("createInvite", { adventureId: id }, cara)).result?.code,
    ).toBeTruthy();
    expect(
      (await call("createInvite", { adventureId: id }, bob)).error?.status,
    ).toBe("PERMISSION_DENIED");
    expect(
      (await call("createInvite", { adventureId: id }, dan)).error?.status,
    ).toBe("PERMISSION_DENIED");
  });

  it("replaces an expired invite with a new code", async () => {
    const ari = await person("Ari");
    const id = await adventure(ari);
    const old = String(
      (await call("createInvite", { adventureId: id }, ari)).result?.code,
    );
    await getFirestore()
      .doc(`invites/${old}`)
      .update({ expiresAt: Timestamp.fromMillis(Date.now() - 1000) });

    const fresh = String(
      (await call("createInvite", { adventureId: id }, ari)).result?.code,
    );
    expect(fresh).not.toBe(old);
  });
});

describe("revokeInvite", () => {
  it("kills the current link; the next share gets a new one", async () => {
    const ari = await person("Ari");
    const id = await adventure(ari);
    const old = String(
      (await call("createInvite", { adventureId: id }, ari)).result?.code,
    );

    expect(
      (await call("revokeInvite", { adventureId: id }, ari)).error,
    ).toBeUndefined();
    expect(
      (await getFirestore().doc(`invites/${old}`).get()).get("revoked"),
    ).toBe(true);

    const fresh = String(
      (await call("createInvite", { adventureId: id }, ari)).result?.code,
    );
    expect(fresh).not.toBe(old);
  });

  it("is for leads only", async () => {
    const ari = await person("Ari");
    const bob = await person("Bob");
    const id = await adventure(ari, { memberUids: [ari.uid, bob.uid] });
    await call("createInvite", { adventureId: id }, ari);
    expect(
      (await call("revokeInvite", { adventureId: id }, bob)).error?.status,
    ).toBe("PERMISSION_DENIED");
  });
});

describe("the leader's picture on an invite (spec UC-28a)", () => {
  it("goes to a signed-in invitee, not the public preview", async () => {
    const ari = await person("Ari");
    await getFirestore().doc(`users/${ari.uid}`).update({ characterId: "panda" });
    const id = await adventure(ari);
    const made = await call("createInvite", { adventureId: id }, ari);
    const code = (made.result as { code: string }).code;

    const stored = (await getFirestore().doc(`invites/${code}`).get()).data();
    expect(stored?.leaderCharacterId).toBe("panda");
    expect(stored?.leaderUid).toBe(ari.uid);

    const zed = await person("Zed");
    const seen = await call("lookupInvite", { code }, zed);
    expect(seen.result?.leaderCharacterId).toBe("panda");
    expect(seen.result?.leaderUid).toBe(ari.uid);

    const res = await fetch(`${FUNCTIONS}/invitePreview?code=${code}`);
    const preview = (await res.json()) as Record<string, unknown>;
    expect(preview.leaderName).toBe("Ari");
    expect(preview.leaderCharacterId).toBeUndefined();
    expect(preview.leaderUid).toBeUndefined();
  });

  it("a leader with no character leaves it empty", async () => {
    const ari = await person("Ari");
    const id = await adventure(ari);
    const made = await call("createInvite", { adventureId: id }, ari);
    const code = (made.result as { code: string }).code;
    expect((await getFirestore().doc(`invites/${code}`).get()).get("leaderCharacterId")).toBeNull();
  });
});

describe("lookupInvite", () => {
  it("describes a valid invite, however the code is typed", async () => {
    const ari = await person("Ari");
    const bob = await person("Bob");
    const id = await adventure(ari);
    const code = String(
      (await call("createInvite", { adventureId: id }, ari)).result?.code,
    );

    const r = await call(
      "lookupInvite",
      { code: formatCode(code).toLowerCase() },
      bob,
    );
    expect(r.result).toMatchObject({
      code,
      adventureId: id,
      adventureName: "College group Bangkok adventure",
      leaderName: "Ari",
      countryCode: "TH",
      startDate: "2026-12-01",
      endDate: "2026-12-08",
    });
  });

  it("explains unknown, expired and revoked codes", async () => {
    const ari = await person("Ari");
    const bob = await person("Bob");
    const id = await adventure(ari);

    const unknown = await call("lookupInvite", { code: "ABCDEFGH" }, bob);
    expect(unknown.error?.status).toBe("NOT_FOUND");

    const code = String(
      (await call("createInvite", { adventureId: id }, ari)).result?.code,
    );
    await getFirestore()
      .doc(`invites/${code}`)
      .update({ expiresAt: Timestamp.fromMillis(Date.now() - 1000) });
    const expired = await call("lookupInvite", { code }, bob);
    expect(expired.error?.status).toBe("FAILED_PRECONDITION");
    expect(expired.error?.message).toContain("expired");

    const code2 = String(
      (await call("createInvite", { adventureId: id }, ari)).result?.code,
    );
    await call("revokeInvite", { adventureId: id }, ari);
    const revoked = await call("lookupInvite", { code: code2 }, bob);
    expect(revoked.error?.status).toBe("FAILED_PRECONDITION");
    expect(revoked.error?.message).toContain("no longer");

    expect(
      (await call("lookupInvite", { code: "nonsense" }, bob)).error?.status,
    ).toBe("INVALID_ARGUMENT");
  });
});

describe("invitePreview (public, for the web page)", () => {
  it("shows only the adventure name and leader's first name", async () => {
    const ari = await person("Ari Chen");
    const id = await adventure(ari);
    const code = String(
      (await call("createInvite", { adventureId: id }, ari)).result?.code,
    );

    const ok = await fetch(`${FUNCTIONS}/invitePreview?code=${code}`);
    expect(ok.status).toBe(200);
    expect(await ok.json()).toEqual({
      code,
      adventureName: "College group Bangkok adventure",
      leaderName: "Ari",
    });
    expect(
      (await fetch(`${FUNCTIONS}/invitePreview?code=ABCDEFGH`)).status,
    ).toBe(404);
  });
});

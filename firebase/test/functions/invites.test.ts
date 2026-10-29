import { beforeAll, describe, expect, it } from "vitest";
import { formatCode, normaliseCode } from "../../functions/src/invites/code";
import {
  getApps,
  getAuth,
  getFirestore,
  initializeApp,
  Timestamp,
} from "../support/admin";

const PROJECT = "demo-roamio";
const FUNCTIONS = `http://127.0.0.1:5001/${PROJECT}/asia-south1`;
let n = 0;

beforeAll(() => {
  if (getApps().length === 0) initializeApp({ projectId: PROJECT });
});

type Person = { uid: string; token: string };

async function person(name: string): Promise<Person> {
  const email = `${name.toLowerCase()}${++n}.${Date.now()}@example.com`;
  const user = await getAuth().createUser({
    email,
    password: "secret123",
    emailVerified: true,
  });
  await getFirestore()
    .doc(`users/${user.uid}`)
    .set({ name, photoUrl: null, bio: "" });
  await getFirestore()
    .doc(`users/${user.uid}/private/account`)
    .set({ dob: "2000-01-01", ageStatus: "adult" });
  const res = await fetch(
    "http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=fake",
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        email,
        password: "secret123",
        returnSecureToken: true,
      }),
    },
  );
  return {
    uid: user.uid,
    token: ((await res.json()) as { idToken: string }).idToken,
  };
}

async function adventure(leader: Person, extra: Record<string, unknown> = {}) {
  const ref = getFirestore().collection("adventures").doc();
  await ref.set({
    name: "College group Bangkok adventure",
    countryCode: "TH",
    startDate: "2026-12-01",
    endDate: "2026-12-08",
    baseCurrency: "THB",
    createdBy: leader.uid,
    leaderUid: leader.uid,
    coLeadUids: [],
    memberUids: [leader.uid],
    ...extra,
  });
  return ref.id;
}

type Result = {
  result?: Record<string, unknown>;
  error?: { status: string; message: string };
};

async function call(name: string, data: unknown, as?: Person): Promise<Result> {
  const res = await fetch(`${FUNCTIONS}/${name}`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      ...(as ? { Authorization: `Bearer ${as.token}` } : {}),
    },
    body: JSON.stringify({ data }),
  });
  return (await res.json()) as Result;
}

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

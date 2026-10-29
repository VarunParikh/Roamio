import { beforeAll, describe, expect, it } from "vitest";
import { todayInIndia } from "../../functions/src/auth/age";
import { runBirthdaySweep } from "../../functions/src/auth/birthdays";
import {
  getApps,
  getAuth,
  getFirestore,
  initializeApp,
} from "../support/admin";

const PROJECT = "demo-roamio";
const FUNCTIONS = `http://127.0.0.1:5001/${PROJECT}/asia-south1`;
const AUTH = "http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1";

let n = 0;
const unique = (name: string) => `${name}${++n}.${Date.now()}@example.com`;

beforeAll(() => {
  if (getApps().length === 0) initializeApp({ projectId: PROJECT });
});

/** A date of birth making someone [years] old exactly today in India. */
function bornYearsAgo(years: number, dayOffset = 0): string {
  const [y, m, d] = todayInIndia(new Date()).split("-").map(Number);
  const date = new Date(Date.UTC(y - years, m - 1, d + dayOffset));
  return date.toISOString().slice(0, 10);
}

async function account(
  name: string,
  dob: string,
  ageStatus: string,
  extra = {},
) {
  const email = unique(name);
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
    .set({ dob, ageStatus, ...extra });
  return { uid: user.uid, email };
}

const accountOf = async (uid: string) =>
  (await getFirestore().doc(`users/${uid}/private/account`).get()).data();
const consentOf = async (uid: string) =>
  (await getFirestore().doc(`parentalConsents/${uid}`).get()).data();
const mailTo = async (to: string) =>
  (await getFirestore().collection("mail").where("to", "==", to).get()).size;

describe("runBirthdaySweep (spec §7.4)", () => {
  it("a consented minor turning 18 must accept the adult notice; the parent link goes", async () => {
    const parent = await account("Pat", "1980-01-01", "adult");
    const teen = await account("Mia", bornYearsAgo(18), "minor_active", {
      parentUid: parent.uid,
    });
    await getFirestore().doc(`parentalConsents/${teen.uid}`).set({
      status: "granted",
      parentUid: parent.uid,
      parentEmail: parent.email,
    });

    await runBirthdaySweep(new Date());

    const acc = await accountOf(teen.uid);
    expect(acc?.ageStatus).toBe("adult_unconfirmed");
    expect(acc?.parentUid).toBeUndefined();
    expect((await consentOf(teen.uid))?.status).toBe("aged_out");
    expect(await mailTo(parent.email)).toBe(1);
  });

  it("leaves 17-year-olds alone, even on the day before", async () => {
    const teen = await account("Sam", bornYearsAgo(18, 1), "minor_active", {
      parentUid: "p",
    });
    await runBirthdaySweep(new Date());
    expect((await accountOf(teen.uid))?.ageStatus).toBe("minor_active");
  });

  it("closes an unanswered consent request for someone who turns 18", async () => {
    const teen = await account("Lee", bornYearsAgo(18), "minor_pending");
    await getFirestore()
      .doc(`parentalConsents/${teen.uid}`)
      .set({
        status: "requested",
        parentEmail: unique("parent"),
        tokenHash: "abc",
      });

    await runBirthdaySweep(new Date());

    expect((await accountOf(teen.uid))?.ageStatus).toBe("adult_unconfirmed");
    const consent = await consentOf(teen.uid);
    expect(consent?.status).toBe("closed");
    expect(consent?.tokenHash).toBeUndefined();
  });
});

describe("acceptAdultNotice", () => {
  async function signIn(email: string) {
    const res = await fetch(`${AUTH}/accounts:signInWithPassword?key=fake`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        email,
        password: "secret123",
        returnSecureToken: true,
      }),
    });
    return ((await res.json()) as { idToken: string }).idToken;
  }

  async function accept(token: string) {
    const res = await fetch(`${FUNCTIONS}/acceptAdultNotice`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${token}`,
      },
      body: JSON.stringify({ data: {} }),
    });
    return (await res.json()) as {
      result?: unknown;
      error?: { status: string };
    };
  }

  it("makes a newly-18 account a full adult account", async () => {
    const me = await account("Mia", bornYearsAgo(18), "adult_unconfirmed");
    const r = await accept(await signIn(me.email));
    expect(r.error).toBeUndefined();
    const acc = await accountOf(me.uid);
    expect(acc?.ageStatus).toBe("adult");
    expect(acc?.noticeVersion).toBeTypeOf("string");
  });

  it("does nothing for anyone else", async () => {
    const teen = await account("Sam", bornYearsAgo(16), "minor_active");
    const r = await accept(await signIn(teen.email));
    expect(r.error?.status).toBe("FAILED_PRECONDITION");
    expect((await accountOf(teen.uid))?.ageStatus).toBe("minor_active");
  });
});

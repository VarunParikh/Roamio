import { readFileSync } from "node:fs";
import {
  initializeTestEnvironment,
  type RulesTestEnvironment,
} from "@firebase/rules-unit-testing";
import { doc, setDoc } from "firebase/firestore";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { todayInIndia } from "../../functions/src/auth/age";

const AUTH = "http://127.0.0.1:9099";
const FIRESTORE =
  "http://127.0.0.1:8080/v1/projects/demo-roamio/databases/(default)/documents";
const OWNER = {
  Authorization: "Bearer owner",
  "Content-Type": "application/json",
};

/** Reads a document straight from the emulator (no client cache), as plain strings. */
async function readDoc(
  path: string,
): Promise<Record<string, string> | undefined> {
  const res = await fetch(`${FIRESTORE}/${path}`, { headers: OWNER });
  if (res.status === 404) return undefined;
  const fields =
    (
      (await res.json()) as {
        fields?: Record<string, { stringValue?: string }>;
      }
    ).fields ?? {};
  return Object.fromEntries(
    Object.entries(fields).map(([k, v]) => [k, v.stringValue ?? ""]),
  );
}
let env: RulesTestEnvironment;

/** A date of birth that makes someone exactly [years] old today in India. */
function bornYearsAgo(years: number): string {
  const [y, m, d] = todayInIndia(new Date()).split("-");
  return `${Number(y) - years}-${m}-${d}`;
}

async function createAuthUser(email: string): Promise<string> {
  const res = await fetch(
    `${AUTH}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake-api-key`,
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
  const { localId } = (await res.json()) as { localId?: string };
  if (!localId) throw new Error(`Auth emulator sign-up failed (${res.status})`);
  return localId;
}

async function authUserExists(uid: string): Promise<boolean> {
  const res = await fetch(
    `${AUTH}/identitytoolkit.googleapis.com/v1/projects/demo-roamio/accounts:lookup`,
    {
      method: "POST",
      headers: OWNER,
      body: JSON.stringify({ localId: [uid] }),
    },
  );
  return ((await res.json()) as { users?: unknown[] }).users?.length === 1;
}

async function eventually<T>(
  read: () => Promise<T>,
  done: (v: T) => boolean,
): Promise<T> {
  for (let i = 0; i < 50; i++) {
    const value = await read();
    if (done(value)) return value;
    await new Promise((r) => setTimeout(r, 200));
  }
  return read();
}

async function signUp(email: string, dob: string | null, uid?: string) {
  uid ??= await createAuthUser(email);
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, `users/${uid}`), {
      name: "Test",
      photoUrl: null,
      bio: "",
    });
    await setDoc(doc(db, `users/${uid}/private/account`), {
      // The pilot asks no birth date: the person ticks "I'm 18 or older".
      ...(dob === null ? { adultDeclared: true } : { dob }),
      profileCurrency: "INR",
    });
  });
  const account = () => readDoc(`users/${uid}/private/account`);
  return { uid, account };
}

beforeAll(async () => {
  env = await initializeTestEnvironment({
    projectId: "demo-roamio",
    firestore: { rules: readFileSync("firestore.rules", "utf8") },
  });
});

afterAll(() => env.cleanup());

describe("setAgeStatus trigger (spec UC-4, §7)", () => {
  it("marks adults as adult", async () => {
    const { account } = await signUp("adult@example.com", bornYearsAgo(18));
    const data = await eventually(account, (d) => d?.ageStatus !== undefined);
    expect(data?.ageStatus).toBe("adult");
  });

  it("marks someone who declared they're 18 or older as adult (pilot: no birth date)", async () => {
    const { account } = await signUp("declared@example.com", null);
    const data = await eventually(account, (d) => d?.ageStatus !== undefined);
    expect(data?.ageStatus).toBe("adult");
  });

  it("removes a record with neither a birth date nor the declaration", async () => {
    const uid = await createAuthUser("neither@example.com");
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), `users/${uid}/private/account`), {
        profileCurrency: "INR",
      });
    });
    expect(
      await eventually(
        () => readDoc(`users/${uid}/private/account`),
        (d) => d === undefined,
      ),
    ).toBeUndefined();
  });

  it("marks 13–17 year olds as waiting for parental consent", async () => {
    const { account } = await signUp("teen@example.com", bornYearsAgo(13));
    const data = await eventually(account, (d) => d?.ageStatus !== undefined);
    expect(data?.ageStatus).toBe("minor_pending");
  });

  it("deletes under-13 sign-ups entirely", async () => {
    const { uid, account } = await signUp("kid@example.com", bornYearsAgo(12));
    expect(await eventually(account, (d) => d === undefined)).toBeUndefined();
    expect(
      await eventually(
        () => authUserExists(uid),
        (e) => !e,
      ),
    ).toBe(false);
    expect(await readDoc(`users/${uid}`)).toBeUndefined();
  });

  it("removes an account record with an impossible date so the app asks again", async () => {
    const { account } = await signUp("future@example.com", "2999-01-01");
    expect(await eventually(account, (d) => d === undefined)).toBeUndefined();
  });

  it("removes records written by a deleted account whose sign-in token still works", async () => {
    // Journey E: a just-deleted person's ID token stays valid for up to an
    // hour, and the rules can't tell. They must not come back as an adult.
    const ghost = `deleted-${Date.now()}`;
    const { account } = await signUp("ghost@example.com", bornYearsAgo(30), ghost);
    expect(await eventually(account, (d) => d === undefined)).toBeUndefined();
    expect(await readDoc(`users/${ghost}`)).toBeUndefined();
  });
});

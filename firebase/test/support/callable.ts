// Helpers for calling deployed callables in the emulator as real signed-in people.
import { beforeAll } from "vitest";
import { getApps, getAuth, getFirestore, initializeApp } from "./admin";

export const PROJECT = "demo-roamio";
export const FUNCTIONS = `http://127.0.0.1:5001/${PROJECT}/asia-south1`;
let n = 0;

beforeAll(() => {
  if (getApps().length === 0) initializeApp({ projectId: PROJECT });
});

export type Person = { uid: string; token: string };

export async function person(
  name: string,
  ageStatus = "adult",
): Promise<Person> {
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
    .set({ dob: "2000-01-01", ageStatus });
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

export async function adventure(
  leader: Person,
  extra: Record<string, unknown> = {},
) {
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

export async function call(
  name: string,
  data: unknown,
  as?: Person,
): Promise<Result> {
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

import { beforeAll, describe, expect, it } from "vitest";
import { runConsentSweep } from "../../functions/src/consent/sweep";
import { getApps, getAuth, getFirestore, initializeApp, Timestamp } from "../support/admin";

const PROJECT = "demo-roamio";
const FUNCTIONS = `http://127.0.0.1:5001/${PROJECT}/asia-south1`;
const AUTH = "http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1";
const DAY = 24 * 60 * 60 * 1000;

let n = 0;
const unique = (name: string) => `${name.toLowerCase()}${++n}.${Date.now()}@example.com`;

beforeAll(() => {
  if (getApps().length === 0) initializeApp({ projectId: PROJECT });
});

type Person = { uid: string; email: string; token: string };

/** Creates a signed-in user with an account record in [ageStatus]. */
async function person(
  name: string,
  ageStatus: string,
  { verified = true, email = unique(name) } = {},
): Promise<Person> {
  const user = await getAuth().createUser({
    email,
    password: "secret123",
    emailVerified: verified,
  });
  const db = getFirestore();
  await db.doc(`users/${user.uid}`).set({ name, photoUrl: null, bio: "" });
  await db
    .doc(`users/${user.uid}/private/account`)
    .set({ dob: "2010-01-01", ageStatus });
  const res = await fetch(`${AUTH}/accounts:signInWithPassword?key=fake`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      email,
      password: "secret123",
      returnSecureToken: true,
    }),
  });
  const { idToken } = (await res.json()) as { idToken: string };
  return { uid: user.uid, email, token: idToken };
}

type CallResult = {
  result?: Record<string, unknown>;
  error?: { status: string };
};

async function call(
  name: string,
  data: unknown,
  as?: Person,
): Promise<CallResult> {
  const res = await fetch(`${FUNCTIONS}/${name}`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      ...(as ? { Authorization: `Bearer ${as.token}` } : {}),
    },
    body: JSON.stringify({ data }),
  });
  return (await res.json()) as CallResult;
}

/** The consent link token from the newest email sent to [to]. */
async function latestToken(to: string): Promise<string> {
  const mail = await getFirestore()
    .collection("mail")
    .where("to", "==", to)
    .get();
  const newest = mail.docs.sort(
    (a, b) => b.get("createdAt") - a.get("createdAt"),
  )[0];
  const text: string = newest.get("message.text");
  return new URL(text.match(/https?:\/\/\S+/)![0]).searchParams.get("t")!;
}

async function requested(child: Person, parentEmail: string) {
  const r = await call(
    "requestParentalConsent",
    { parentEmail, relationship: "mother" },
    child,
  );
  expect(r.error).toBeUndefined();
  return latestToken(parentEmail.toLowerCase());
}

const consentOf = async (uid: string) =>
  (await getFirestore().doc(`parentalConsents/${uid}`).get()).data();
const accountOf = async (uid: string) =>
  (await getFirestore().doc(`users/${uid}/private/account`).get()).data();
const authUserExists = (uid: string) =>
  getAuth()
    .getUser(uid)
    .then(() => true)
    .catch(() => false);

describe("requestParentalConsent", () => {
  it("records the request and emails the parent a single-use link", async () => {
    const child = await person("Mia", "minor_pending");
    const parentEmail = unique("Parent").toUpperCase();
    const token = await requested(child, parentEmail);

    const consent = await consentOf(child.uid);
    expect(consent?.status).toBe("requested");
    expect(consent?.parentEmail).toBe(parentEmail.toLowerCase());
    expect(consent?.relationship).toBe("mother");
    expect(consent?.tokenHash).toBeTypeOf("string");
    expect(JSON.stringify(consent)).not.toContain(token);
  });

  it("refuses the child's own email, signed-out callers and non-pending users", async () => {
    const child = await person("Mia", "minor_pending");
    expect(
      (
        await call(
          "requestParentalConsent",
          { parentEmail: child.email },
          child,
        )
      ).error?.status,
    ).toBe("INVALID_ARGUMENT");
    expect(
      (await call("requestParentalConsent", { parentEmail: "x@example.com" }))
        .error?.status,
    ).toBe("UNAUTHENTICATED");
    const adult = await person("Ari", "adult");
    expect(
      (
        await call(
          "requestParentalConsent",
          { parentEmail: "x@example.com" },
          adult,
        )
      ).error?.status,
    ).toBe("FAILED_PRECONDITION");
    expect(
      (
        await call(
          "requestParentalConsent",
          { parentEmail: "not-an-email" },
          child,
        )
      ).error?.status,
    ).toBe("INVALID_ARGUMENT");
  });

  it("allows three requests a day, and each new link replaces the old one", async () => {
    const child = await person("Mia", "minor_pending");
    const parent = await person("Pat", "adult");
    const first = await requested(child, parent.email);
    await requested(child, parent.email);
    await requested(child, parent.email);
    const fourth = await call(
      "requestParentalConsent",
      { parentEmail: parent.email },
      child,
    );
    expect(fourth.error?.status).toBe("RESOURCE_EXHAUSTED");

    const stale = await call(
      "decideParentalConsent",
      { childUid: child.uid, token: first, decision: "grant" },
      parent,
    );
    expect(stale.error?.status).toBe("PERMISSION_DENIED");
  });
});

describe("describeConsentRequest", () => {
  it("shows the parent who is asking, only with a valid token", async () => {
    const child = await person("Mia Rao", "minor_pending");
    const parent = await person("Pat", "adult");
    const token = await requested(child, parent.email);

    const ok = await call(
      "describeConsentRequest",
      { childUid: child.uid, token },
      parent,
    );
    expect(ok.result).toEqual({
      childFirstName: "Mia",
      relationship: "mother",
      parentEmail: parent.email,
    });
    const bad = await call(
      "describeConsentRequest",
      { childUid: child.uid, token: "nope" },
      parent,
    );
    expect(bad.error?.status).toBe("PERMISSION_DENIED");
  });
});

describe("decideParentalConsent", () => {
  it("a verified adult guardian grants consent; the link then stops working", async () => {
    const child = await person("Mia", "minor_pending");
    const parent = await person("Pat", "adult");
    const token = await requested(child, parent.email);

    const r = await call(
      "decideParentalConsent",
      { childUid: child.uid, token, decision: "grant" },
      parent,
    );
    expect(r.error).toBeUndefined();

    expect((await accountOf(child.uid))?.ageStatus).toBe("minor_active");
    expect((await accountOf(child.uid))?.parentUid).toBe(parent.uid);
    const consent = await consentOf(child.uid);
    expect(consent?.status).toBe("granted");
    expect(consent?.parentUid).toBe(parent.uid);
    expect(consent?.method).toBe("verified_adult_roamio_account");
    expect(consent?.tokenHash).toBeUndefined();

    const again = await call(
      "decideParentalConsent",
      { childUid: child.uid, token, decision: "decline" },
      parent,
    );
    expect(again.error?.status).toBe("FAILED_PRECONDITION");
  });

  it("a decline deletes the child's account and tells them", async () => {
    const child = await person("Mia", "minor_pending");
    const parent = await person("Pat", "adult");
    const token = await requested(child, parent.email);

    const r = await call(
      "decideParentalConsent",
      { childUid: child.uid, token, decision: "decline" },
      parent,
    );
    expect(r.error).toBeUndefined();

    expect(await authUserExists(child.uid)).toBe(false);
    expect(await accountOf(child.uid)).toBeUndefined();
    expect((await consentOf(child.uid))?.status).toBe("declined");
    const toChild = await getFirestore()
      .collection("mail")
      .where("to", "==", child.email)
      .get();
    expect(toChild.size).toBe(1);
  });

  it("refuses a guardian who is under 18", async () => {
    const child = await person("Mia", "minor_pending");
    const teen = await person("Sam", "minor_active");
    const token = await requested(child, teen.email);
    const r = await call(
      "decideParentalConsent",
      { childUid: child.uid, token, decision: "grant" },
      teen,
    );
    expect(r.error?.status).toBe("PERMISSION_DENIED");
    expect((await accountOf(child.uid))?.ageStatus).toBe("minor_pending");
  });

  it("refuses an unverified email or a different email from the one asked", async () => {
    const child = await person("Mia", "minor_pending");
    const unverified = await person("Pat", "adult", { verified: false });
    const token = await requested(child, unverified.email);
    expect(
      (
        await call(
          "decideParentalConsent",
          { childUid: child.uid, token, decision: "grant" },
          unverified,
        )
      ).error?.status,
    ).toBe("PERMISSION_DENIED");

    const stranger = await person("Rex", "adult");
    expect(
      (
        await call(
          "decideParentalConsent",
          { childUid: child.uid, token, decision: "grant" },
          stranger,
        )
      ).error?.status,
    ).toBe("PERMISSION_DENIED");
  });

  it("refuses the child approving themselves", async () => {
    const child = await person("Mia", "minor_pending");
    const token = await requested(child, unique("parent"));
    const r = await call(
      "decideParentalConsent",
      { childUid: child.uid, token, decision: "grant" },
      child,
    );
    expect(r.error?.status).toBe("PERMISSION_DENIED");
  });

  it("refuses a request older than seven days", async () => {
    const child = await person("Mia", "minor_pending");
    const parent = await person("Pat", "adult");
    const token = await requested(child, parent.email);
    await getFirestore()
      .doc(`parentalConsents/${child.uid}`)
      .update({ requestedAt: Timestamp.fromMillis(Date.now() - 8 * DAY) });

    const r = await call(
      "decideParentalConsent",
      { childUid: child.uid, token, decision: "grant" },
      parent,
    );
    expect(r.error?.status).toBe("FAILED_PRECONDITION");
  });
});

describe("runConsentSweep (daily reminders and expiry)", () => {
  it("reminds the parent on day 3", async () => {
    const child = await person("Mia", "minor_pending");
    const parentEmail = unique("parent");
    await requested(child, parentEmail);
    const before = (
      await getFirestore()
        .collection("mail")
        .where("to", "==", parentEmail)
        .get()
    ).size;

    await runConsentSweep(new Date(Date.now() + 3 * DAY + 60_000));

    const after = (
      await getFirestore()
        .collection("mail")
        .where("to", "==", parentEmail)
        .get()
    ).size;
    expect(after).toBe(before + 1);
    expect((await consentOf(child.uid))?.remindersSent).toBe(1);
  });

  it("deletes the child's account after seven days without an answer", async () => {
    const child = await person("Mia", "minor_pending");
    await requested(child, unique("parent"));

    await runConsentSweep(new Date(Date.now() + 7 * DAY + 60_000));

    expect(await authUserExists(child.uid)).toBe(false);
    expect(await accountOf(child.uid)).toBeUndefined();
    expect((await consentOf(child.uid))?.status).toBe("expired");
  });
});

import { createServer, type Server } from "node:http";
import { afterAll, beforeAll, beforeEach, describe, expect, it } from "vitest";
import {
  getApps,
  getAuth,
  getFirestore,
  initializeApp,
} from "../support/admin";

/**
 * A stand-in for the Unsplash API. functions/.env.demo-roamio points the
 * emulated functions here (UNSPLASH_API_BASE), so tests never call Unsplash.
 */
const MOCK_PORT = 5099;
let mock: Server;
let requests: string[] = [];
let mode: "hit" | "empty" | "down" = "hit";

const photo = {
  urls: { raw: "https://images.unsplash.com/photo-123?ixid=abc" },
  user: { name: "Jane Doe", links: { html: "https://unsplash.com/@jane" } },
  links: {
    html: "https://unsplash.com/photos/123",
    download_location: `http://127.0.0.1:${MOCK_PORT}/photos/123/download`,
  },
};

const PROJECT = "demo-roamio";
const FUNCTIONS = `http://127.0.0.1:5001/${PROJECT}/asia-south1`;
let token = "";

beforeAll(async () => {
  if (getApps().length === 0) initializeApp({ projectId: PROJECT });
  mock = createServer((req, res) => {
    requests.push(req.url ?? "");
    if (mode === "down") {
      res.writeHead(503).end();
      return;
    }
    res.setHeader("Content-Type", "application/json");
    if (req.url?.startsWith("/photos/123/download")) {
      res.end("{}");
      return;
    }
    res.end(JSON.stringify({ results: mode === "hit" ? [photo] : [] }));
  });
  await new Promise<void>((r) => mock.listen(MOCK_PORT, "127.0.0.1", r));

  const email = `banner${Date.now()}@example.com`;
  const user = await getAuth().createUser({
    email,
    password: "secret123",
    emailVerified: true,
  });
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
  token = ((await res.json()) as { idToken: string }).idToken;

  // Warm-up: the emulator's first call looks up the Unsplash secret in
  // Secret Manager, which CI can't reach; let that happen outside the tests.
  await getBanner("FR");
});

afterAll(() => new Promise<void>((r) => mock.close(() => r())));

beforeEach(async () => {
  requests = [];
  mode = "hit";
  // Other test files may leave banners behind (the rules tests seed
  // banners/TH); start each test with none cached for our countries.
  await Promise.all(
    ["TH", "JP", "IS", "PE", "FR"].map((c) =>
      getFirestore().doc(`banners/${c}`).delete(),
    ),
  );
});

async function getBanner(countryCode: string, auth = true) {
  const res = await fetch(`${FUNCTIONS}/getBanner`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      ...(auth ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: JSON.stringify({ data: { countryCode } }),
  });
  return (await res.json()) as {
    result?: Record<string, string | null>;
    error?: { status: string };
  };
}

describe("getBanner (spec §9.2)", () => {
  it("finds a landmark photo, credits the photographer, and caches it per country", async () => {
    const r = await getBanner("TH");
    expect(r.result?.photographer).toBe("Jane Doe");
    expect(r.result?.photographerUrl).toContain("utm_source=roamio");
    const url = new URL(r.result?.url ?? "");
    expect(url.searchParams.get("w")).toBe("1600");
    expect(url.searchParams.get("fm")).toBe("webp");
    expect(url.searchParams.get("q")).toBe("80");

    const search = requests.find((u) => u.startsWith("/search/photos"));
    expect(new URL(search ?? "", "http://x").searchParams.get("query")).toBe(
      "Grand Palace Thailand",
    );
    expect(requests.some((u) => u.startsWith("/photos/123/download"))).toBe(
      true,
    );

    const cached = (await getFirestore().doc("banners/TH").get()).data();
    expect(cached?.url).toBe(r.result?.url);
  });

  it("serves the cached banner without calling Unsplash again", async () => {
    await getBanner("JP");
    requests = [];
    const again = await getBanner("JP");
    expect(again.result?.url).toBeTruthy();
    expect(requests).toEqual([]);
  });

  it("returns no banner (the app shows its fallback) when nothing matches", async () => {
    mode = "empty";
    const r = await getBanner("IS");
    expect(r.result).toEqual({ url: null });
    expect((await getFirestore().doc("banners/IS").get()).exists).toBe(false);
  });

  it("returns no banner when Unsplash is down, and tries again next time", async () => {
    mode = "down";
    expect((await getBanner("PE")).result).toEqual({ url: null });
    mode = "hit";
    expect((await getBanner("PE")).result?.url).toBeTruthy();
  });

  it("rejects unknown countries and signed-out callers", async () => {
    expect((await getBanner("XX")).error?.status).toBe("INVALID_ARGUMENT");
    expect((await getBanner("TH", false)).error?.status).toBe(
      "UNAUTHENTICATED",
    );
  });
});

import { readFileSync } from "node:fs";
import {
  assertFails,
  initializeTestEnvironment,
  type RulesTestEnvironment,
} from "@firebase/rules-unit-testing";
import { doc, getDoc, setDoc } from "firebase/firestore";
import { getBytes, ref, uploadString } from "firebase/storage";
import { afterAll, beforeAll, describe, it } from "vitest";

let env: RulesTestEnvironment;

beforeAll(async () => {
  env = await initializeTestEnvironment({
    projectId: "demo-roamio",
    firestore: { rules: readFileSync("firestore.rules", "utf8") },
    storage: { rules: readFileSync("storage.rules", "utf8") },
  });
});

afterAll(() => env.cleanup());

describe("Firestore default deny", () => {
  it("blocks signed-out reads and writes", async () => {
    const db = env.unauthenticatedContext().firestore();
    await assertFails(getDoc(doc(db, "adventures/a1")));
    await assertFails(setDoc(doc(db, "adventures/a1"), { name: "Bangkok" }));
  });

  it("blocks collections that have no rules of their own", async () => {
    const db = env.authenticatedContext("alice").firestore();
    await assertFails(getDoc(doc(db, "secrets/x")));
    await assertFails(setDoc(doc(db, "secrets/x"), { a: 1 }));
  });
});

describe("Storage default deny", () => {
  it("blocks uploads and downloads for everyone", async () => {
    const storage = env.authenticatedContext("alice").storage();
    await assertFails(
      uploadString(ref(storage, "users/alice/avatar.webp"), "x"),
    );
    await assertFails(getBytes(ref(storage, "users/alice/avatar.webp")));
  });
});

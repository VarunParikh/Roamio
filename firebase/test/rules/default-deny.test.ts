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

  it("blocks signed-in users until a collection has its own rules", async () => {
    const db = env.authenticatedContext("alice").firestore();
    await assertFails(getDoc(doc(db, "users/alice")));
    await assertFails(setDoc(doc(db, "users/alice"), { name: "Alice" }));
  });
});

describe("Storage default deny", () => {
  it("blocks uploads and downloads for everyone", async () => {
    const storage = env.authenticatedContext("alice").storage();
    await assertFails(uploadString(ref(storage, "users/alice/avatar.webp"), "x"));
    await assertFails(getBytes(ref(storage, "users/alice/avatar.webp")));
  });
});

import { readFileSync } from "node:fs";
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
  type RulesTestEnvironment,
} from "@firebase/rules-unit-testing";
import { doc, setDoc } from "firebase/firestore";
import { getBytes, ref, uploadBytes } from "firebase/storage";
import { afterAll, beforeAll, beforeEach, describe, it } from "vitest";
import { clearFirestore } from "../support/clear";

/**
 * Phase 1 uploads no pictures (spec §10): the rules as they ship deny every
 * write, from anyone, even a perfectly good photo. Reading what's there stays
 * as it was. storage.test.ts checks the rules for when uploads come back.
 * Alice leads a1, bob is a member and created tab t1, dan is outside.
 */
let env: RulesTestEnvironment;

const storage = (uid?: string) =>
  (uid
    ? env.authenticatedContext(uid)
    : env.unauthenticatedContext()
  ).storage();

const asWebp = { contentType: "image/webp" };
const put = (uid: string | undefined, path: string) =>
  uploadBytes(ref(storage(uid), path), new Uint8Array(1000), asWebp);

beforeAll(async () => {
  env = await initializeTestEnvironment({
    projectId: "demo-roamio",
    firestore: { rules: readFileSync("firestore.rules", "utf8") },
    storage: { rules: readFileSync("storage.rules", "utf8") },
  });
});

afterAll(() => env.cleanup());

beforeEach(async () => {
  await clearFirestore(env);
  await env.clearStorage();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    for (const uid of ["alice", "bob", "dan"]) {
      await setDoc(doc(db, `users/${uid}/private/account`), {
        ageStatus: "adult",
      });
    }
    await setDoc(doc(db, "adventures/a1"), {
      leaderUid: "alice",
      coLeadUids: [],
      memberUids: ["alice", "bob"],
    });
    await setDoc(doc(db, "adventures/a1/tabs/t1"), { createdBy: "bob" });
    await uploadBytes(
      ref(ctx.storage(), "adventures/a1/tabs/t1/old.webp"),
      new Uint8Array(1000),
      asWebp,
    );
  });
});

describe("no uploads in the pilot", () => {
  it("a tab's creator can't add a photo", async () => {
    await assertFails(put("bob", "adventures/a1/tabs/t1/new.webp"));
  });

  it("a lead can't upload a banner", async () => {
    await assertFails(put("alice", "adventures/a1/banner/new.webp"));
  });

  it("nobody can upload a display picture, even their own", async () => {
    await assertFails(put("bob", "users/bob/avatar/new.webp"));
  });

  it("outsiders and signed-out people can't either", async () => {
    await assertFails(put("dan", "adventures/a1/banner/new.webp"));
    await assertFails(put(undefined, "users/bob/avatar/new.webp"));
  });

  it("members can still read what's already there; outsiders can't", async () => {
    await assertSucceeds(
      getBytes(ref(storage("alice"), "adventures/a1/tabs/t1/old.webp")),
    );
    await assertFails(
      getBytes(ref(storage("dan"), "adventures/a1/tabs/t1/old.webp")),
    );
  });
});

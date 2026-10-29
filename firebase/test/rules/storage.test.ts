import { readFileSync } from "node:fs";
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
  type RulesTestEnvironment,
} from "@firebase/rules-unit-testing";
import { doc, setDoc } from "firebase/firestore";
import { deleteObject, getBytes, ref, uploadBytes } from "firebase/storage";
import { afterAll, beforeAll, beforeEach, describe, it } from "vitest";

/**
 * Photos (spec §10): only compressed WebP up to 1 MB, only into places the
 * uploader may write, readable by the squad. Cast as in firestore.test.ts:
 * alice leads a1, cara co-leads, bob is a member, dan is outside, pete is
 * a minor waiting for consent. Bob created tab t1.
 */
let env: RulesTestEnvironment;

const storage = (uid?: string) =>
  (uid
    ? env.authenticatedContext(uid)
    : env.unauthenticatedContext()
  ).storage();

const webp = (bytes = 1000) => new Uint8Array(bytes);
const asWebp = { contentType: "image/webp" };

const put = (
  uid: string | undefined,
  path: string,
  bytes = 1000,
  meta = asWebp,
) => uploadBytes(ref(storage(uid), path), webp(bytes), meta);

beforeAll(async () => {
  env = await initializeTestEnvironment({
    projectId: "demo-roamio",
    firestore: { rules: readFileSync("firestore.rules", "utf8") },
    storage: { rules: readFileSync("storage.rules", "utf8") },
  });
});

afterAll(() => env.cleanup());

beforeEach(async () => {
  await env.clearFirestore();
  await env.clearStorage();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    for (const [uid, ageStatus] of Object.entries({
      alice: "adult",
      bob: "adult",
      cara: "adult",
      dan: "adult",
      pete: "minor_pending",
    })) {
      await setDoc(doc(db, `users/${uid}/private/account`), { ageStatus });
    }
    await setDoc(doc(db, "adventures/a1"), {
      leaderUid: "alice",
      coLeadUids: ["cara"],
      memberUids: ["alice", "bob", "cara", "pete"],
    });
    await setDoc(doc(db, "adventures/a1/tabs/t1"), { createdBy: "bob" });
    const files = ctx.storage();
    await uploadBytes(
      ref(files, "adventures/a1/tabs/t1/old.webp"),
      webp(),
      asWebp,
    );
    await uploadBytes(ref(files, "users/bob/avatar/old.webp"), webp(), asWebp);
  });
});

describe("tab memories", () => {
  const path = "adventures/a1/tabs/t1/m1.webp";

  it("the tab's creator uploads WebP photos; the squad can see them", async () => {
    await assertSucceeds(put("bob", path));
    await assertSucceeds(
      getBytes(ref(storage("alice"), "adventures/a1/tabs/t1/old.webp")),
    );
    await assertSucceeds(
      getBytes(ref(storage("cara"), "adventures/a1/tabs/t1/old.webp")),
    );
  });

  it("other members, outsiders and pending minors can't upload", async () => {
    // A fresh name, so these fail for who is uploading, not a clash.
    const fresh = "adventures/a1/tabs/t1/deny.webp";
    await assertFails(put("alice", fresh));
    await assertFails(put("dan", fresh));
    await assertFails(put("pete", fresh));
    await assertFails(put(undefined, fresh));
    await assertFails(put("bob", "adventures/a1/tabs/nope/m1.webp"));
  });

  it("outsiders and pending minors can't see them", async () => {
    await assertFails(
      getBytes(ref(storage("dan"), "adventures/a1/tabs/t1/old.webp")),
    );
    await assertFails(
      getBytes(ref(storage("pete"), "adventures/a1/tabs/t1/old.webp")),
    );
    await assertFails(
      getBytes(ref(storage(), "adventures/a1/tabs/t1/old.webp")),
    );
  });

  it("rejects files over 1 MB or not WebP", async () => {
    await assertSucceeds(
      put("bob", "adventures/a1/tabs/t1/max.webp", 1024 * 1024),
    );
    await assertFails(
      put("bob", "adventures/a1/tabs/t1/big.webp", 1024 * 1024 + 1),
    );
    await assertFails(
      put("bob", "adventures/a1/tabs/t1/raw.jpg", 1000, {
        contentType: "image/jpeg",
      }),
    );
  });

  it("can't be overwritten or deleted from the app", async () => {
    await assertFails(put("bob", "adventures/a1/tabs/t1/old.webp"));
    await assertFails(
      deleteObject(ref(storage("bob"), "adventures/a1/tabs/t1/old.webp")),
    );
  });
});

describe("adventure banners", () => {
  const path = "adventures/a1/banner/b1.webp";

  it("leads upload a banner; members can see it", async () => {
    await assertSucceeds(put("alice", path));
    await assertSucceeds(put("cara", "adventures/a1/banner/b2.webp"));
    await assertSucceeds(getBytes(ref(storage("bob"), path)));
  });

  it("members and outsiders can't upload; outsiders can't see", async () => {
    const fresh = "adventures/a1/banner/deny.webp";
    await assertFails(put("bob", fresh));
    await assertFails(put("dan", fresh));
    await assertFails(
      put("alice", "adventures/a1/banner/b3.png", 1000, {
        contentType: "image/png",
      }),
    );
    await put("alice", "adventures/a1/banner/b9.webp");
    await assertFails(
      getBytes(ref(storage("dan"), "adventures/a1/banner/b9.webp")),
    );
  });
});

describe("profile photos", () => {
  it("the owner uploads their own; active users can see it", async () => {
    await assertSucceeds(put("bob", "users/bob/avatar/new.webp"));
    await assertSucceeds(
      getBytes(ref(storage("dan"), "users/bob/avatar/old.webp")),
    );
    await assertSucceeds(
      getBytes(ref(storage("bob"), "users/bob/avatar/old.webp")),
    );
  });

  it("nobody else can upload, and pending minors can't browse others", async () => {
    await assertFails(put("dan", "users/bob/avatar/new.webp"));
    await assertFails(
      getBytes(ref(storage("pete"), "users/bob/avatar/old.webp")),
    );
    await assertFails(getBytes(ref(storage(), "users/bob/avatar/old.webp")));
    await assertFails(
      put("bob", "users/bob/avatar/huge.webp", 2 * 1024 * 1024),
    );
  });
});

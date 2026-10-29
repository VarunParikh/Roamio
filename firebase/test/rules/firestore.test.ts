import { readFileSync } from "node:fs";
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
  type RulesTestEnvironment,
} from "@firebase/rules-unit-testing";
import {
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  query,
  serverTimestamp,
  setDoc,
  updateDoc,
  where,
  type Firestore,
} from "firebase/firestore";
import { afterAll, beforeAll, beforeEach, describe, it } from "vitest";

/**
 * Cast (spec §5): alice leads adventure a1, cara is co-lead, bob and mia
 * (a consented minor) are members, dan is an adult outside the squad,
 * pete is a minor still waiting for parental consent, and nora has no
 * account record yet. kiko is a pal.
 */
let env: RulesTestEnvironment;

const as = (uid: string): Firestore =>
  env.authenticatedContext(uid).firestore();
const anon = (): Firestore => env.unauthenticatedContext().firestore();
let nextId = 0;
/** A fresh document path, so each write is a create rather than an edit. */
const fresh = (collectionPath: string) => `${collectionPath}/doc${++nextId}`;

const accounts: Record<string, string> = {
  alice: "adult",
  bob: "adult",
  cara: "adult",
  dan: "adult",
  mia: "minor_active",
  pete: "minor_pending",
  fay: "minor_frozen",
  ola: "adult_unconfirmed",
};

const adventure = {
  name: "College group's Bangkok adventure",
  description: "",
  countryCode: "TH",
  city: "Bangkok",
  startDate: "2026-12-01",
  endDate: "2026-12-08",
  baseCurrency: "THB",
  bannerUrl: null,
  createdBy: "alice",
  leaderUid: "alice",
  coLeadUids: ["cara"],
  memberUids: ["alice", "bob", "cara", "mia"],
};

const tab = (createdBy: string, extra: Record<string, unknown> = {}) => ({
  description: "Street food",
  category: "food",
  amountMinor: 45000,
  currency: "THB",
  date: "2026-12-02",
  fxDate: "2026-12-02",
  payers: [{ id: createdBy, amountMinor: 45000 }],
  participants: ["alice", "bob", "kiko"],
  percentBp: null,
  memories: [],
  createdBy,
  deleted: false,
  ...extra,
});

const settlement = (
  from: string,
  to: string,
  recordedBy: string,
  extra = {},
) => ({
  from,
  to,
  amountMinor: 1000,
  currency: "THB",
  recordedBy,
  undone: false,
  ...extra,
});

beforeAll(async () => {
  env = await initializeTestEnvironment({
    projectId: "demo-roamio",
    firestore: { rules: readFileSync("firestore.rules", "utf8") },
  });
});

afterAll(() => env.cleanup());

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    for (const [uid, ageStatus] of Object.entries(accounts)) {
      await setDoc(doc(db, `users/${uid}`), {
        name: uid,
        photoUrl: null,
        bio: "",
      });
      await setDoc(doc(db, `users/${uid}/private/account`), {
        dob: "2000-01-01",
        ageStatus,
        profileCurrency: "INR",
      });
    }
    await setDoc(doc(db, "adventures/a1"), adventure);
    await setDoc(doc(db, "adventures/a2"), { ...adventure, hasTabs: true });
    await setDoc(doc(db, "adventures/a1/members/bob"), {
      role: "member",
      status: "active",
    });
    await setDoc(doc(db, "adventures/a1/pals/kiko"), {
      nickname: "Kiko",
      addedBy: "alice",
      status: "active",
    });
    await setDoc(doc(db, "adventures/a1/tabs/t1"), tab("bob"));
    await setDoc(
      doc(db, "adventures/a1/settlements/s1"),
      settlement("bob", "alice", "bob"),
    );
    await setDoc(doc(db, "adventures/a1/budgets/bob"), {
      amountMinor: 2000000,
      currency: "INR",
    });
    await setDoc(doc(db, "users/alice/notifications/a1_joined_bob"), {
      type: "member_joined",
      adventureId: "a1",
      memberUid: "bob",
    });
    await setDoc(doc(db, "adventures/a1/activity/x1"), {
      type: "joined",
      actorUid: "bob",
    });
    await setDoc(doc(db, "invites/ROAM7KQ2"), {
      adventureId: "a1",
      adventureName: "Bangkok",
    });
    await setDoc(doc(db, "fx_rates/2026-12-02"), { rates: { INR: "84" } });
    await setDoc(doc(db, "banners/TH"), { url: "https://example.com/th.webp" });
    await setDoc(doc(db, "parentalConsents/mia"), {
      parentUid: "dan",
      decision: "granted",
    });
    await setDoc(doc(db, "auditLog/l1"), { action: "x" });
  });
});

describe("users/{uid} public profile", () => {
  it("owner can create and edit name, photo and bio", async () => {
    await assertSucceeds(
      setDoc(doc(as("nora"), "users/nora"), {
        name: "Nora",
        photoUrl: null,
        bio: "",
      }),
    );
    await assertSucceeds(
      updateDoc(doc(as("bob"), "users/bob"), { bio: "Foodie" }),
    );
  });

  it("nobody else can write it, and no extra fields are allowed", async () => {
    await assertFails(
      updateDoc(doc(as("dan"), "users/bob"), { name: "Hacked" }),
    );
    await assertFails(
      updateDoc(doc(as("bob"), "users/bob"), { email: "b@x.com" }),
    );
    await assertFails(
      setDoc(doc(as("nora"), "users/nora"), {
        name: "",
        photoUrl: null,
        bio: "",
      }),
    );
  });

  it("active users can read other profiles; pending minors only their own", async () => {
    await assertSucceeds(getDoc(doc(as("dan"), "users/bob")));
    await assertSucceeds(getDoc(doc(as("pete"), "users/pete")));
    await assertFails(getDoc(doc(as("pete"), "users/bob")));
    await assertFails(getDoc(doc(anon(), "users/bob")));
  });
});

describe("users/{uid}/private/account", () => {
  const fresh = {
    dob: "2010-05-01",
    profileCurrency: "INR",
    consents: {},
    noticeVersion: "1",
  };

  it("owner creates it with a date of birth but no server fields", async () => {
    await assertSucceeds(
      setDoc(doc(as("nora"), "users/nora/private/account"), fresh),
    );
    await assertFails(
      setDoc(doc(as("nora"), "users/nora/private/account"), {
        ...fresh,
        ageStatus: "adult",
      }),
    );
    await assertFails(
      setDoc(doc(as("nora"), "users/nora/private/account"), {
        profileCurrency: "INR",
      }),
    );
  });

  it("owner can change currency and consents but never dob or age status", async () => {
    const own = doc(as("bob"), "users/bob/private/account");
    await assertSucceeds(
      updateDoc(own, { profileCurrency: "EUR", consents: { location: true } }),
    );
    await assertFails(updateDoc(own, { dob: "1990-01-01" }));
    await assertFails(updateDoc(own, { ageStatus: "minor_active" }));
    await assertFails(
      updateDoc(doc(as("pete"), "users/pete/private/account"), {
        ageStatus: "minor_active",
      }),
    );
  });

  it("is private to its owner", async () => {
    await assertSucceeds(getDoc(doc(as("bob"), "users/bob/private/account")));
    await assertFails(getDoc(doc(as("alice"), "users/bob/private/account")));
  });
});

describe("users/{uid}/invites", () => {
  it("owner saves invite codes they opened; others cannot", async () => {
    await assertSucceeds(
      setDoc(doc(as("pete"), "users/pete/invites/ROAM7KQ2"), {
        code: "ROAM7KQ2",
        addedAt: 1,
      }),
    );
    await assertFails(
      setDoc(doc(as("dan"), "users/pete/invites/ROAM7KQ2"), {
        code: "ROAM7KQ2",
        addedAt: 1,
      }),
    );
    await assertFails(
      setDoc(doc(as("pete"), "users/pete/invites/ROAM7KQ2"), {
        code: "OTHER",
        addedAt: 1,
      }),
    );
  });
});

describe("users/{uid}/notifications (lead cards, spec UC-14)", () => {
  const path = "users/alice/notifications/a1_joined_bob";

  it("owner reads and dismisses their cards", async () => {
    await assertSucceeds(getDoc(doc(as("alice"), path)));
    await assertSucceeds(
      getDocs(collection(as("alice"), "users/alice/notifications")),
    );
    await assertSucceeds(deleteDoc(doc(as("alice"), path)));
  });

  it("nobody else can read or dismiss them", async () => {
    await assertFails(getDoc(doc(as("cara"), path)));
    await assertFails(getDoc(doc(as("bob"), path)));
    await assertFails(getDoc(doc(anon(), path)));
    await assertFails(
      getDocs(collection(as("cara"), "users/alice/notifications")),
    );
    await assertFails(deleteDoc(doc(as("bob"), path)));
  });

  it("only the server writes them, even for the owner", async () => {
    await assertFails(
      setDoc(doc(as("alice"), "users/alice/notifications/fake"), {
        type: "member_joined",
      }),
    );
    await assertFails(updateDoc(doc(as("alice"), path), { memberUid: "dan" }));
    await assertFails(
      setDoc(doc(as("bob"), "users/alice/notifications/fake"), {
        type: "member_joined",
      }),
    );
  });
});

describe("adventures", () => {
  const draft = {
    ...adventure,
    createdBy: "dan",
    leaderUid: "dan",
    coLeadUids: [],
    memberUids: ["dan"],
  };

  it("an active user creates one as its only member and leader", async () => {
    await assertSucceeds(setDoc(doc(as("dan"), "adventures/new"), draft));
    await assertSucceeds(
      setDoc(doc(as("mia"), "adventures/new2"), {
        ...draft,
        createdBy: "mia",
        leaderUid: "mia",
        memberUids: ["mia"],
      }),
    );
  });

  it("rejects bad creations", async () => {
    await assertFails(
      setDoc(doc(as("dan"), "adventures/n"), {
        ...draft,
        memberUids: ["dan", "bob"],
      }),
    );
    await assertFails(
      setDoc(doc(as("dan"), "adventures/n"), { ...draft, leaderUid: "bob" }),
    );
    await assertFails(
      setDoc(doc(as("dan"), "adventures/n"), { ...draft, coLeadUids: ["bob"] }),
    );
    await assertFails(
      setDoc(doc(as("dan"), "adventures/n"), {
        ...draft,
        endDate: "2026-11-30",
      }),
    );
    await assertFails(
      setDoc(doc(as("dan"), "adventures/n"), {
        ...draft,
        baseCurrency: "baht",
      }),
    );
    await assertFails(
      setDoc(doc(as("dan"), "adventures/n"), { ...draft, hasTabs: false }),
    );
    await assertFails(
      setDoc(doc(as("pete"), "adventures/n"), {
        ...draft,
        createdBy: "pete",
        leaderUid: "pete",
        memberUids: ["pete"],
      }),
    );
  });

  it("members list their own adventures; nobody lists everyone's", async () => {
    const mine = query(
      collection(as("bob"), "adventures"),
      where("memberUids", "array-contains", "bob"),
    );
    await assertSucceeds(getDocs(mine));
    await assertFails(getDocs(collection(as("bob"), "adventures")));
    const someoneElses = query(
      collection(as("dan"), "adventures"),
      where("memberUids", "array-contains", "bob"),
    );
    await assertFails(getDocs(someoneElses));
    const pending = query(
      collection(as("pete"), "adventures"),
      where("memberUids", "array-contains", "pete"),
    );
    await assertFails(getDocs(pending));
  });

  it("only members can read it", async () => {
    await assertSucceeds(getDoc(doc(as("bob"), "adventures/a1")));
    await assertFails(getDoc(doc(as("dan"), "adventures/a1")));
  });

  it("leader and co-lead edit metadata; members cannot", async () => {
    await assertSucceeds(
      updateDoc(doc(as("alice"), "adventures/a1"), { name: "BKK" }),
    );
    await assertSucceeds(
      updateDoc(doc(as("cara"), "adventures/a1"), { endDate: "2026-12-09" }),
    );
    await assertFails(
      updateDoc(doc(as("bob"), "adventures/a1"), { name: "Mine" }),
    );
  });

  it("membership and roles are server-only, even for leads", async () => {
    await assertFails(
      updateDoc(doc(as("alice"), "adventures/a1"), {
        memberUids: ["alice", "dan"],
      }),
    );
    await assertFails(
      updateDoc(doc(as("alice"), "adventures/a1"), { coLeadUids: ["bob"] }),
    );
    await assertFails(
      updateDoc(doc(as("cara"), "adventures/a1"), { leaderUid: "cara" }),
    );
    await assertFails(
      updateDoc(doc(as("alice"), "adventures/a1"), { hasTabs: false }),
    );
  });

  it("base currency is locked once the adventure has tabs", async () => {
    await assertSucceeds(
      updateDoc(doc(as("alice"), "adventures/a1"), { baseCurrency: "INR" }),
    );
    await assertFails(
      updateDoc(doc(as("alice"), "adventures/a2"), { baseCurrency: "INR" }),
    );
  });

  it("can't be deleted", async () => {
    await assertFails(deleteDoc(doc(as("alice"), "adventures/a1")));
  });
});

describe("members and activity (server-written)", () => {
  it("members can read; nobody can write", async () => {
    await assertSucceeds(getDoc(doc(as("bob"), "adventures/a1/members/bob")));
    await assertFails(getDoc(doc(as("dan"), "adventures/a1/members/bob")));
    await assertFails(
      setDoc(doc(as("alice"), "adventures/a1/members/dan"), {
        role: "member",
        status: "active",
      }),
    );
    await assertSucceeds(getDoc(doc(as("mia"), "adventures/a1/activity/x1")));
    await assertFails(
      setDoc(doc(as("alice"), "adventures/a1/activity/x2"), { type: "fake" }),
    );
  });
});

describe("pals", () => {
  const pal = { nickname: "Lu", addedBy: "cara", status: "active" };

  it("leads add and rename pals; members cannot", async () => {
    await assertSucceeds(setDoc(doc(as("cara"), "adventures/a1/pals/lu"), pal));
    await assertSucceeds(
      updateDoc(doc(as("alice"), "adventures/a1/pals/kiko"), {
        nickname: "Kiks",
      }),
    );
    await assertFails(
      setDoc(doc(as("bob"), "adventures/a1/pals/lu"), {
        ...pal,
        addedBy: "bob",
      }),
    );
  });

  it("pals hold a nickname only, and are never hard-deleted", async () => {
    await assertFails(
      setDoc(doc(as("cara"), "adventures/a1/pals/lu"), {
        ...pal,
        phone: "+91…",
      }),
    );
    await assertSucceeds(
      updateDoc(doc(as("alice"), "adventures/a1/pals/kiko"), {
        status: "left",
      }),
    );
    await assertFails(deleteDoc(doc(as("alice"), "adventures/a1/pals/kiko")));
  });

  it("members can read pals", async () => {
    await assertSucceeds(getDocs(collection(as("bob"), "adventures/a1/pals")));
    await assertFails(getDocs(collection(as("dan"), "adventures/a1/pals")));
  });
});

describe("tabs", () => {
  it("members add tabs as themselves", async () => {
    await assertSucceeds(
      setDoc(doc(as("bob"), fresh("adventures/a1/tabs")), tab("bob")),
    );
    await assertSucceeds(
      setDoc(doc(as("mia"), fresh("adventures/a1/tabs")), tab("mia")),
    );
  });

  it("rejects tabs from outsiders, impersonation and bad shapes", async () => {
    await assertFails(
      setDoc(doc(as("dan"), fresh("adventures/a1/tabs")), tab("dan")),
    );
    await assertFails(
      setDoc(doc(as("bob"), fresh("adventures/a1/tabs")), tab("alice")),
    );
    await assertFails(
      setDoc(
        doc(as("bob"), fresh("adventures/a1/tabs")),
        tab("bob", { amountMinor: 0 }),
      ),
    );
    await assertFails(
      setDoc(
        doc(as("bob"), fresh("adventures/a1/tabs")),
        tab("bob", { amountMinor: 450.5 }),
      ),
    );
    await assertFails(
      setDoc(
        doc(as("bob"), fresh("adventures/a1/tabs")),
        tab("bob", { participants: [] }),
      ),
    );
    await assertFails(
      setDoc(
        doc(as("bob"), fresh("adventures/a1/tabs")),
        tab("bob", { payers: [] }),
      ),
    );
    await assertFails(
      setDoc(
        doc(as("bob"), fresh("adventures/a1/tabs")),
        tab("bob", { deleted: true }),
      ),
    );
    await assertFails(
      setDoc(
        doc(as("bob"), fresh("adventures/a1/tabs")),
        tab("bob", { memories: ["a", "b", "c", "d", "e"] }),
      ),
    );
  });

  it("location is allowed for adults and refused for minors (spec §7.2)", async () => {
    const location = { lat: 13.75, lng: 100.5 };
    await assertSucceeds(
      setDoc(
        doc(as("bob"), fresh("adventures/a1/tabs")),
        tab("bob", { location }),
      ),
    );
    await assertFails(
      setDoc(
        doc(as("mia"), fresh("adventures/a1/tabs")),
        tab("mia", { location }),
      ),
    );
  });

  it("the creator edits; other members cannot", async () => {
    await assertSucceeds(
      updateDoc(doc(as("bob"), "adventures/a1/tabs/t1"), {
        amountMinor: 50000,
      }),
    );
    await assertFails(
      updateDoc(doc(as("mia"), "adventures/a1/tabs/t1"), { amountMinor: 1 }),
    );
    await assertFails(
      updateDoc(doc(as("bob"), "adventures/a1/tabs/t1"), { createdBy: "mia" }),
    );
  });

  it("leads can only soft-delete someone else's tab", async () => {
    await assertSucceeds(
      updateDoc(doc(as("cara"), "adventures/a1/tabs/t1"), {
        deleted: true,
        updatedAt: serverTimestamp(),
      }),
    );
    await assertFails(
      updateDoc(doc(as("cara"), "adventures/a1/tabs/t1"), { amountMinor: 1 }),
    );
    await assertFails(deleteDoc(doc(as("alice"), "adventures/a1/tabs/t1")));
  });

  it("only members read tabs", async () => {
    await assertSucceeds(getDocs(collection(as("mia"), "adventures/a1/tabs")));
    await assertFails(getDocs(collection(as("dan"), "adventures/a1/tabs")));
  });
});

describe("settlements", () => {
  it("a party to the payment records it", async () => {
    await assertSucceeds(
      setDoc(
        doc(as("bob"), fresh("adventures/a1/settlements")),
        settlement("bob", "alice", "bob"),
      ),
    );
    await assertSucceeds(
      setDoc(
        doc(as("alice"), fresh("adventures/a1/settlements")),
        settlement("bob", "alice", "alice"),
      ),
    );
  });

  it("a lead records it when a pal is involved; others cannot", async () => {
    await assertSucceeds(
      setDoc(
        doc(as("cara"), fresh("adventures/a1/settlements")),
        settlement("kiko", "alice", "cara"),
      ),
    );
    await assertFails(
      setDoc(
        doc(as("mia"), fresh("adventures/a1/settlements")),
        settlement("bob", "alice", "mia"),
      ),
    );
    await assertFails(
      setDoc(
        doc(as("mia"), fresh("adventures/a1/settlements")),
        settlement("kiko", "alice", "mia"),
      ),
    );
  });

  it("rejects bad settlements", async () => {
    await assertFails(
      setDoc(
        doc(as("bob"), fresh("adventures/a1/settlements")),
        settlement("bob", "bob", "bob"),
      ),
    );
    await assertFails(
      setDoc(
        doc(as("bob"), fresh("adventures/a1/settlements")),
        settlement("bob", "alice", "bob", { currency: "INR" }),
      ),
    );
    await assertFails(
      setDoc(
        doc(as("bob"), fresh("adventures/a1/settlements")),
        settlement("bob", "alice", "bob", { amountMinor: 0 }),
      ),
    );
    await assertFails(
      setDoc(
        doc(as("bob"), fresh("adventures/a1/settlements")),
        settlement("bob", "dan", "bob"),
      ),
    );
    await assertFails(
      setDoc(
        doc(as("bob"), fresh("adventures/a1/settlements")),
        settlement("bob", "alice", "alice"),
      ),
    );
  });

  it("can be undone but not edited", async () => {
    const s1 = "adventures/a1/settlements/s1";
    await assertFails(updateDoc(doc(as("bob"), s1), { amountMinor: 1 }));
    await assertFails(
      updateDoc(doc(as("mia"), s1), { undone: true, undoneBy: "mia" }),
    );
    await assertSucceeds(
      updateDoc(doc(as("alice"), s1), { undone: true, undoneBy: "alice" }),
    );
  });
});

describe("budgets (private to their owner, spec UC-19)", () => {
  it("the owner sets and reads their budget", async () => {
    await assertSucceeds(getDoc(doc(as("bob"), "adventures/a1/budgets/bob")));
    await assertSucceeds(
      setDoc(doc(as("mia"), "adventures/a1/budgets/mia"), {
        amountMinor: 1000000,
        currency: "INR",
        updatedAt: serverTimestamp(),
      }),
    );
  });

  it("nobody else can read it, including the squad leader", async () => {
    await assertFails(getDoc(doc(as("alice"), "adventures/a1/budgets/bob")));
    await assertFails(getDoc(doc(as("mia"), "adventures/a1/budgets/bob")));
    await assertFails(
      getDocs(collection(as("alice"), "adventures/a1/budgets")),
    );
  });

  it("owners can't write server alert state or budgets elsewhere", async () => {
    await assertFails(
      updateDoc(doc(as("bob"), "adventures/a1/budgets/bob"), {
        alertsSent: [80, 100],
      }),
    );
    await assertFails(
      setDoc(doc(as("dan"), "adventures/a1/budgets/dan"), {
        amountMinor: 1,
        currency: "INR",
      }),
    );
    await assertFails(
      setDoc(doc(as("alice"), "adventures/a1/budgets/bob"), {
        amountMinor: 1,
        currency: "INR",
      }),
    );
  });
});

describe("invites, fx rates and banners", () => {
  it("active users get a single invite; listing and writing are blocked", async () => {
    await assertSucceeds(getDoc(doc(as("dan"), "invites/ROAM7KQ2")));
    await assertFails(getDocs(collection(as("dan"), "invites")));
    await assertFails(
      setDoc(doc(as("alice"), "invites/NEW"), { adventureId: "a1" }),
    );
  });

  it("a minor whose consent was withdrawn loses access at once (spec §7.3)", async () => {
    await assertFails(getDoc(doc(as("fay"), "invites/ROAM7KQ2")));
    await assertFails(getDoc(doc(as("fay"), "fx_rates/2026-12-02")));
    await assertSucceeds(getDoc(doc(as("fay"), "users/fay")));
  });

  it("a newly-18 account waits until it accepts the adult notice (spec §7.4)", async () => {
    await assertFails(getDoc(doc(as("ola"), "fx_rates/2026-12-02")));
    await assertSucceeds(getDoc(doc(as("ola"), "users/ola/private/account")));
  });

  it("pending minors can't open invites yet", async () => {
    await assertFails(getDoc(doc(as("pete"), "invites/ROAM7KQ2")));
  });

  it("rates and banners are readable by active users and written by the server", async () => {
    await assertSucceeds(getDoc(doc(as("bob"), "fx_rates/2026-12-02")));
    await assertSucceeds(getDoc(doc(as("bob"), "banners/TH")));
    await assertFails(getDoc(doc(anon(), "fx_rates/2026-12-02")));
    await assertFails(
      setDoc(doc(as("bob"), "fx_rates/2026-12-03"), { rates: {} }),
    );
    await assertFails(setDoc(doc(as("bob"), "banners/TH"), { url: "x" }));
  });
});

describe("parental consents and audit log", () => {
  it("child and parent can read the consent record; nobody can write it", async () => {
    await assertSucceeds(getDoc(doc(as("mia"), "parentalConsents/mia")));
    await assertSucceeds(getDoc(doc(as("dan"), "parentalConsents/mia")));
    await assertFails(getDoc(doc(as("bob"), "parentalConsents/mia")));
    await assertFails(
      updateDoc(doc(as("mia"), "parentalConsents/mia"), {
        decision: "granted",
      }),
    );
  });

  it("the audit log is not readable from the app", async () => {
    await assertFails(getDoc(doc(as("alice"), "auditLog/l1")));
  });
});

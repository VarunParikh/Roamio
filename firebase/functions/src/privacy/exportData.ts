import { crc32 } from "node:zlib";
import {
  type DocumentSnapshot,
  FieldValue,
  getFirestore,
  Timestamp,
} from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";
import { HttpsError, onCall } from "firebase-functions/https";
import { uidOf } from "../invites/invites";

// Data export (spec UC-29, §7.3): a person's own records as JSON, and their
// photos as zip parts small enough to return from a callable. Built on demand
// and never stored, so it costs nothing between downloads.

const db = () => getFirestore();

/** Raw photo bytes per zip part; base64 keeps the reply well under 32 MB. */
export const PART_BYTES = 6 * 1024 * 1024;

type Plain = Record<string, unknown>;

/** Firestore values as JSON: times become ISO text. */
function plain(value: unknown): unknown {
  if (value instanceof Timestamp) return value.toDate().toISOString();
  if (Array.isArray(value)) return value.map(plain);
  if (value && typeof value === "object") {
    return Object.fromEntries(Object.entries(value).map(([k, v]) => [k, plain(v)]));
  }
  return value;
}

const withId = (doc: DocumentSnapshot): Plain & { id: string } => ({
  id: doc.id,
  ...(plain(doc.data()) as Plain),
});

/** Consent records without the emailed link's secret. */
function consentRecord(doc: DocumentSnapshot): Plain {
  const record = plain(doc.data()) as Plain;
  delete record.tokenHash;
  return record;
}

function involves(uid: string, tab: Plain): boolean {
  const payers = (tab.payers as { id: string }[] | undefined) ?? [];
  const participants = (tab.participants as string[] | undefined) ?? [];
  return tab.createdBy === uid || participants.includes(uid) || payers.some((p) => p.id === uid);
}

/** Where someone else was when they added a tab isn't the person's data. */
function withoutLocation<T extends Plain>(tab: T): T {
  const rest = { ...tab };
  delete rest.location;
  return rest;
}

function roleIn(uid: string, adventure: DocumentSnapshot): string {
  if (!(adventure.get("memberUids") ?? []).includes(uid)) return "left";
  if (adventure.get("leaderUid") === uid) return "leader";
  if ((adventure.get("coLeadUids") ?? []).includes(uid)) return "co_lead";
  return "member";
}

/** Adventures the person is in, then ones they left with tabs to their name. */
async function adventuresOf(uid: string): Promise<DocumentSnapshot[]> {
  const [current, left] = await Promise.all([
    db().collection("adventures").where("memberUids", "array-contains", uid).get(),
    db().collection("adventures").where("leftUids", "array-contains", uid).get(),
  ]);
  return [...current.docs, ...left.docs.filter((d) => !current.docs.some((c) => c.id === d.id))];
}

/** Everything Roamio holds about one person, minus other people's private data. */
export async function collectData(uid: string) {
  const [profile, account, invites, notifications, asChild, asParent, audit] = await Promise.all([
    db().doc(`users/${uid}`).get(),
    db().doc(`users/${uid}/private/account`).get(),
    db().collection(`users/${uid}/invites`).get(),
    db().collection(`users/${uid}/notifications`).get(),
    db().doc(`parentalConsents/${uid}`).get(),
    db().collection("parentalConsents").where("parentUid", "==", uid).get(),
    db().collection("auditLog").where("target", "==", uid).get(),
  ]);
  const memberships = await adventuresOf(uid);

  const adventures = await Promise.all(
    memberships.map(async (adventure) => {
      const [tabs, settlements, budget, activity] = await Promise.all([
        adventure.ref.collection("tabs").get(),
        adventure.ref.collection("settlements").get(),
        adventure.ref.collection("budgets").doc(uid).get(),
        adventure.ref.collection("activity").get(),
      ]);
      return {
        id: adventure.id,
        name: adventure.get("name"),
        countryCode: adventure.get("countryCode"),
        city: adventure.get("city") ?? null,
        startDate: adventure.get("startDate"),
        endDate: adventure.get("endDate"),
        baseCurrency: adventure.get("baseCurrency"),
        role: roleIn(uid, adventure),
        tabs: tabs.docs
          .map(withId)
          .filter((t) => involves(uid, t))
          .map((t) => (t.createdBy === uid ? t : withoutLocation(t))),
        settlements: settlements.docs
          .map(withId)
          .filter((s) => s.from === uid || s.to === uid || s.recordedBy === uid),
        budget: budget.exists ? (plain(budget.data()) as Plain) : null,
        activity: activity.docs.map(withId).filter((a) => a.actorUid === uid || a.subject === uid),
      };
    }),
  );

  return {
    exportedAt: new Date().toISOString(),
    you: {
      uid,
      profile: profile.exists ? (plain(profile.data()) as Plain) : null,
      account: account.exists ? (plain(account.data()) as Plain) : null,
      invites: invites.docs.map(withId),
      notifications: notifications.docs.map(withId),
    },
    adventures,
    parentalConsent: asChild.exists ? consentRecord(asChild) : null,
    linkedChildren: asParent.docs.map(consentRecord),
    auditLog: audit.docs.map(withId),
  };
}

/** Where a person's photos live: profile photos and memories on tabs they added. */
export async function photoPrefixes(uid: string): Promise<string[]> {
  const memberships = await adventuresOf(uid);
  const prefixes = [`users/${uid}/avatar/`];
  for (const adventure of memberships) {
    const tabs = await adventure.ref.collection("tabs").where("createdBy", "==", uid).get();
    prefixes.push(...tabs.docs.map((t) => `adventures/${adventure.id}/tabs/${t.id}/`));
  }
  return prefixes;
}

export type PhotoFile = { name: string; size: number };

/** Splits photos, in order, into parts of at most [max] bytes (a larger photo goes alone). */
export function photoParts(files: PhotoFile[], max = PART_BYTES): PhotoFile[][] {
  const parts: PhotoFile[][] = [];
  let bytes = 0;
  for (const file of files) {
    const last = parts.at(-1);
    if (last && bytes + file.size <= max) {
      last.push(file);
      bytes += file.size;
    } else {
      parts.push([file]);
      bytes = file.size;
    }
  }
  return parts;
}

/** A zip with each file stored as is: photos are WebP already, so deflate gains nothing. */
export function zipStored(files: { name: string; data: Buffer }[]): Buffer {
  const chunks: Buffer[] = [];
  const central: Buffer[] = [];
  let offset = 0;
  for (const { name, data } of files) {
    const path = Buffer.from(name, "utf8");
    const crc = crc32(data);
    // Shared fields: version 2.0, UTF-8 names, stored, 1980-01-01 00:00.
    const common = (h: Buffer, at: number) => {
      h.writeUInt16LE(20, at);
      h.writeUInt16LE(0x0800, at + 2);
      h.writeUInt16LE(0, at + 4);
      h.writeUInt16LE(0, at + 6);
      h.writeUInt16LE(0x21, at + 8);
      h.writeUInt32LE(crc, at + 10);
      h.writeUInt32LE(data.length, at + 14);
      h.writeUInt32LE(data.length, at + 18);
      h.writeUInt16LE(path.length, at + 22);
    };
    const local = Buffer.alloc(30);
    local.writeUInt32LE(0x04034b50, 0);
    common(local, 4);
    chunks.push(local, path, data);

    const entry = Buffer.alloc(46);
    entry.writeUInt32LE(0x02014b50, 0);
    entry.writeUInt16LE(20, 4);
    common(entry, 6);
    entry.writeUInt32LE(offset, 42);
    central.push(entry, path);
    offset += local.length + path.length + data.length;
  }
  const directory = Buffer.concat(central);
  const end = Buffer.alloc(22);
  end.writeUInt32LE(0x06054b50, 0);
  end.writeUInt16LE(files.length, 8);
  end.writeUInt16LE(files.length, 10);
  end.writeUInt32LE(directory.length, 12);
  end.writeUInt32LE(offset, 16);
  return Buffer.concat([...chunks, directory, end]);
}

async function listPhotos(uid: string): Promise<PhotoFile[]> {
  const bucket = getStorage().bucket();
  const found: PhotoFile[] = [];
  for (const prefix of await photoPrefixes(uid)) {
    const [files] = await bucket.getFiles({ prefix });
    found.push(...files.map((f) => ({ name: f.name, size: Number(f.metadata.size ?? 0) })));
  }
  return found;
}

/** The caller, or a parent with granted consent for [childUid] (spec §7.3). */
async function subjectFor(caller: string, childUid: unknown): Promise<string> {
  if (childUid === undefined || childUid === null || childUid === caller) return caller;
  const consent = await db()
    .doc(`parentalConsents/${String(childUid)}`)
    .get();
  if (consent.get("parentUid") !== caller || consent.get("status") !== "granted") {
    throw new HttpsError(
      "permission-denied",
      "You can only download your own or your linked child's data.",
    );
  }
  return String(childUid);
}

/**
 * Without `photosPart`: the JSON and how many photo parts there are.
 * With `photosPart` n (from 0): that part as a base64 zip.
 */
export const exportMyData = onCall(async (request) => {
  const caller = uidOf(request);
  const uid = await subjectFor(caller, request.data?.childUid);
  const parts = photoParts(await listPhotos(uid));

  const wanted = request.data?.photosPart;
  if (wanted === undefined || wanted === null) {
    const data = await collectData(uid);
    await db().collection("auditLog").add({
      actorUid: caller,
      action: "data_exported",
      target: uid,
      at: FieldValue.serverTimestamp(),
    });
    return { data, photoParts: parts.length };
  }
  if (!Number.isInteger(wanted) || wanted < 0 || wanted >= parts.length) {
    throw new HttpsError("invalid-argument", "That photo part doesn't exist.");
  }
  const bucket = getStorage().bucket();
  const files = await Promise.all(
    parts[wanted].map(async (f) => ({
      name: f.name,
      data: (await bucket.file(f.name).download())[0],
    })),
  );
  return { part: wanted, of: parts.length, zip: zipStored(files).toString("base64") };
});

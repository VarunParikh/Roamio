import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { logger } from "firebase-functions";
import { onDocumentWritten } from "firebase-functions/firestore";
import { sendPush } from "../notify/push";
import { serverConfig } from "../config";

// Personal budget alerts (spec UC-19, UC-20). A budget is measured against
// its owner's own share of the adventure's tabs, each converted into the
// budget's currency at the tab's own day's rates, with the same exact maths
// as the app's split engine (spec §6, §9.1). Alerts fire once per threshold;
// changing the budget resets them.

const db = () => getFirestore();

/** The default for Remote Config `budget_alert_thresholds` (spec §11). */
export const BUDGET_THRESHOLDS = [80, 100];

// ISO 4217 currencies whose minor unit isn't 2 digits (as in money.dart).
const NO_DECIMALS = "BIF CLP DJF GNF ISK JPY KMF KRW PYG RWF UGX UYI VND VUV XAF XOF XPF";
const THREE_DECIMALS = "BHD IQD JOD KWD LYD OMR TND";
const MINOR_DIGITS: Record<string, number> = Object.fromEntries([
  ...NO_DECIMALS.split(" ").map((c) => [c, 0]),
  ...THREE_DECIMALS.split(" ").map((c) => [c, 3]),
]);
const digits = (currency: string) => MINOR_DIGITS[currency] ?? 2;
const pow10 = (n: number) => 10n ** BigInt(n);

export type TabDoc = {
  amountMinor: number;
  participants: string[];
  percentBp?: Record<string, number> | null;
};

/** [total] split by [weights], remainders one unit at a time in order. */
function allocate(total: number, weights: number[]): number[] {
  const sum = weights.reduce((a, b) => a + BigInt(b), 0n);
  const parts = weights.map((w) => (BigInt(total) * BigInt(w)) / sum);
  let left = BigInt(total) - parts.reduce((a, b) => a + b, 0n);
  for (let i = 0; left > 0n; i++, left--) parts[i]++;
  return parts.map(Number);
}

/** [uid]'s share of [tab] once its whole amount is [converted] minor units. */
export function shareOf(tab: TabDoc, converted: number, uid: string): number {
  const i = tab.participants.indexOf(uid);
  if (i < 0 || converted === 0) return 0;
  const bp = tab.percentBp;
  const weights = tab.participants.map((p) => (bp ? (bp[p] ?? 0) : 1));
  return allocate(converted, weights)[i];
}

function parseRate(text: string): { units: bigint; scale: number } {
  const m = /^(\d+)(?:\.(\d+))?$/.exec(text);
  if (!m) throw new Error(`Bad rate ${text}`);
  return { units: BigInt(m[1] + (m[2] ?? "")), scale: (m[2] ?? "").length };
}

/**
 * [minor] of [from] in [to]'s minor units, with [rates] (units per USD),
 * rounding half to even like the app. Throws if a rate is missing.
 */
export function convertMinor(
  minor: number,
  from: string,
  to: string,
  rates: Record<string, string>,
): number {
  if (from === to) return minor;
  const rate = (c: string) => {
    if (c === "USD") return { units: 1n, scale: 0 };
    if (!rates[c]) throw new Error(`No ${c} rate`);
    return parseRate(rates[c]);
  };
  const f = rate(from);
  const t = rate(to);
  const n = BigInt(minor) * pow10(digits(to) + f.scale) * t.units;
  const d = pow10(digits(from) + t.scale) * f.units;
  const negative = n < 0n;
  const abs = negative ? -n : n;
  let q = abs / d;
  const twice = (abs - q * d) * 2n;
  if (twice > d || (twice === d && q % 2n === 1n)) q++;
  return Number(negative ? -q : q);
}

/** Thresholds (in %) that [share] has reached of [budget]. */
export function thresholdsReached(
  share: number,
  budget: number,
  thresholds: number[] = BUDGET_THRESHOLDS,
): number[] {
  return thresholds.filter((t) => BigInt(share) * 100n >= BigInt(t) * BigInt(budget));
}

/** The latest stored rates on or before [date] (Task 28). */
/**
 * The rates for [date], falling back to the earliest rates after it when none
 * are older, exactly as the app does (FirebaseFxRepository.ratesFor), so a tab
 * dated before any rates still counts.
 */
async function ratesOn(date: string): Promise<Record<string, string>> {
  const older = await db()
    .collection("fx_rates")
    .where("date", "<=", date)
    .orderBy("date", "desc")
    .limit(1)
    .get();
  const doc =
    older.docs[0] ??
    (await db().collection("fx_rates").where("date", ">", date).orderBy("date").limit(1).get())
      .docs[0];
  return (doc?.get("rates") as Record<string, string>) ?? {};
}

/** Tabs that count towards a budget: waiting and rejected ones don't (spec UC-20). */
const COUNTED_STATUSES = ["approved", "personal"];

/**
 * Sends any budget alerts [uid] is now due on adventure [aid]; returns the
 * thresholds newly alerted. Safe to run twice: a transaction records each
 * threshold once.
 */
export async function checkBudget(aid: string, uid: string): Promise<number[]> {
  const adventureRef = db().doc(`adventures/${aid}`);
  const budgetRef = adventureRef.collection("budgets").doc(uid);
  const budget = await budgetRef.get();
  if (!budget.exists) return [];
  const amount = budget.get("amountMinor") as number;
  const currency = budget.get("currency") as string;

  let share = 0;
  try {
    const tabs = await adventureRef.collection("tabs").where("deleted", "==", false).get();
    const rateCache = new Map<string, Record<string, string>>();
    for (const doc of tabs.docs) {
      const tab = doc.data() as TabDoc & { currency: string; fxDate: string; status?: string };
      if (!COUNTED_STATUSES.includes(tab.status ?? "approved")) continue;
      if (!tab.participants?.includes(uid)) continue;
      const rates = rateCache.get(tab.fxDate) ?? (await ratesOn(tab.fxDate));
      rateCache.set(tab.fxDate, rates);
      // A tab with no rate yet counts for nothing rather than blocking this
      // person's alerts for every other tab (item 7).
      try {
        share += shareOf(tab, convertMinor(tab.amountMinor, tab.currency, currency, rates), uid);
      } catch (e) {
        logger.warn("Budget skipped a tab: rate missing", { aid, tab: doc.id, error: String(e) });
      }
    }
  } catch (e) {
    logger.warn("Budget not checked: rates missing", { aid, error: String(e) });
    return [];
  }

  const adventureName = String((await adventureRef.get()).get("name") ?? "your adventure");
  const { budgetThresholds } = await serverConfig();
  const fresh = await db().runTransaction(async (tx) => {
    const now = await tx.get(budgetRef);
    // The budget changed meanwhile: its own trigger will check again.
    if (now.get("amountMinor") !== amount || now.get("currency") !== currency) return [];
    const sent: number[] = now.get("alertsSent") ?? [];
    const due = thresholdsReached(share, amount, budgetThresholds).filter((t) => !sent.includes(t));
    if (due.length === 0) return [];
    tx.update(budgetRef, { alertsSent: FieldValue.arrayUnion(...due) });
    for (const t of due) {
      tx.set(db().doc(`users/${uid}/notifications/${aid}_budget_${t}`), {
        type: "budget_alert",
        adventureId: aid,
        adventureName,
        threshold: t,
        createdAt: FieldValue.serverTimestamp(),
      });
    }
    return due;
  });

  if (fresh.length > 0) {
    const top = Math.max(...fresh);
    await sendPush([uid], {
      title:
        top >= 100
          ? `You've reached your ${adventureName} budget`
          : `You've used ${top}% of your ${adventureName} budget`,
      body: "Your share of the tabs so far.",
      data: { type: "budget_alert", adventureId: aid },
    });
  }
  return fresh;
}

/** A tab changed: check the budgets of everyone sharing it, before and after. */
export const budgetOnTab = onDocumentWritten("adventures/{aid}/tabs/{tid}", async (event) => {
  const people = new Set<string>([
    ...((event.data?.before?.get("participants") as string[]) ?? []),
    ...((event.data?.after?.get("participants") as string[]) ?? []),
  ]);
  for (const uid of people) await checkBudget(event.params.aid, uid);
});

/** A budget was set or changed: clear its alerts, then check it afresh. */
export const budgetOnChange = onDocumentWritten("adventures/{aid}/budgets/{uid}", async (event) => {
  const before = event.data?.before?.data();
  const after = event.data?.after;
  if (!after?.exists) return;
  const changed =
    !before ||
    before.amountMinor !== after.get("amountMinor") ||
    before.currency !== after.get("currency");
  if (!changed) return; // our own alertsSent writes land here too
  if ((after.get("alertsSent") ?? []).length > 0) {
    await after.ref.update({ alertsSent: [] });
  }
  await checkBudget(event.params.aid, event.params.uid);
});

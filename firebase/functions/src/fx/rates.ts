import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { logger } from "firebase-functions";
import { onSchedule } from "firebase-functions/scheduler";

// Daily exchange rates (spec §9.1): units of each currency per 1 USD,
// stored as exact decimal text in fx_rates/{yyyy-mm-dd}. Each tab converts
// with its own day's rates, so old totals never change. If the provider is
// down nothing is written and the app uses the latest earlier day.

const SOURCE = "https://open.er-api.com/v6/latest/USD";

/** A rate as plain decimal text ("1.2e-7" → "0.00000012"); null unless > 0. */
export function plainDecimal(text: string): string | null {
  const m = /^(\d+)(?:\.(\d+))?(?:[eE]([+-]?\d+))?$/.exec(text.trim());
  if (!m) return null;
  let digits = m[1] + (m[2] ?? "");
  let point = m[1].length + Number(m[3] ?? 0); // where the decimal point goes
  if (point <= 0) {
    digits = "0".repeat(1 - point) + digits;
    point = 1;
  } else if (point > digits.length) {
    digits += "0".repeat(point - digits.length);
  }
  const whole = digits.slice(0, point).replace(/^0+(?=\d)/, "");
  const fraction = digits.slice(point).replace(/0+$/, "");
  if (/^0*$/.test(whole + fraction)) return null;
  return fraction ? `${whole}.${fraction}` : whole;
}

/**
 * The day and rates in an open.er-api.com response, read from the raw text
 * so no rate ever passes through a floating-point number.
 */
export function ratesFromBody(
  body: string,
): { date: string; rates: Record<string, string> } | null {
  let parsed: { result?: string; time_last_update_unix?: number };
  try {
    parsed = JSON.parse(body);
  } catch {
    return null;
  }
  if (parsed.result !== "success" || !parsed.time_last_update_unix) return null;
  const block = /"rates"\s*:\s*\{([^}]*)\}/.exec(body)?.[1];
  if (!block) return null;
  const rates: Record<string, string> = {};
  for (const [, code, value] of block.matchAll(/"([A-Z]{3})"\s*:\s*([^,\s}]+)/g)) {
    const rate = plainDecimal(value);
    if (code !== "USD" && rate) rates[code] = rate;
  }
  const date = new Date(parsed.time_last_update_unix * 1000).toISOString().slice(0, 10);
  return Object.keys(rates).length > 0 ? { date, rates } : null;
}

/** Fetches today's rates and stores them; false (and nothing written) on failure. */
export async function refreshRates(fetchImpl: typeof fetch = fetch): Promise<boolean> {
  try {
    const res = await fetchImpl(SOURCE, { signal: AbortSignal.timeout(15_000) });
    if (!res.ok) throw new Error(`Rates HTTP ${res.status}`);
    const parsed = ratesFromBody(await res.text());
    if (!parsed) throw new Error("Rates response not usable");
    await getFirestore().doc(`fx_rates/${parsed.date}`).set({
      // Also a field, so the app can ask for the latest day on or before one.
      date: parsed.date,
      rates: parsed.rates,
      source: "open.er-api.com",
      fetchedAt: FieldValue.serverTimestamp(),
    });
    logger.info("Stored FX rates", { date: parsed.date, count: Object.keys(parsed.rates).length });
    return true;
  } catch (e) {
    logger.warn("FX rates not refreshed; the app keeps the last day", { error: String(e) });
    return false;
  }
}

/** The scheduled run: throws on failure so the scheduler retries it. */
export async function runDailyFxRates(fetchImpl: typeof fetch = fetch): Promise<void> {
  if (!(await refreshRates(fetchImpl))) throw new Error("FX rates not refreshed");
}

/** Shortly after the provider's daily update (00:00 UTC). */
export const dailyFxRates = onSchedule(
  { schedule: "every day 00:30", timeZone: "UTC", retryCount: 3 },
  () => runDailyFxRates(),
);

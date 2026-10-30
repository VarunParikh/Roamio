import { beforeAll, describe, expect, it } from "vitest";
import {
  plainDecimal,
  ratesFromBody,
  refreshRates,
  runDailyFxRates,
} from "../../functions/src/fx/rates";
import { getApps, getFirestore, initializeApp } from "../support/admin";

beforeAll(() => {
  if (getApps().length === 0) initializeApp({ projectId: "demo-roamio" });
});

const db = () => getFirestore();

// Shaped like open.er-api.com's /v6/latest/USD response.
const body = (date: string) => `{
  "result": "success",
  "time_last_update_unix": ${Date.parse(`${date}T00:02:31Z`) / 1000},
  "time_last_update_utc": "x",
  "base_code": "USD",
  "rates": {
    "USD": 1,
    "INR": 84.123456,
    "EUR": 0.9215,
    "THB": 33.4,
    "JPY": 150,
    "KWD": 0.3071,
    "VES": 3.6e1,
    "XYZ": 1.2e-7
  }
}`;

const fakeFetch = (text: string, ok = true) => async () =>
  ({ ok, status: ok ? 200 : 503, text: async () => text }) as Response;

describe("plainDecimal (rates stay exact decimal text, never floats)", () => {
  it("keeps plain numbers as written and expands exponents", () => {
    expect(plainDecimal("84.123456")).toBe("84.123456");
    expect(plainDecimal("150")).toBe("150");
    expect(plainDecimal("3.6e1")).toBe("36");
    expect(plainDecimal("1.2e-7")).toBe("0.00000012");
    expect(plainDecimal("1.25E+3")).toBe("1250");
    expect(plainDecimal("-1")).toBeNull();
    expect(plainDecimal("0")).toBeNull();
    expect(plainDecimal("abc")).toBeNull();
  });
});

describe("ratesFromBody", () => {
  it("reads every rate as written in the response, except USD itself", () => {
    const r = ratesFromBody(body("2026-10-29"));
    expect(r?.date).toBe("2026-10-29");
    expect(r?.rates).toEqual({
      INR: "84.123456",
      EUR: "0.9215",
      THB: "33.4",
      JPY: "150",
      KWD: "0.3071",
      VES: "36",
      XYZ: "0.00000012",
    });
  });

  it("refuses an error response", () => {
    expect(ratesFromBody('{"result":"error","error-type":"quota-reached"}')).toBeNull();
    expect(ratesFromBody("not json")).toBeNull();
  });
});

describe("refreshRates (scheduled daily, spec §9.1)", () => {
  it("stores the day's rates under the provider's date", async () => {
    const ok = await refreshRates(fakeFetch(body("2026-10-27")));
    expect(ok).toBe(true);
    const doc = (await db().doc("fx_rates/2026-10-27").get()).data();
    expect(doc?.rates.INR).toBe("84.123456");
    expect(doc?.date).toBe("2026-10-27");
    expect(doc?.source).toBe("open.er-api.com");
    expect(doc?.fetchedAt).toBeTruthy();
  });

  it("writes nothing during an outage, keeping the last day's rates", async () => {
    await db().doc("fx_rates/2026-10-25").set({ rates: { INR: "83.9" } });

    expect(await refreshRates(fakeFetch("", false))).toBe(false);
    expect(
      await refreshRates(async () => {
        throw new Error("network down");
      }),
    ).toBe(false);
    expect(await refreshRates(fakeFetch('{"result":"error"}'))).toBe(false);

    expect((await db().doc("fx_rates/2026-10-25").get()).get("rates")).toEqual({ INR: "83.9" });
    expect((await db().doc("fx_rates/2026-10-26").get()).exists).toBe(false);
  });
});

describe("dailyFxRates (follow-up C10)", () => {
  it("reports a failed refresh, so the scheduler's 3 retries run", async () => {
    await expect(runDailyFxRates(fakeFetch("", false))).rejects.toThrow(/not refreshed/);
    await expect(runDailyFxRates(fakeFetch(body("2026-10-28")))).resolves.toBeUndefined();
  });
});

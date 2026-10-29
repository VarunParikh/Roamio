import { describe, expect, it } from "vitest";
import {
  parseServerConfig,
  SERVER_CONFIG_DEFAULTS,
  serverConfig,
} from "../../functions/src/config";
import { thresholdsReached } from "../../functions/src/budget/budget";
import { isExpired } from "../../functions/src/consent/rules";

const DAY = 86_400_000;

describe("server Remote Config (spec §11)", () => {
  it("has a default for every server key", () => {
    expect(parseServerConfig({})).toEqual({
      budgetThresholds: [80, 100],
      inviteDays: 14,
      consentDays: 7,
    });
    expect(Object.keys(SERVER_CONFIG_DEFAULTS).sort()).toEqual([
      "budget_alert_thresholds",
      "consent_link_validity_days",
      "invite_validity_days",
    ]);
  });

  it("uses values that make sense, and the default for anything else", () => {
    expect(
      parseServerConfig({
        budget_alert_thresholds: "[100, 50, 90]",
        invite_validity_days: "30",
        consent_link_validity_days: "10",
      }),
    ).toEqual({ budgetThresholds: [50, 90, 100], inviteDays: 30, consentDays: 10 });

    expect(
      parseServerConfig({
        budget_alert_thresholds: "lots",
        invite_validity_days: "0",
        consent_link_validity_days: "2.5",
      }),
    ).toEqual({ budgetThresholds: [80, 100], inviteDays: 14, consentDays: 7 });
    expect(parseServerConfig({ budget_alert_thresholds: "[0, 500]" }).budgetThresholds).toEqual([
      80, 100,
    ]);
    expect(parseServerConfig({ budget_alert_thresholds: "[]" }).budgetThresholds).toEqual([80, 100]);
    expect(parseServerConfig({ invite_validity_days: "400" }).inviteDays).toBe(14);
  });

  it("falls back to the defaults when Remote Config can't be reached", async () => {
    expect(await serverConfig()).toEqual(parseServerConfig({}));
  });

  it("budget alerts and consent expiry follow the configured values", () => {
    expect(thresholdsReached(5000, 10000)).toEqual([]);
    expect(thresholdsReached(5000, 10000, [50, 100])).toEqual([50]);
    expect(isExpired(0, 7 * DAY)).toBe(true);
    expect(isExpired(0, 7 * DAY, 10)).toBe(false);
    expect(isExpired(0, 10 * DAY, 10)).toBe(true);
  });
});

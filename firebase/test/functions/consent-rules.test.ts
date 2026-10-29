import { describe, expect, it } from "vitest";
import {
  CONSENT_DAYS,
  MAX_REQUESTS_PER_DAY,
  WITHDRAW_GRACE_HOURS,
  canRequestAgain,
  nextConsentAction,
} from "../../functions/src/consent/rules";
import {
  hashToken,
  newToken,
  tokensMatch,
} from "../../functions/src/consent/token";

const HOUR = 60 * 60 * 1000;
const DAY = 24 * HOUR;
const sent = Date.parse("2026-10-29T06:00:00Z");

describe("nextConsentAction (spec §7.1 step 3)", () => {
  const pending = { status: "requested", requestedAt: sent, remindersSent: 0 };

  it("does nothing in the first three days", () => {
    expect(nextConsentAction(pending, sent + 2.9 * DAY)).toBeNull();
  });

  it("reminds on day 3 and day 6, once each", () => {
    expect(nextConsentAction(pending, sent + 3 * DAY)).toBe("remind");
    expect(
      nextConsentAction({ ...pending, remindersSent: 1 }, sent + 3.5 * DAY),
    ).toBeNull();
    expect(
      nextConsentAction({ ...pending, remindersSent: 1 }, sent + 6 * DAY),
    ).toBe("remind");
    expect(
      nextConsentAction({ ...pending, remindersSent: 2 }, sent + 6.5 * DAY),
    ).toBeNull();
  });

  it("expires after seven days", () => {
    expect(
      nextConsentAction(
        { ...pending, remindersSent: 2 },
        sent + CONSENT_DAYS * DAY,
      ),
    ).toBe("expire");
  });

  it("deletes a withdrawn child 48 hours after withdrawal (spec §7.3)", () => {
    const withdrawn = { ...pending, status: "withdrawn", withdrawnAt: sent };
    expect(
      nextConsentAction(withdrawn, sent + (WITHDRAW_GRACE_HOURS - 1) * HOUR),
    ).toBeNull();
    expect(
      nextConsentAction(withdrawn, sent + WITHDRAW_GRACE_HOURS * HOUR),
    ).toBe("delete");
  });

  it("ignores requests that are already decided", () => {
    for (const status of ["granted", "declined", "expired", "closed"]) {
      expect(
        nextConsentAction({ ...pending, status }, sent + 10 * DAY),
      ).toBeNull();
    }
  });
});

describe("canRequestAgain (resend limit)", () => {
  it(`allows ${MAX_REQUESTS_PER_DAY} requests per day in India, then refuses`, () => {
    expect(canRequestAgain(undefined, "2026-10-29")).toBe(true);
    expect(canRequestAgain({ day: "2026-10-29", count: 2 }, "2026-10-29")).toBe(
      true,
    );
    expect(canRequestAgain({ day: "2026-10-29", count: 3 }, "2026-10-29")).toBe(
      false,
    );
  });

  it("resets the next day", () => {
    expect(canRequestAgain({ day: "2026-10-29", count: 3 }, "2026-10-30")).toBe(
      true,
    );
  });
});

describe("consent tokens", () => {
  it("are long, random and stored only as a hash", () => {
    const a = newToken();
    const b = newToken();
    expect(a).not.toBe(b);
    expect(a.length).toBeGreaterThanOrEqual(40);
    expect(hashToken(a)).not.toContain(a);
  });

  it("match only the original token", () => {
    const token = newToken();
    const hash = hashToken(token);
    expect(tokensMatch(token, hash)).toBe(true);
    expect(tokensMatch(newToken(), hash)).toBe(false);
    expect(tokensMatch("", hash)).toBe(false);
    expect(tokensMatch(token, undefined)).toBe(false);
  });
});

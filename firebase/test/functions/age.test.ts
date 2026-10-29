import { describe, expect, it } from "vitest";
import { ageOn, bracketFor, todayInIndia } from "../../functions/src/auth/age";

describe("age rules (server copy of app/lib/features/auth/domain/age.dart)", () => {
  it("counts whole years, turning older on the birthday", () => {
    expect(ageOn("2008-10-30", "2026-10-29")).toBe(17);
    expect(ageOn("2008-10-30", "2026-10-30")).toBe(18);
  });

  it("turns a 29 February birthday older on 1 March in common years", () => {
    expect(ageOn("2008-02-29", "2026-02-28")).toBe(17);
    expect(ageOn("2008-02-29", "2026-03-01")).toBe(18);
  });

  it("brackets ages for sign-up", () => {
    const today = "2026-10-29";
    expect(bracketFor("2013-10-30", today)).toBe("underThirteen");
    expect(bracketFor("2013-10-29", today)).toBe("minor");
    expect(bracketFor("2008-10-30", today)).toBe("minor");
    expect(bracketFor("2008-10-29", today)).toBe("adult");
  });

  it("rejects malformed, future and over-120 dates", () => {
    const today = "2026-10-29";
    expect(bracketFor("29-10-2008", today)).toBe("invalid");
    expect(bracketFor("2026-10-30", today)).toBe("invalid");
    expect(bracketFor("1906-10-28", today)).toBe("invalid");
    expect(bracketFor("1906-10-29", today)).toBe("adult");
    expect(bracketFor("2008-02-30", today)).toBe("invalid");
  });

  it("uses the date in India, not UTC", () => {
    // 20:00 UTC on 28 Oct is 01:30 on 29 Oct in India.
    expect(todayInIndia(new Date("2026-10-28T20:00:00Z"))).toBe("2026-10-29");
  });
});

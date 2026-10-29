// Server copy of app/lib/features/auth/domain/age.dart — keep the two in step.
// The server's answer is the one that counts: it sets `ageStatus`.

export type Bracket = "underThirteen" | "minor" | "adult" | "invalid";

const ISO_DATE = /^(\d{4})-(\d{2})-(\d{2})$/;

/** True when [date] is a real calendar date written as yyyy-mm-dd. */
function isRealDate(date: string): boolean {
  const m = ISO_DATE.exec(date);
  if (!m) return false;
  const [y, mo, d] = [Number(m[1]), Number(m[2]), Number(m[3])];
  const real = new Date(Date.UTC(y, mo - 1, d));
  return real.getUTCMonth() === mo - 1 && real.getUTCDate() === d;
}

/** Whole years; a 29 February birthday turns older on 1 March in common years. */
export function ageOn(dob: string, today: string): number {
  const [by, bm, bd] = dob.split("-").map(Number);
  const [ty, tm, td] = today.split("-").map(Number);
  const hadBirthday = tm > bm || (tm === bm && td >= bd);
  return ty - by - (hadBirthday ? 0 : 1);
}

export function bracketFor(dob: string, today: string): Bracket {
  const oldestAllowed = `${Number(today.slice(0, 4)) - 120}${today.slice(4)}`;
  if (!isRealDate(dob) || dob > today || dob < oldestAllowed) return "invalid";
  const age = ageOn(dob, today);
  if (age < 13) return "underThirteen";
  return age < 18 ? "minor" : "adult";
}

/** Today's date in India (yyyy-mm-dd); Roamio's users and data live there. */
export function todayInIndia(now: Date): string {
  return new Intl.DateTimeFormat("en-CA", { timeZone: "Asia/Kolkata" }).format(now);
}

// Timing and limits for parental consent requests (spec §7.1).

/** Days a parent has to answer before the child's account is deleted. */
export const CONSENT_DAYS = 7;
/** Days after the request on which the parent is reminded. */
export const REMINDER_DAYS = [3, 6];
/** Hours between a parent withdrawing consent and the child's deletion. */
export const WITHDRAW_GRACE_HOURS = 48;
/** Consent emails a child can trigger per day (India date). */
export const MAX_REQUESTS_PER_DAY = 3;

const HOUR_MS = 60 * 60 * 1000;
const DAY_MS = 24 * HOUR_MS;

export type ConsentTiming = {
  status: string;
  requestedAt: number;
  remindersSent: number;
  withdrawnAt?: number;
};

export function isExpired(requestedAt: number, now: number, days = CONSENT_DAYS): boolean {
  return now - requestedAt >= days * DAY_MS;
}

/** What the daily sweep should do with one consent request at [now]. */
export function nextConsentAction(
  c: ConsentTiming,
  now: number,
  days = CONSENT_DAYS,
): "remind" | "expire" | "delete" | null {
  if (c.status === "withdrawn") {
    return c.withdrawnAt !== undefined && now - c.withdrawnAt >= WITHDRAW_GRACE_HOURS * HOUR_MS
      ? "delete"
      : null;
  }
  if (c.status !== "requested") return null;
  if (isExpired(c.requestedAt, now, days)) return "expire";
  const daysWaiting = (now - c.requestedAt) / DAY_MS;
  const due = REMINDER_DAYS.filter((day) => daysWaiting >= day).length;
  return c.remindersSent < due ? "remind" : null;
}

export type RequestCounter = { day: string; count: number };

export function canRequestAgain(counter: RequestCounter | undefined, today: string): boolean {
  return !counter || counter.day !== today || counter.count < MAX_REQUESTS_PER_DAY;
}

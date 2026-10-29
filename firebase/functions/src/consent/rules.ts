// Timing and limits for parental consent requests (spec §7.1).

/** Days a parent has to answer before the child's account is deleted. */
export const CONSENT_DAYS = 7;
/** Days after the request on which the parent is reminded. */
export const REMINDER_DAYS = [3, 6];
/** Consent emails a child can trigger per day (India date). */
export const MAX_REQUESTS_PER_DAY = 3;

const DAY_MS = 24 * 60 * 60 * 1000;

export type ConsentTiming = { status: string; requestedAt: number; remindersSent: number };

export function isExpired(requestedAt: number, now: number): boolean {
  return now - requestedAt >= CONSENT_DAYS * DAY_MS;
}

/** What the daily sweep should do with one consent request at [now]. */
export function nextConsentAction(c: ConsentTiming, now: number): "remind" | "expire" | null {
  if (c.status !== "requested") return null;
  if (isExpired(c.requestedAt, now)) return "expire";
  const daysWaiting = (now - c.requestedAt) / DAY_MS;
  const due = REMINDER_DAYS.filter((day) => daysWaiting >= day).length;
  return c.remindersSent < due ? "remind" : null;
}

export type RequestCounter = { day: string; count: number };

export function canRequestAgain(counter: RequestCounter | undefined, today: string): boolean {
  return !counter || counter.day !== today || counter.count < MAX_REQUESTS_PER_DAY;
}

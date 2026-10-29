import { randomInt } from "node:crypto";

/** No 0/O, 1/I/L: easy to read aloud and type from a screenshot. */
const ALPHABET = "ABCDEFGHJKMNPQRSTUVWXYZ23456789";
const CODE = new RegExp(`^[${ALPHABET}]{8}$`);

export function newCode(): string {
  return Array.from({ length: 8 }, () => ALPHABET[randomInt(ALPHABET.length)]).join("");
}

/**
 * Accepts a code however it was typed or pasted ("7kq2-m9xa", "7KQ2 M9XA",
 * or a full invite link); null if it can't be a Roamio code.
 */
export function normaliseCode(input: string): string | null {
  const fromLink = /\/i\/([^/?#\s]+)/.exec(input)?.[1] ?? input;
  const code = fromLink.toUpperCase().replace(/[\s-]/g, "");
  return CODE.test(code) ? code : null;
}

/** "7KQ2M9XA" → "7KQ2-M9XA". */
export function formatCode(code: string): string {
  return `${code.slice(0, 4)}-${code.slice(4)}`;
}

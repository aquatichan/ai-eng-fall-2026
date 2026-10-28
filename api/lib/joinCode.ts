import { randomBytes } from "node:crypto";

// Crockford base32: no I, L, O, U, so codes are easy to read aloud and type.
const ALPHABET = "0123456789ABCDEFGHJKMNPQRSTVWXYZ";
export const JOIN_CODE_LENGTH = 12; // 60 bits of randomness

export function generateJoinCode(): string {
  // 256 is a multiple of 32, so `byte & 31` is unbiased.
  return Array.from(randomBytes(JOIN_CODE_LENGTH), (b) => ALPHABET[b & 31]).join("");
}

// Accepts user input like "abcd-efgh-jkmn" and returns the stored form,
// or null if it can't be a valid code.
export function normalizeJoinCode(input: unknown): string | null {
  if (typeof input !== "string") return null;
  const code = input
    .toUpperCase()
    .replace(/[\s-]/g, "")
    .replace(/[IL]/g, "1")
    .replace(/O/g, "0");
  if (code.length !== JOIN_CODE_LENGTH) return null;
  for (const ch of code) if (!ALPHABET.includes(ch)) return null;
  return code;
}

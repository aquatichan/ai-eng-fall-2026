import { randomInt } from "node:crypto";

// Codes are 3 letters then 3 digits, shown as "ABC-123". Short enough to read
// aloud, at the cost of guessability: 26^3 * 10^3 ≈ 17.6M codes.
const LETTERS = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
export const JOIN_CODE_RE = /^[A-Z]{3}[0-9]{3}$/;

export function generateJoinCode(): string {
  let code = "";
  for (let i = 0; i < 3; i++) code += LETTERS[randomInt(LETTERS.length)];
  for (let i = 0; i < 3; i++) code += String(randomInt(10));
  return code;
}

// Accepts input like "abc-123" or "ABC 123" and returns the stored form,
// or null if it can't be a valid code. Letter/digit look-alikes are fixed by
// position: "0" in the letter half is O, "O" in the digit half is 0.
export function normalizeJoinCode(input: unknown): string | null {
  if (typeof input !== "string") return null;
  const raw = input.toUpperCase().replace(/[\s-]/g, "");
  if (raw.length !== 6) return null;
  const letters = raw.slice(0, 3).replace(/0/g, "O").replace(/1/g, "I");
  const digits = raw.slice(3).replace(/O/g, "0").replace(/[IL]/g, "1");
  const code = letters + digits;
  return JOIN_CODE_RE.test(code) ? code : null;
}

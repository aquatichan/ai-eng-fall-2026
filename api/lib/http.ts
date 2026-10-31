// Every response is per-user and changes as people join or edit their cards,
// so nothing between the app and the API may cache it.
export function json(body: unknown, status = 200): Response {
  return Response.json(body, { status, headers: { "Cache-Control": "no-store" } });
}

export function error(status: number, message: string): Response {
  return json({ error: message }, status);
}

// Returns the parsed JSON object, or null if the body isn't a JSON object.
export async function readJsonObject(
  req: Request,
): Promise<Record<string, unknown> | null> {
  try {
    const body = await req.json();
    return body && typeof body === "object" && !Array.isArray(body)
      ? (body as Record<string, unknown>)
      : null;
  } catch {
    return null;
  }
}

// Control characters other than newline. These end up in other people's
// Contacts and in .vcf files, where a stray \r or NUL can corrupt the card.
const CONTROL_RE = /[\u0000-\u0009\u000B-\u001F\u007F]/;

// Trimmed string, or null when missing/blank. Throws on wrong type, too long,
// control characters, or a line break unless `multiline`.
export function optionalString(
  value: unknown,
  field: string,
  maxLength: number,
  { multiline = false } = {},
): string | null {
  if (value === undefined || value === null) return null;
  if (typeof value !== "string") throw new ValidationError(`${field} must be a string`);
  if (CONTROL_RE.test(value) || (!multiline && value.includes("\n"))) {
    throw new ValidationError(`${field} contains characters that aren't allowed`);
  }
  const trimmed = value.trim();
  if (trimmed.length > maxLength) {
    throw new ValidationError(`${field} must be at most ${maxLength} characters`);
  }
  return trimmed === "" ? null : trimmed;
}

export function requiredString(value: unknown, field: string, maxLength: number): string {
  const s = optionalString(value, field, maxLength);
  if (s === null) throw new ValidationError(`${field} is required`);
  return s;
}

export class ValidationError extends Error {}

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export function isUuid(value: unknown): value is string {
  return typeof value === "string" && UUID_RE.test(value);
}

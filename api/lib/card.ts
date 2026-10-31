import type { User } from "@supabase/supabase-js";
import { displayName } from "./auth";
import { optionalString, requiredString, ValidationError } from "./http";

// A person's contact card, stored once in `profiles` and shown in every group.
export type Card = {
  first_name: string;
  last_name: string | null;
  phones: { label: string; number: string }[];
  emails: { label: string; address: string }[];
  company: string | null;
  job_title: string | null;
  website: string | null;
  address: string | null;
  birthday: string | null; // YYYY-MM-DD
};

export const PROFILE_COLUMNS =
  "user_id, first_name, last_name, phones, emails, company, job_title, website, address, birthday, updated_at";

// Labels both iOS and Android Contacts understand; the app maps them to each
// platform's own (e.g. "iphone" becomes "mobile" on Android).
const PHONE_LABELS = ["mobile", "iphone", "home", "work", "main", "pager", "other"];
const EMAIL_LABELS = ["home", "work", "school", "icloud", "other"];
const MAX_ENTRIES = 5;

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const PHONE_RE = /^[0-9+()\-.\s]{3,40}$/;
const DATE_RE = /^\d{4}-\d{2}-\d{2}$/;

// Validates a card from a request body. Throws ValidationError with a message
// fit to show the user.
export function parseCard(body: Record<string, unknown>): Card {
  const birthday = optionalString(body.birthday, "birthday", 10);
  if (birthday !== null && (!DATE_RE.test(birthday) || isNaN(Date.parse(birthday)))) {
    throw new ValidationError("birthday must be YYYY-MM-DD");
  }
  return {
    first_name: requiredString(body.first_name, "first name", 100),
    last_name: optionalString(body.last_name, "last name", 100),
    phones: parseList(body.phones, "phones", PHONE_LABELS, "number", (v) => {
      if (!PHONE_RE.test(v)) throw new ValidationError(`"${v}" is not a valid phone number`);
    }),
    emails: parseList(body.emails, "emails", EMAIL_LABELS, "address", (v) => {
      if (!EMAIL_RE.test(v)) throw new ValidationError(`"${v}" is not a valid email`);
    }),
    company: optionalString(body.company, "company", 100),
    job_title: optionalString(body.job_title, "job title", 100),
    website: optionalString(body.website, "website", 200),
    address: optionalString(body.address, "address", 300),
    birthday,
  };
}

function parseList<K extends "number" | "address">(
  value: unknown,
  field: string,
  labels: string[],
  key: K,
  check: (v: string) => void,
): ({ label: string } & Record<K, string>)[] {
  if (value === undefined || value === null) return [];
  if (!Array.isArray(value)) throw new ValidationError(`${field} must be a list`);
  const out = [];
  for (const item of value) {
    if (!item || typeof item !== "object") throw new ValidationError(`${field} entries must be objects`);
    const entry = item as Record<string, unknown>;
    const v = optionalString(entry[key], field, key === "number" ? 40 : 254);
    if (v === null) continue; // blank rows from the form
    check(v);
    const label = typeof entry.label === "string" && labels.includes(entry.label) ? entry.label : "other";
    out.push({ label, [key]: v } as { label: string } & Record<K, string>);
  }
  if (out.length > MAX_ENTRIES) throw new ValidationError(`At most ${MAX_ENTRIES} ${field}`);
  return out;
}

// For members who haven't set up a profile yet: a card from what joining
// recorded (their Google name and email).
export function fallbackCard(m: { name: string; email: string; phone: string | null; org: string | null }): Card {
  const [first, ...rest] = m.name.trim().split(/\s+/);
  return {
    first_name: first || "Member",
    last_name: rest.length ? rest.join(" ") : null,
    phones: m.phone ? [{ label: "mobile", number: m.phone }] : [],
    emails: m.email ? [{ label: "other", address: m.email }] : [],
    company: m.org,
    job_title: null,
    website: null,
    address: null,
    birthday: null,
  };
}

// The legacy per-group columns on `members`, kept in sync with the profile so
// anything still reading them sees current data.
export function memberColumns(card: Card, user: User) {
  const name = [card.first_name, card.last_name].filter(Boolean).join(" ") || displayName(user);
  return {
    name: name.slice(0, 100),
    email: card.emails[0]?.address ?? user.email ?? "",
    phone: card.phones[0]?.number ?? null,
    org: card.company,
  };
}

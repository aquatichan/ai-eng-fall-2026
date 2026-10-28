import { requireUser } from "@/lib/auth";
import {
  error,
  isUuid,
  json,
  optionalString,
  readJsonObject,
  requiredString,
  ValidationError,
} from "@/lib/http";
import { supabaseAdmin } from "@/lib/supabaseAdmin";

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const PHONE_RE = /^[0-9+()\-.\s]{3,40}$/;

// POST /api/members { group_id, name, phone?, email?, org? }
// Creates or updates your own entry. You must own the group or have joined it.
// email defaults to your Google email; blank phone/org are stored as null.
export async function POST(req: Request) {
  const user = await requireUser(req);
  if (user instanceof Response) return user;

  const body = await readJsonObject(req);
  if (!body) return error(400, "Body must be a JSON object");
  if (!isUuid(body.group_id)) return error(400, "group_id must be a UUID");
  const groupId = body.group_id;

  let entry: { name: string; phone: string | null; email: string; org: string | null };
  try {
    const email = optionalString(body.email, "email", 254) ?? user.email ?? "";
    const phone = optionalString(body.phone, "phone", 40);
    if (!EMAIL_RE.test(email)) throw new ValidationError("email is not valid");
    if (phone !== null && !PHONE_RE.test(phone)) throw new ValidationError("phone is not valid");
    entry = {
      name: requiredString(body.name, "name", 100),
      phone,
      email,
      org: optionalString(body.org, "org", 100),
    };
  } catch (e) {
    if (e instanceof ValidationError) return error(400, e.message);
    throw e;
  }

  const db = supabaseAdmin();
  const [{ data: group, error: gErr }, { data: existing, error: eErr }] = await Promise.all([
    db.from("groups").select("owner_id").eq("id", groupId).maybeSingle(),
    db.from("members").select("id").eq("group_id", groupId).eq("user_id", user.id).maybeSingle(),
  ]);
  if (gErr) return error(500, gErr.message);
  if (eErr) return error(500, eErr.message);
  if (!group) return error(404, "Group not found");
  if (!existing && group.owner_id !== user.id) {
    return error(403, "Join the group with its code first");
  }

  const { data: member, error: upErr } = await db
    .from("members")
    .upsert({ group_id: groupId, user_id: user.id, ...entry }, { onConflict: "group_id,user_id" })
    .select("id, group_id, user_id, name, phone, email, org, created_at")
    .single();
  if (upErr) return error(500, upErr.message);

  return json({ member }, existing ? 200 : 201);
}

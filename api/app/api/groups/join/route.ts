import { requireUser } from "@/lib/auth";
import { error, json, readJsonObject } from "@/lib/http";
import { normalizeJoinCode } from "@/lib/joinCode";
import { ensureMember } from "@/lib/members";
import { supabaseAdmin } from "@/lib/supabaseAdmin";

const MAX_FAILED_JOINS = 10;
const FAILED_JOIN_WINDOW_MS = 15 * 60 * 1000;

// POST /api/groups/join { code }: adds you to the group with that code.
// After 10 wrong codes in 15 minutes, answers 429 until the window passes.
// Your card in the group is your profile (PUT /api/profile).
// Joining a group you're already in is a no-op that returns your existing entry.
export async function POST(req: Request) {
  const user = await requireUser(req);
  if (user instanceof Response) return user;

  const db = supabaseAdmin();
  // Codes are short enough to guess, so cap wrong guesses per user.
  const since = new Date(Date.now() - FAILED_JOIN_WINDOW_MS).toISOString();
  const { count, error: cErr } = await db
    .from("join_failures")
    .select("*", { count: "exact", head: true })
    .eq("user_id", user.id)
    .gte("created_at", since);
  if (cErr) return error(500, cErr.message);
  if ((count ?? 0) >= MAX_FAILED_JOINS) {
    return error(429, "Too many wrong codes. Try again in a few minutes.");
  }

  const body = await readJsonObject(req);
  const code = normalizeJoinCode(body?.code);
  if (!code) return error(400, "Invalid join code");

  const { data: group, error: gErr } = await db
    .from("groups")
    .select("id, name, join_code, owner_id, created_at")
    .eq("join_code", code)
    .maybeSingle();
  if (gErr) return error(500, gErr.message);
  if (!group) {
    const { error: fErr } = await db.from("join_failures").insert({ user_id: user.id });
    if (fErr) return error(500, fErr.message);
    return error(404, "No group with that code");
  }

  const insErr = await ensureMember(db, group.id, user);
  if (insErr) return error(500, insErr.message);

  const { data: member, error: mErr } = await db
    .from("members")
    .select("*")
    .eq("group_id", group.id)
    .eq("user_id", user.id)
    .single();
  if (mErr) return error(500, mErr.message);

  return json({ group: { ...group, is_owner: group.owner_id === user.id }, member });
}

import { requireUser } from "@/lib/auth";
import { error, json, readJsonObject } from "@/lib/http";
import { normalizeJoinCode } from "@/lib/joinCode";
import { ensureMember } from "@/lib/members";
import { supabaseAdmin } from "@/lib/supabaseAdmin";

// POST /api/groups/join { code }: adds you to the group with that code.
// Your card in the group is your profile (PUT /api/profile).
// Joining a group you're already in is a no-op that returns your existing entry.
export async function POST(req: Request) {
  const user = await requireUser(req);
  if (user instanceof Response) return user;

  const body = await readJsonObject(req);
  const code = normalizeJoinCode(body?.code);
  if (!code) return error(400, "Invalid join code");

  const db = supabaseAdmin();
  const { data: group, error: gErr } = await db
    .from("groups")
    .select("id, name, join_code, owner_id, created_at")
    .eq("join_code", code)
    .maybeSingle();
  if (gErr) return error(500, gErr.message);
  if (!group) return error(404, "No group with that code");

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

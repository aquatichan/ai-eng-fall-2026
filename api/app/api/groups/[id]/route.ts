import { requireUser } from "@/lib/auth";
import { fallbackCard, PROFILE_COLUMNS } from "@/lib/card";
import { error, isUuid, json } from "@/lib/http";
import { supabaseAdmin } from "@/lib/supabaseAdmin";

// GET /api/groups/[id]: the group and its roster. Only for its owner or members.
// Each member is their profile card (or a card from their Google account if
// they haven't set one up), plus user_id, is_owner and updated_at.
export async function GET(req: Request, ctx: { params: Promise<{ id: string }> }) {
  const user = await requireUser(req);
  if (user instanceof Response) return user;

  const { id } = await ctx.params;
  if (!isUuid(id)) return error(404, "Group not found");

  const db = supabaseAdmin();
  const { data: group, error: gErr } = await db
    .from("groups")
    .select("id, name, join_code, owner_id, created_at")
    .eq("id", id)
    .maybeSingle();
  if (gErr) return error(500, gErr.message);
  if (!group) return error(404, "Group not found");

  const { data: rows, error: mErr } = await db
    .from("members")
    .select("user_id, name, phone, email, org, created_at")
    .eq("group_id", id);
  if (mErr) return error(500, mErr.message);

  const isOwner = group.owner_id === user.id;
  if (!isOwner && !rows.some((m) => m.user_id === user.id)) {
    return error(403, "You are not a member of this group");
  }

  const userIds = rows.map((m) => m.user_id as string);
  const { data: profiles, error: pErr } = userIds.length
    ? await db.from("profiles").select(PROFILE_COLUMNS).in("user_id", userIds)
    : { data: [], error: null };
  if (pErr) return error(500, pErr.message);
  const profileOf = new Map(profiles.map((p) => [p.user_id as string, p]));

  const members = rows
    .map((m) => {
      const profile = profileOf.get(m.user_id);
      const card = profile ?? { ...fallbackCard(m), updated_at: m.created_at };
      return { ...card, user_id: m.user_id, is_owner: m.user_id === group.owner_id };
    })
    .sort((a, b) => a.first_name.localeCompare(b.first_name));

  return json({ group: { ...group, is_owner: isOwner }, members, me_id: user.id });
}
